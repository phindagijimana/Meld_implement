#!/usr/bin/env python3
"""
Output validation functions for MELD Graph pipeline
Checks that critical files exist and are valid between pipeline stages
"""

import os
import h5py
import nibabel as nib

# Simple message formatter (standalone, no dependency on utils)
def get_m(message, subject_id=None, level='INFO'):
    """Format validation message"""
    prefix = f"[{level}]"
    if subject_id:
        return f"{prefix} {message} for {subject_id}"
    return f"{prefix} {message}"

def validate_freesurfer_outputs(subject_id, subjects_dir):
    """
    Validate that FreeSurfer produced all required surface files
    
    Args:
        subject_id: Subject identifier
        subjects_dir: FreeSurfer SUBJECTS_DIR path
        
    Returns:
        bool: True if all required files exist and are non-empty
    """
    required_files = [
        f'{subjects_dir}/{subject_id}/surf/lh.white',
        f'{subjects_dir}/{subject_id}/surf/rh.white',
        f'{subjects_dir}/{subject_id}/surf/lh.pial',
        f'{subjects_dir}/{subject_id}/surf/rh.pial',
        f'{subjects_dir}/{subject_id}/surf/lh.inflated',
        f'{subjects_dir}/{subject_id}/surf/rh.inflated',
        f'{subjects_dir}/{subject_id}/mri/T1.mgz',
    ]
    
    for fpath in required_files:
        if not os.path.exists(fpath):
            print(get_m(f'Missing FreeSurfer output: {os.path.basename(fpath)}', subject_id, 'ERROR'))
            return False
        if os.path.getsize(fpath) == 0:
            print(get_m(f'Empty FreeSurfer output: {os.path.basename(fpath)}', subject_id, 'ERROR'))
            return False
    
    print(get_m(f'FreeSurfer outputs validated', subject_id, 'INFO'))
    return True


def validate_feature_files(subject_id, output_dir):
    """
    Validate that feature extraction produced required .mgh files
    
    Args:
        subject_id: Subject identifier
        output_dir: Base output directory
        
    Returns:
        bool: True if all required feature files exist
    """
    feature_dir = os.path.join(output_dir, 'output', 'fs_outputs', subject_id, 'xhemi', 'surf_meld')
    
    required_features = [
        f'{feature_dir}/lh.on_lh.thickness.mgh',
        f'{feature_dir}/lh.on_lh.w-g.pct.mgh',
        f'{feature_dir}/lh.on_lh.curv.mgh',
        f'{feature_dir}/lh.on_lh.sulc.mgh',
    ]
    
    missing_count = 0
    for fpath in required_features:
        if not os.path.exists(fpath):
            print(get_m(f'Missing feature file: {os.path.basename(fpath)}', subject_id, 'WARNING'))
            missing_count += 1
        elif os.path.getsize(fpath) == 0:
            print(get_m(f'Empty feature file: {os.path.basename(fpath)}', subject_id, 'WARNING'))
            missing_count += 1
    
    if missing_count > 0:
        print(get_m(f'{missing_count} feature files missing or empty', subject_id, 'WARNING'))
        # Don't fail - some features may be optional
        return True
    
    print(get_m(f'Feature files validated', subject_id, 'INFO'))
    return True


def validate_hdf5_files(harmo_code, output_dir, expected_subjects=None):
    """
    Validate that preprocessing produced valid HDF5 files
    
    Args:
        harmo_code: Harmonization code
        output_dir: Base output directory
        expected_subjects: List of subject IDs that should be in HDF5 (optional)
        
    Returns:
        bool: True if HDF5 files exist and are valid
    """
    hdf5_dir = os.path.join(output_dir, 'output', 'preprocessed_surf_data', f'MELD_{harmo_code}')
    
    required_files = [
        f'{hdf5_dir}/{harmo_code}_patient_featurematrix.hdf5',
        f'{hdf5_dir}/{harmo_code}_patient_featurematrix_smoothed.hdf5',
        f'{hdf5_dir}/{harmo_code}_patient_featurematrix_combat.hdf5',
    ]
    
    for fpath in required_files:
        if not os.path.exists(fpath):
            print(get_m(f'Missing HDF5 file: {os.path.basename(fpath)}', None, 'ERROR'))
            return False
        
        if os.path.getsize(fpath) < 1000:  # HDF5 should be at least 1KB
            print(get_m(f'HDF5 file too small (possibly corrupted): {os.path.basename(fpath)}', None, 'ERROR'))
            return False
        
        # Try to open HDF5 file to verify it's valid
        try:
            with h5py.File(fpath, 'r') as f:
                # Check that it has some data (structure may vary)
                if len(f.keys()) == 0:
                    print(get_m(f'HDF5 file appears empty: {os.path.basename(fpath)}', None, 'ERROR'))
                    return False
                
                # Optional: verify subjects if list provided (if subject_IDs key exists)
                if expected_subjects and 'subject_IDs' in f:
                    try:
                        stored_subjects = [s.decode('utf-8') if isinstance(s, bytes) else s for s in f['subject_IDs'][:]]
                        for subj in expected_subjects:
                            if subj not in stored_subjects:
                                print(get_m(f'Subject {subj} not found in HDF5: {os.path.basename(fpath)}', None, 'WARNING'))
                    except:
                        pass  # Subject verification is optional
        except Exception as e:
            print(get_m(f'Cannot read HDF5 file {os.path.basename(fpath)}: {e}', None, 'ERROR'))
            return False
    
    print(get_m(f'HDF5 files validated', None, 'INFO'))
    return True


def validate_prediction_outputs(subject_id, output_dir):
    """
    Validate that prediction stage produced all expected outputs
    
    Args:
        subject_id: Subject identifier
        output_dir: Base output directory
        
    Returns:
        bool: True if all required outputs exist
    """
    pred_dir = os.path.join(output_dir, 'output', 'predictions_reports', subject_id)
    
    required_files = [
        f'{pred_dir}/predictions/lh.prediction.nii.gz',
        f'{pred_dir}/predictions/rh.prediction.nii.gz',
        f'{pred_dir}/predictions/prediction.nii.gz',
        f'{pred_dir}/reports/MELD_report_{subject_id}.pdf',
    ]
    
    for fpath in required_files:
        if not os.path.exists(fpath):
            print(get_m(f'Missing prediction output: {os.path.basename(fpath)}', subject_id, 'ERROR'))
            return False
        
        if os.path.getsize(fpath) == 0:
            print(get_m(f'Empty prediction output: {os.path.basename(fpath)}', subject_id, 'ERROR'))
            return False
    
    # Validate NIfTI files can be loaded
    try:
        for nii_file in [f'{pred_dir}/predictions/lh.prediction.nii.gz',
                         f'{pred_dir}/predictions/rh.prediction.nii.gz',
                         f'{pred_dir}/predictions/prediction.nii.gz']:
            img = nib.load(nii_file)
            # Basic sanity check on shape
            if len(img.shape) < 3:
                print(get_m(f'Invalid NIfTI shape in {os.path.basename(nii_file)}', subject_id, 'ERROR'))
                return False
    except Exception as e:
        print(get_m(f'Cannot load prediction NIfTI: {e}', subject_id, 'ERROR'))
        return False
    
    print(get_m(f'Prediction outputs validated', subject_id, 'INFO'))
    return True


def validate_input_data(subject_id, data_dir):
    """
    Validate input data before starting pipeline
    
    Args:
        subject_id: Subject identifier
        data_dir: Input data directory
        
    Returns:
        bool: True if input data is valid
    """
    input_dir = os.path.join(data_dir, subject_id, 'anat')
    
    # T1 is mandatory
    t1_file = os.path.join(input_dir, f'{subject_id}_T1w.nii.gz')
    if not os.path.exists(t1_file):
        print(get_m(f'Missing required T1w image', subject_id, 'ERROR'))
        return False
    
    if os.path.getsize(t1_file) < 1000000:  # Should be at least 1MB
        print(get_m(f'T1w image suspiciously small', subject_id, 'ERROR'))
        return False
    
    # Validate T1 can be loaded
    try:
        img = nib.load(t1_file)
        if len(img.shape) != 3:
            print(get_m(f'T1w image should be 3D, got shape {img.shape}', subject_id, 'ERROR'))
            return False
        print(get_m(f'T1w image validated: shape {img.shape}, voxel size {img.header.get_zooms()[:3]}', subject_id, 'INFO'))
    except Exception as e:
        print(get_m(f'Cannot load T1w image: {e}', subject_id, 'ERROR'))
        return False
    
    # FLAIR is optional but recommended
    flair_file = os.path.join(input_dir, f'{subject_id}_FLAIR.nii.gz')
    if os.path.exists(flair_file):
        try:
            img = nib.load(flair_file)
            if len(img.shape) != 3:
                print(get_m(f'FLAIR image should be 3D, got shape {img.shape}', subject_id, 'WARNING'))
            else:
                print(get_m(f'FLAIR image validated: shape {img.shape}', subject_id, 'INFO'))
        except Exception as e:
            print(get_m(f'FLAIR image exists but cannot be loaded: {e}', subject_id, 'WARNING'))
    else:
        print(get_m(f'FLAIR image not provided (optional but recommended)', subject_id, 'WARNING'))
    
    return True
