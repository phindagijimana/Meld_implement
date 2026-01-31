#!/bin/bash
#SBATCH --job-name=meld_pipeline
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=8:00:00
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/logs/meld_pipeline_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/logs/meld_pipeline_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=pndagiji@urmc.rochester.edu

# MELD Graph Pipeline - Fixed for Containerized FreeSurfer
# This script properly configures the environment for end-to-end pipeline execution

echo "========================================="
echo "MELD Graph Pipeline - Complete Run"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Subject: ${SUBJECT_ID:-<specify with -id flag>}"
echo "Start time: $(date)"
echo ""

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

# Change to meld_graph directory
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph || exit 1

# Initialize conda
eval "$(/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/miniconda3/bin/conda shell.bash hook)"
conda activate meld_graph

# Enable FreeSurfer parallelization
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-8}
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${SLURM_CPUS_PER_TASK:-8}
echo "FreeSurfer parallelization: $OMP_NUM_THREADS threads"

# Add FreeSurfer wrappers to PATH (CRITICAL for containerized FreeSurfer)
FREESURFER_WRAPPERS_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph/.freesurfer_wrappers"
export PATH="${FREESURFER_WRAPPERS_DIR}:$PATH"
# Also add symlinked path for compatibility
export PATH="/mnt/nfs/home/URMC-SH/pndagiji/Documents/Meld_Graph/.freesurfer_wrappers:$PATH"
echo "FreeSurfer wrappers added to PATH"

# Verify wrapper availability
if ! command -v recon-all &> /dev/null; then
    echo "ERROR: recon-all wrapper not found in PATH"
    exit 1
fi
echo "✓ FreeSurfer wrappers verified"

# Set FreeSurfer license
export FS_LICENSE="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/freesurfer_license/license.txt"
if [ ! -f "$FS_LICENSE" ]; then
    echo "ERROR: FreeSurfer license not found: $FS_LICENSE"
    exit 1
fi
echo "✓ FreeSurfer license found"

echo ""
echo "Environment configured successfully"
echo "========================================="
echo ""

# ============================================================================
# RUN PIPELINE
# ============================================================================

# Parse subject ID from command line or use default
SUBJECT_ID="${1:-sub-03}"

echo "Running complete MELD pipeline for: $SUBJECT_ID"
echo "  Stage 1: FreeSurfer segmentation & feature extraction"
echo "  Stage 2: Preprocessing & normalization  "
echo "  Stage 3: Prediction & report generation"
echo ""

# Run the complete pipeline
python scripts/new_patient_pipeline/new_pt_pipeline.py -id "$SUBJECT_ID"

EXIT_CODE=$?

# ============================================================================
# REPORT RESULTS
# ============================================================================

echo ""
echo "========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Pipeline completed successfully!"
    echo ""
    echo "Outputs:"
    echo "  FreeSurfer:"
    ls -lh meld_data/output/fs_outputs/$SUBJECT_ID/surf/lh.white 2>/dev/null && echo "    ✓ Cortical surfaces"
    
    echo "  Feature Matrix:"
    ls -lh meld_data/output/preprocessed_surf_data/MELD_noHarmo/*.hdf5 2>/dev/null | grep -v "^total" && echo "    ✓ HDF5 matrices"
    
    echo "  Predictions:"
    ls -lh meld_data/output/predictions_reports/$SUBJECT_ID/predictions/*.nii.gz 2>/dev/null && echo "    ✓ Prediction volumes"
    
    echo "  Reports:"
    ls -lh meld_data/output/predictions_reports/$SUBJECT_ID/reports/*.pdf 2>/dev/null && echo "    ✓ PDF reports"
else
    echo "✗ Pipeline failed with exit code: $EXIT_CODE"
    echo ""
    echo "Check logs:"
    echo "  - SLURM log: logs/meld_pipeline_${SLURM_JOB_ID}.err"
    echo "  - Pipeline log: meld_data/logs/MELD_pipeline_*.log"
fi

echo ""
echo "End time: $(date)"
echo "========================================="

exit $EXIT_CODE
