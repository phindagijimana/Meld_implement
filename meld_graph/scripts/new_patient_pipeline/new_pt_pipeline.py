import os
import argparse
import sys
import time
import shutil
import pandas as pd
import numpy as np
from scripts.new_patient_pipeline.run_script_segmentation import run_script_segmentation
from scripts.new_patient_pipeline.run_script_preprocessing import run_script_preprocessing
from scripts.new_patient_pipeline.run_script_prediction import run_script_prediction
from scripts.new_patient_pipeline.validate_outputs import (
    validate_input_data,
    validate_freesurfer_outputs,
    validate_hdf5_files,
    validate_prediction_outputs
)
from meld_graph.paths import MELD_DATA_PATH, DEMOGRAPHIC_FEATURES_FILE, FS_SUBJECTS_PATH
from meld_graph.tools_pipeline import get_m, create_demographic_file

class Logger(object):
    def __init__(self, sys_type=sys.stdout, filename='MELD_output.log'):
        self.terminal = sys_type
        self.filename = filename
        self.log = open(self.filename, "a")

    def write(self, message):
        self.terminal.write(message)
        self.log.write(message)
    
    def flush(self):
        pass
        
if __name__ == "__main__":
    import scripts.env_setup
    scripts.env_setup.setup()
    
    # parse commandline arguments
    parser = argparse.ArgumentParser(description="Main pipeline to predict on subject with MELD classifier")
    parser.add_argument("-id","--id",
                        help="Subject ID.",
                        default=None,
                        required=False,
                        )
    parser.add_argument("-ids","--list_ids",
                        default=None,
                        help="File containing list of ids. Can be txt or csv with 'ID' column",
                        required=False,
                        )
    parser.add_argument("-ses","--session",
                        default=None,
                        help="Session label (e.g., '1' or 'ses-1'). For multi-session subjects, process specific session.",
                        required=False,
                        )
    parser.add_argument("-harmo_code","--harmo_code",
                        default="noHarmo",
                        help="Harmonisation code",
                        required=False,
                        )
    parser.add_argument("--fastsurfer", 
                        help="use fastsurfer instead of freesurfer", 
                        required=False, 
                        default=False,
                        action="store_true",
                        )
    parser.add_argument("--parallelise", 
                        help="parallelise segmentation", 
                        required=False,
                        default=False,
                        action="store_true",
                        )
    parser.add_argument('-demos', '--demographic_file', 
                        type=str, 
                        help='provide the demographic files for the harmonisation',
                        required=False,
                        default=None,
                        )
    parser.add_argument('--harmo_only', 
                        action="store_true", 
                        help='only compute the harmonisation combat parameters, no further process',
                        required=False,
                        default=False,
                        )
    parser.add_argument('--skip_feature_extraction',
                        action="store_true",
                        help='Skip the segmentation and extraction of the MELD features',
                        )
    parser.add_argument('--no_nifti',
                        action="store_true",
                        default=False,
                        help='Only predict. Does not produce prediction on native T1, nor report',
                        )
    parser.add_argument('--no_report',
                        action="store_true",
                        default=False,
                        help='Predict and map back into native T1. Does not produce report',)
    parser.add_argument("--debug_mode", 
                        help="mode to debug error", 
                        required=False,
                        default=False,
                        action="store_true",
                        )
    

     
    #write terminal output in a log
    os.makedirs(os.path.join(MELD_DATA_PATH, 'logs'), exist_ok=True)
    file_path=os.path.join(MELD_DATA_PATH, 'logs','MELD_pipeline_'+time.strftime('%Y-%m-%d-%H-%M-%S') + '.log')
    sys.stdout = Logger(sys.stdout,file_path)
    sys.stderr = Logger(sys.stderr, file_path)
    
    args = parser.parse_args()
    print(args)
    
    #---------------------------------------------------------------------------------
    ### Create demographic file for prediction if not provided
    demographic_file_tmp = DEMOGRAPHIC_FEATURES_FILE
    if args.demographic_file is None:
        harmo_code = str(args.harmo_code)
        subject_id=None
        subject_ids=None
        if args.list_ids != None:
            list_ids=os.path.join(MELD_DATA_PATH, args.list_ids)
            try:
                sub_list_df=pd.read_csv(list_ids)
                subject_ids=np.array(sub_list_df.ID.values)
            except:
                subject_ids=np.array(np.loadtxt(list_ids, dtype='str', ndmin=1)) 
            else:
                    sys.exit(get_m(f'Could not open {subject_ids}', None, 'ERROR'))             
        elif args.id != None:
            subject_id=args.id
            subject_ids=np.array([args.id])
        else:
            print(get_m(f'No ids were provided', None, 'ERROR'))
            print(get_m(f'Please specify both subject(s) and site_code ...', None, 'ERROR'))
            sys.exit(-1) 
        create_demographic_file(subject_ids, demographic_file_tmp, harmo_code=harmo_code)
    else:
        shutil.copy(os.path.join(MELD_DATA_PATH,args.demographic_file), demographic_file_tmp)
    
    #---------------------------------------------------------------------------------
    ### INPUT VALIDATION ###
    print(get_m(f'Validating input data', None, 'VALIDATION'))
    for subject_id in subject_ids:
        if not validate_input_data(subject_id, os.path.join(MELD_DATA_PATH, 'input')):
            print(get_m(f'Input validation failed for subject {subject_id}. Please check input data.', None, 'ERROR'))
            sys.exit(1)
    
    #---------------------------------------------------------------------------------
    ### SEGMENTATION ###
    if not args.skip_feature_extraction:
        print(get_m(f'Call script segmentation', None, 'SCRIPT 1'))
        result = run_script_segmentation(
                            harmo_code = args.harmo_code,
                            list_ids=args.list_ids,
                            sub_id=args.id, 
                            use_parallel=args.parallelise, 
                            use_fastsurfer=args.fastsurfer,
                            verbose = args.debug_mode,
                            session = args.session
                            )
        if result == False:
            print(get_m(f'Segmentation and feature extraction has failed at least for one subject. See log at {file_path}. Consider fixing errors or excluding these subjects before re-running the pipeline. Segmentation will be skipped for subjects already processed', None, 'SCRIPT 1'))    
            sys.exit(1)
        
        # Validate FreeSurfer outputs
        print(get_m(f'Validating FreeSurfer outputs', None, 'VALIDATION'))
        for subject_id in subject_ids:
            if not validate_freesurfer_outputs(subject_id, FS_SUBJECTS_PATH):
                print(get_m(f'FreeSurfer output validation failed for {subject_id}', None, 'ERROR'))
                sys.exit(1)
    else:
        print(get_m(f'Skip script segmentation', None, 'SCRIPT 1'))

    #---------------------------------------------------------------------------------
    ### PREPROCESSING ###
    print(get_m(f'Call script preprocessing', None, 'SCRIPT 2'))
    result = run_script_preprocessing(
                    harmo_code=args.harmo_code,
                    list_ids=args.list_ids,
                    sub_id=args.id,
                    harmonisation_only = args.harmo_only,
                    )
    if result == False:
        print(get_m(f'Preprocessing has failed at least for one subject. See log at {file_path}. Consider fixing errors or excluding these subjects before re-running the pipeline.', None, 'SCRIPT 2'))
        sys.exit(1)
    
    # Validate HDF5 files
    print(get_m(f'Validating preprocessed HDF5 files', None, 'VALIDATION'))
    if not validate_hdf5_files(args.harmo_code, MELD_DATA_PATH, subject_ids):
        print(get_m(f'HDF5 validation failed', None, 'ERROR'))
        sys.exit(1)

    #---------------------------------------------------------------------------------
    ### PREDICTION ###
    if not args.harmo_only:
        print(get_m(f'Call script prediction', None, 'SCRIPT 3'))
        result = run_script_prediction(
                            harmo_code = args.harmo_code,
                            list_ids=args.list_ids,
                            sub_id=args.id,
                            no_prediction_nifti = args.no_nifti,
                            no_report = args.no_report,
                            verbose = args.debug_mode
                            )
        if result == False:
            print(get_m(f'Prediction and mapping back to native MRI has failed at least for one subject. See log at {file_path}. Consider fixing errors or excluding these subjects before re-running the pipeline. Segmentation will be skipped for subjects already processed', None, 'SCRIPT 3'))    
            sys.exit(1)
        
        # Validate prediction outputs
        if not args.no_nifti:
            print(get_m(f'Validating prediction outputs', None, 'VALIDATION'))
            for subject_id in subject_ids:
                if not validate_prediction_outputs(subject_id, MELD_DATA_PATH):
                    print(get_m(f'Prediction output validation failed for {subject_id}', None, 'ERROR'))
                    sys.exit(1)
    else:
        print(get_m(f'Skip script predition', None, 'SCRIPT 3'))
    
    #---------------------------------------------------------------------------------
    ### FINAL SUCCESS ###
    print(get_m(f'✓ Pipeline completed successfully for all subjects!', None, 'SUCCESS'))            
    print(f'You can find a log of the pipeline at {file_path}')
    
    #delete demographic file
    os.remove(demographic_file_tmp)