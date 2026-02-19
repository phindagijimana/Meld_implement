#!/bin/bash
#SBATCH --job-name=meld_pipeline
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/logs/meld_pipeline_%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/logs/meld_pipeline_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=pndagiji@urmc.rochester.edu

# =============================================================================
# MELD Graph Pipeline - Production Ready
# =============================================================================
# This script runs the complete MELD Graph pipeline for FCD lesion detection
# 
# Usage: sbatch run_meld_pipeline_fixed.sh <subject-id>
# Example: sbatch run_meld_pipeline_fixed.sh sub-036
#
# Default subject: sub-03
# =============================================================================

# Parse subject ID from command line or use default
SUBJECT_ID="${1:-sub-03}"

echo "============================================"
echo "MELD Graph Pipeline - Complete Run"
echo "============================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Subject: $SUBJECT_ID"
echo "Start time: $(date)"
echo ""

# =============================================================================
# DIRECTORY SETUP
# =============================================================================

BASE_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph"
MELD_DATA_DIR="${BASE_DIR}/meld_graph/meld_data"
LICENSE_FILE="${BASE_DIR}/freesurfer_license/license.txt"

# Create required directories
mkdir -p "${BASE_DIR}/logs"
mkdir -p "${MELD_DATA_DIR}/output"

echo "Base directory: $BASE_DIR"
echo "Data directory: $MELD_DATA_DIR"
echo ""

# =============================================================================
# FREESURFER CONFIGURATION
# =============================================================================

export FREESURFER_HOME="${BASE_DIR}/.freesurfer_wrappers/freesurfer"
export SUBJECTS_DIR="${MELD_DATA_DIR}/output"
export FS_LICENSE="${LICENSE_FILE}"

# Add FreeSurfer wrappers to PATH
export PATH="${BASE_DIR}/.freesurfer_wrappers:${PATH}"

# Parallelization settings
export OMP_NUM_THREADS=8
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=8

echo "FreeSurfer Configuration:"
echo "  FREESURFER_HOME: $FREESURFER_HOME"
echo "  SUBJECTS_DIR: $SUBJECTS_DIR"
echo "  Threads: $OMP_NUM_THREADS"
echo ""

# =============================================================================
# VERIFICATION
# =============================================================================

echo "Verifying environment..."

# Check FreeSurfer availability
if ! which recon-all &> /dev/null; then
    echo "ERROR: FreeSurfer not found in PATH"
    exit 1
fi
echo "✓ FreeSurfer found: $(which recon-all)"

# Check license file
if [ ! -f "$FS_LICENSE" ]; then
    echo "ERROR: FreeSurfer license not found at $FS_LICENSE"
    exit 1
fi
echo "✓ FreeSurfer license: $FS_LICENSE"

# Check Python
PYTHON_BIN="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/miniconda3/envs/meld_graph/bin/python"
if [ ! -f "$PYTHON_BIN" ]; then
    echo "ERROR: Python not found at $PYTHON_BIN"
    exit 1
fi
echo "✓ Python: $PYTHON_BIN ($($PYTHON_BIN --version))"

# Verify input data exists - support both flat and session structure
BASE_SUBJECT_DIR="${MELD_DATA_DIR}/input/${SUBJECT_ID}"
if [ ! -d "$BASE_SUBJECT_DIR" ]; then
    echo "ERROR: Subject directory not found: $BASE_SUBJECT_DIR"
    exit 1
fi

# Detect structure: flat (anat/) or session (ses-*/anat/)
if [ -d "${BASE_SUBJECT_DIR}/anat" ]; then
    INPUT_DIR="${BASE_SUBJECT_DIR}/anat"
    SESSION=""
    echo "✓ Using flat structure: ${INPUT_DIR}"
elif ls -d "${BASE_SUBJECT_DIR}"/ses-* 1> /dev/null 2>&1; then
    SESSION_DIR=$(ls -d "${BASE_SUBJECT_DIR}"/ses-* | head -1)
    INPUT_DIR="${SESSION_DIR}/anat"
    SESSION=$(basename "$SESSION_DIR")
    echo "✓ Using session structure: ${INPUT_DIR} (session: ${SESSION})"
    if [ ! -d "$INPUT_DIR" ]; then
        echo "ERROR: Session anat directory not found: $INPUT_DIR"
        exit 1
    fi
else
    echo "ERROR: Neither flat structure (anat/) nor session structure (ses-*/anat/) found"
    echo "Expected: ${BASE_SUBJECT_DIR}/anat/ or ${BASE_SUBJECT_DIR}/ses-*/anat/"
    exit 1
fi

# Verify files - they may have session labels in filenames
if ls "${INPUT_DIR}"/*T1w.nii.gz 1> /dev/null 2>&1; then
    T1_FILE=$(ls "${INPUT_DIR}"/*T1w.nii.gz | head -1)
    echo "✓ T1 file: $(basename $T1_FILE)"
else
    echo "ERROR: T1 file not found in: $INPUT_DIR"
    exit 1
fi

if ls "${INPUT_DIR}"/*FLAIR.nii.gz 1> /dev/null 2>&1; then
    FLAIR_FILE=$(ls "${INPUT_DIR}"/*FLAIR.nii.gz | head -1)
    echo "✓ FLAIR file: $(basename $FLAIR_FILE)"
else
    echo "⚠ WARNING: FLAIR file not found (optional)"
fi

echo ""
echo "All checks passed. Starting pipeline..."
echo "============================================"
echo ""

# =============================================================================
# RUN PIPELINE
# =============================================================================

echo "Pipeline Stages:"
echo "  Stage 1: FreeSurfer segmentation & feature extraction (6-12 hours)"
echo "  Stage 2: Preprocessing & normalization"
echo "  Stage 3: Prediction & report generation"
echo ""

# Change to pipeline directory
cd "${BASE_DIR}/meld_graph/scripts/new_patient_pipeline" || exit 1

# Run pipeline with unbuffered output
$PYTHON_BIN -u new_pt_pipeline.py -id "$SUBJECT_ID"

PIPELINE_EXIT_CODE=$?

# =============================================================================
# REPORT RESULTS
# =============================================================================

echo ""
echo "============================================"
echo "Pipeline Completed"
echo "============================================"
echo "Exit code: $PIPELINE_EXIT_CODE"
echo "End time: $(date)"
echo ""

if [ $PIPELINE_EXIT_CODE -eq 0 ]; then
    echo "✓ SUCCESS - All stages completed"
    echo ""
    echo "Output Summary:"
    
    # FreeSurfer outputs
    FS_DIR="${SUBJECTS_DIR}/${SUBJECT_ID}"
    if [ -d "$FS_DIR" ]; then
        echo "  FreeSurfer:"
        [ -f "$FS_DIR/mri/T1.mgz" ] && echo "    ✓ T1 volume"
        [ -f "$FS_DIR/surf/lh.white" ] && echo "    ✓ Cortical surfaces"
        [ -f "$FS_DIR/label/lh.aparc.annot" ] && echo "    ✓ Parcellation"
    fi
    
    # Feature matrices
    HDF5_DIR="${MELD_DATA_DIR}/output/preprocessed_surf_data/MELD_noHarmo"
    if [ -d "$HDF5_DIR" ]; then
        HDF5_COUNT=$(ls -1 "$HDF5_DIR"/*.hdf5 2>/dev/null | wc -l)
        if [ "$HDF5_COUNT" -gt 0 ]; then
            echo "  Feature Matrices:"
            echo "    ✓ $HDF5_COUNT HDF5 file(s)"
        fi
    fi
    
    # Predictions
    PRED_DIR="${MELD_DATA_DIR}/output/predictions_data_0.75_0.25/${SUBJECT_ID}"
    if [ -d "$PRED_DIR" ]; then
        NIFTI_COUNT=$(ls -1 "$PRED_DIR"/*.nii.gz 2>/dev/null | wc -l)
        PDF_COUNT=$(ls -1 "$PRED_DIR"/*.pdf 2>/dev/null | wc -l)
        
        echo "  Predictions:"
        [ "$NIFTI_COUNT" -gt 0 ] && echo "    ✓ $NIFTI_COUNT NIfTI volume(s)"
        [ "$PDF_COUNT" -gt 0 ] && echo "    ✓ $PDF_COUNT PDF report(s)"
    fi
    
    echo ""
    echo "Results location: ${MELD_DATA_DIR}/output/"
else
    echo "✗ FAILED - Pipeline exited with error code $PIPELINE_EXIT_CODE"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check SLURM logs: logs/meld_pipeline_${SLURM_JOB_ID}.err"
    echo "  2. Check pipeline log: ${MELD_DATA_DIR}/logs/MELD_pipeline_*.log"
    echo "  3. Review FreeSurfer logs: ${SUBJECTS_DIR}/${SUBJECT_ID}/scripts/"
fi

echo "============================================"

exit $PIPELINE_EXIT_CODE
