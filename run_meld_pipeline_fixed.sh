#!/bin/bash
#SBATCH --job-name=meld_pipeline
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/meld_pipeline_%j.out
#SBATCH --error=logs/meld_pipeline_%j.err
#SBATCH --mail-type=END,FAIL
##SBATCH --mail-user=you@example.com

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

if [ -n "$SLURM_SUBMIT_DIR" ]; then
    BASE_DIR="$SLURM_SUBMIT_DIR"
else
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
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
PYTHON_BIN="${MELD_PYTHON:-$(command -v python3)}"
if [ -z "$PYTHON_BIN" ] || [ ! -x "$PYTHON_BIN" ]; then
    echo "ERROR: Set MELD_PYTHON to your meld_graph Python, or install python3 on PATH"
    exit 1
fi
echo "✓ Python: $PYTHON_BIN ($($PYTHON_BIN --version))"

# Verify input data exists
INPUT_DIR="${MELD_DATA_DIR}/input/${SUBJECT_ID}/anat"
if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    echo "Please ensure subject data is in BIDS format at: ${MELD_DATA_DIR}/input/${SUBJECT_ID}/"
    exit 1
fi

T1_FILE="${INPUT_DIR}/${SUBJECT_ID}_T1w.nii.gz"
FLAIR_FILE="${INPUT_DIR}/${SUBJECT_ID}_FLAIR.nii.gz"

if [ ! -f "$T1_FILE" ]; then
    echo "ERROR: T1 file not found: $T1_FILE"
    exit 1
fi
echo "✓ T1 file: $T1_FILE"

if [ -f "$FLAIR_FILE" ]; then
    echo "✓ FLAIR file: $FLAIR_FILE"
else
    echo "⚠ WARNING: FLAIR file not found (optional): $FLAIR_FILE"
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
