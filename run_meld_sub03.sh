#!/bin/bash

# =============================================================================
# MELD Graph Pipeline - Subject sub-03
# =============================================================================
# 
# Purpose: Run FCD detection pipeline on subject sub-03
# Images:  T1w + FLAIR (from CIDUR_BIDS_TEST dataset)
# Method:  Standard FreeSurfer (3-4 hours expected)
# 
# Author: AI Assistant
# Date: 2025-10-28
# Version: 2.0
#
# SLURM Configuration
#SBATCH --job-name=meld_sub03
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=6:00:00
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/logs/meld_sub03_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/logs/meld_sub03_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=pndagiji@urmc.rochester.edu
#
# =============================================================================

echo "========================================="
echo "MELD Graph Pipeline - Subject sub-03"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Start time: $(date)"
echo "========================================="

# Set working directory
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph

# Add FreeSurfer wrappers to PATH
export PATH="$(pwd)/.freesurfer_wrappers:$PATH"

# Display system information
echo ""
echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  CPUs: $SLURM_CPUS_PER_TASK"
echo "  Memory: $SLURM_MEM_PER_NODE MB"
echo "  Working Dir: $(pwd)"
echo ""

# Display subject information
echo "Subject Information:"
echo "  Subject ID: sub-03"
echo "  T1w: meld_data/input/sub-03/anat/sub-03_T1w.nii.gz"
echo "  FLAIR: meld_data/input/sub-03/anat/sub-03_FLAIR.nii.gz"
echo "  T1w size: $(du -h meld_data/input/sub-03/anat/sub-03_T1w.nii.gz | cut -f1)"
echo "  FLAIR size: $(du -h meld_data/input/sub-03/anat/sub-03_FLAIR.nii.gz | cut -f1)"
echo ""

# Check available disk space
echo "Disk Space:"
df -h /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/ | grep -v Filesystem
echo ""

# Initialize conda
echo "Initializing Conda environment..."
eval "$(/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/miniconda3/bin/conda shell.bash hook)"

# Activate MELD Graph environment
echo "Activating meld_graph environment..."
conda activate meld_graph

# Verify environment
echo ""
echo "Environment Verification:"
echo "  Conda env: $CONDA_DEFAULT_ENV"
python -c "import meld_graph; import torch; print(f'  MELD Graph: {meld_graph.__version__}'); print(f'  PyTorch: {torch.__version__}'); print(f'  Device: {\"GPU\" if torch.cuda.is_available() else \"CPU\"}')"
echo ""

# Check if FreeSurfer container exists
if [ ! -f "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/containers/freesurfer-7.4.1.sif" ]; then
    echo "ERROR: FreeSurfer container not found!"
    exit 1
fi
echo "FreeSurfer container: Found ($(du -h /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/containers/freesurfer-7.4.1.sif | cut -f1))"
echo ""

# Check if license exists
if [ ! -f "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/freesurfer_license/license.txt" ]; then
    echo "ERROR: FreeSurfer license not found!"
    exit 1
fi
echo "FreeSurfer license: Found"
echo ""

echo "========================================="
echo "Starting MELD Graph Pipeline"
echo "========================================="
echo ""

# Run MELD Graph pipeline with FreeSurfer
# This will:
# 1. Run FreeSurfer/FastSurfer segmentation (1-3 hours)
# 2. Extract features from T1w and FLAIR (30-60 min)
# 3. Run FCD prediction (5-10 min)
# 4. Generate PDF report (5 min)

echo "Running: ./run_meld_with_freesurfer.sh -id sub-03"
echo "Note: Using standard FreeSurfer (not FastSurfer)"
echo ""

./run_meld_with_freesurfer.sh -id sub-03

# Check exit status
EXIT_CODE=$?
echo ""
echo "========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "Pipeline completed successfully!"
    echo "========================================="
    echo ""
    echo "Output Location:"
    echo "  Predictions: meld_data/output/predictions_reports/sub-03/predictions/"
    echo "  Report: meld_data/output/predictions_reports/sub-03/reports/"
    echo ""
    
    # Check if output files exist
    if [ -f "meld_data/output/predictions_reports/sub-03/predictions/prediction.nii.gz" ]; then
        echo "Prediction file created:"
        ls -lh meld_data/output/predictions_reports/sub-03/predictions/prediction.nii.gz
    fi
    
    if [ -f "meld_data/output/predictions_reports/sub-03/reports/MELD_report_sub-03.pdf" ]; then
        echo "PDF report created:"
        ls -lh meld_data/output/predictions_reports/sub-03/reports/MELD_report_sub-03.pdf
    fi
    
else
    echo "Pipeline failed with exit code: $EXIT_CODE"
    echo "========================================="
    echo ""
    echo "Check logs for errors:"
    echo "  Job log: /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/logs/meld_sub03_${SLURM_JOB_ID}.err"
    echo "  FreeSurfer log: meld_data/output/fs_outputs/sub-03/scripts/recon-all.log"
fi

echo ""
echo "End time: $(date)"
echo "========================================="

exit $EXIT_CODE
