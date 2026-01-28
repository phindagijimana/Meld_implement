# =============================================================================
# MELD Graph Pipeline Configuration
# =============================================================================
# 
# This configuration file contains all the settings and paths for the
# MELD Graph pipeline implementation.
#
# Author: AI Assistant
# Date: 2025-10-28
# Version: 2.0
#
# =============================================================================

# =============================================================================
# SYSTEM CONFIGURATION
# =============================================================================

# SLURM Configuration
SLURM_JOB_NAME="meld_pipeline"
SLURM_PARTITION="general"
SLURM_NODES=1
SLURM_NTASKS=1
SLURM_CPUS_PER_TASK=8
SLURM_MEMORY="32G"
SLURM_TIME="12:00:00"

# Pipeline Configuration
PIPELINE_NAME="MELD Graph Pipeline"
PIPELINE_VERSION="2.0"
MELD_GRAPH_VERSION="2.2.2"
PYTHON_VERSION="3.9"

# =============================================================================
# PATH CONFIGURATION
# =============================================================================

# Base paths
WORKSPACE_ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph"
MELD_GRAPH_DIR="${WORKSPACE_ROOT}/meld_graph"
CONTAINER_DIR="${WORKSPACE_ROOT}/containers"
LICENSE_DIR="${WORKSPACE_ROOT}/freesurfer_license"
LOGS_DIR="${WORKSPACE_ROOT}/logs"

# FreeSurfer Configuration
FREESURFER_CONTAINER="${CONTAINER_DIR}/freesurfer-7.4.1.sif"
FREESURFER_LICENSE="${LICENSE_DIR}/license.txt"
FREESURFER_HOME="${MELD_GRAPH_DIR}/.freesurfer_wrappers/freesurfer"
SUBJECTS_DIR="${MELD_GRAPH_DIR}/meld_data/output/fs_outputs"

# Data paths
INPUT_DATA_DIR="${MELD_GRAPH_DIR}/meld_data/input"
OUTPUT_DATA_DIR="${MELD_GRAPH_DIR}/meld_data/output"
PREDICTIONS_DIR="${OUTPUT_DATA_DIR}/predictions_reports"
REPORTS_DIR="${OUTPUT_DATA_DIR}/predictions_reports"

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

# Conda environment
CONDA_ENV_NAME="meld_graph"

# Python paths
PYTHON_SCRIPT_DIR="${MELD_GRAPH_DIR}/scripts/new_patient_pipeline"
MAIN_PIPELINE_SCRIPT="${PYTHON_SCRIPT_DIR}/new_pt_pipeline.py"
SEGMENTATION_SCRIPT="${PYTHON_SCRIPT_DIR}/run_script_segmentation.py"
PREPROCESSING_SCRIPT="${PYTHON_SCRIPT_DIR}/run_script_preprocessing.py"
PREDICTION_SCRIPT="${PYTHON_SCRIPT_DIR}/run_script_prediction.py"

# =============================================================================
# VALIDATION CONFIGURATION
# =============================================================================

# Required file extensions
T1W_EXTENSION="_T1w.nii.gz"
FLAIR_EXTENSION="_FLAIR.nii.gz"
JSON_EXTENSION=".json"

# Expected output files
PREDICTION_FILES=("prediction.nii.gz" "lh.prediction.nii.gz" "rh.prediction.nii.gz")
REPORT_FILES=("MELD_report_*.pdf" "inflatbrain_*.png" "info_clusters_*.csv")

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

# Log levels
LOG_LEVELS=("INFO" "WARN" "ERROR" "SUCCESS" "DEBUG")

# Log file naming
LOG_FILE_PREFIX="meld_pipeline"
LOG_FILE_SUFFIX=".log"

# =============================================================================
# ERROR HANDLING CONFIGURATION
# =============================================================================

# Exit codes
EXIT_SUCCESS=0
EXIT_GENERAL_ERROR=1
EXIT_MISSING_FILE=2
EXIT_INVALID_INPUT=3
EXIT_PIPELINE_ERROR=4

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=30

# =============================================================================
# PERFORMANCE CONFIGURATION
# =============================================================================

# Memory limits
MAX_MEMORY_USAGE="90%"

# Disk space requirements (in GB)
MIN_DISK_SPACE=10

# Processing timeouts (in minutes)
SEGMENTATION_TIMEOUT=360  # 6 hours
PREPROCESSING_TIMEOUT=60  # 1 hour
PREDICTION_TIMEOUT=30     # 30 minutes

# =============================================================================
# QUALITY CONTROL CONFIGURATION
# =============================================================================

# File size thresholds (in MB)
MIN_T1W_SIZE=5
MIN_FLAIR_SIZE=3
MAX_T1W_SIZE=200
MAX_FLAIR_SIZE=150

# Validation checks
ENABLE_FILE_SIZE_CHECK=true
ENABLE_DISK_SPACE_CHECK=true
ENABLE_MEMORY_CHECK=true
ENABLE_OUTPUT_VALIDATION=true
