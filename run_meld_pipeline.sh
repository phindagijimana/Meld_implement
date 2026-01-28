#!/bin/bash

# =============================================================================
# MELD Graph Pipeline - Professional Implementation
# =============================================================================
# 
# This script implements the MELD Graph pipeline for FCD lesion detection
# following the official documentation and best practices.
#
# Author: AI Assistant
# Date: $(date +%Y-%m-%d)
# Version: 2.0
#
# Dependencies:
# - MELD Graph 2.2.2+
# - FreeSurfer 7.4.1+ (containerized)
# - Python 3.9+
# - SLURM workload manager
#
# Usage:
#   sbatch run_meld_pipeline.sh <subject_id>
#   Example: sbatch run_meld_pipeline.sh sub-03
#
# =============================================================================

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# SLURM Configuration
#SBATCH --job-name=meld_pipeline
#SBATCH --partition=general
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/meld_pipeline_%j.out
#SBATCH --error=logs/meld_pipeline_%j.err

# Pipeline Configuration
readonly SCRIPT_NAME="MELD Graph Pipeline"
readonly VERSION="2.0"
readonly MELD_GRAPH_VERSION="2.2.2"

# Path Configuration
readonly WORKSPACE_ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph"
readonly MELD_GRAPH_DIR="${WORKSPACE_ROOT}/meld_graph"
readonly CONTAINER_DIR="${WORKSPACE_ROOT}/containers"
readonly LICENSE_DIR="${WORKSPACE_ROOT}/freesurfer_license"
readonly LOGS_DIR="${WORKSPACE_ROOT}/logs"

# Environment Configuration
readonly FREESURFER_CONTAINER="${CONTAINER_DIR}/freesurfer-7.4.1.sif"
readonly FREESURFER_LICENSE="${LICENSE_DIR}/license.txt"
readonly FREESURFER_HOME="${MELD_GRAPH_DIR}/.freesurfer_wrappers/freesurfer"
readonly SUBJECTS_DIR="${MELD_GRAPH_DIR}/meld_data/output/fs_outputs"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging function with timestamp and log levels
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Pipeline failed at line ${line_number} with exit code ${exit_code}"
    log_error "Check logs for detailed error information"
    exit ${exit_code}
}

# Set error trap
trap 'handle_error $LINENO' ERR

# Validation function for required files
validate_environment() {
    log_info "Validating environment setup..."
    
    # Check workspace directory
    if [[ ! -d "${WORKSPACE_ROOT}" ]]; then
        log_error "Workspace root not found: ${WORKSPACE_ROOT}"
        exit 1
    fi
    
    # Check MELD Graph directory
    if [[ ! -d "${MELD_GRAPH_DIR}" ]]; then
        log_error "MELD Graph directory not found: ${MELD_GRAPH_DIR}"
        exit 1
    fi
    
    # Check FreeSurfer container
    if [[ ! -f "${FREESURFER_CONTAINER}" ]]; then
        log_error "FreeSurfer container not found: ${FREESURFER_CONTAINER}"
        exit 1
    fi
    
    # Check FreeSurfer license
    if [[ ! -f "${FREESURFER_LICENSE}" ]]; then
        log_error "FreeSurfer license not found: ${FREESURFER_LICENSE}"
        exit 1
    fi
    
    # Check logs directory
    if [[ ! -d "${LOGS_DIR}" ]]; then
        log_warn "Creating logs directory: ${LOGS_DIR}"
        mkdir -p "${LOGS_DIR}"
    fi
    
    log_success "Environment validation completed"
}

# System information logging
log_system_info() {
    log_info "System Information:"
    log_info "  Hostname: $(hostname)"
    log_info "  CPUs: $(nproc)"
    log_info "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    log_info "  Working Directory: $(pwd)"
    log_info "  User: $(whoami)"
    log_info "  Job ID: ${SLURM_JOB_ID:-N/A}"
    log_info "  Node: ${SLURM_NODELIST:-N/A}"
}

# =============================================================================
# MAIN PIPELINE FUNCTIONS
# =============================================================================

# Initialize the pipeline environment
initialize_pipeline() {
    log_info "Initializing ${SCRIPT_NAME} v${VERSION}"
    
    # Change to MELD Graph directory
    cd "${MELD_GRAPH_DIR}" || {
        log_error "Failed to change to MELD Graph directory"
        exit 1
    }
    
    # Set up environment variables
    export FREESURFER_HOME="${FREESURFER_HOME}"
    export SUBJECTS_DIR="${SUBJECTS_DIR}"
    export FS_LICENSE="${FREESURFER_LICENSE}"
    
    # Source FreeSurfer environment
    if [[ -f "${FREESURFER_HOME}/SetUpFreeSurfer.sh" ]]; then
        source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
        log_success "FreeSurfer environment sourced"
    else
        log_error "FreeSurfer setup script not found"
        exit 1
    fi
    
    # Activate conda environment
    if command -v conda >/dev/null 2>&1; then
        eval "$(conda shell.bash hook)"
        conda activate meld_graph
        log_success "Conda environment activated: meld_graph"
    else
        log_warn "Conda not found, using system Python"
    fi
    
    log_success "Pipeline initialization completed"
}

# Validate subject data
validate_subject_data() {
    local subject_id="$1"
    
    log_info "Validating data for subject: ${subject_id}"
    
    # Check input directory
    local input_dir="${MELD_GRAPH_DIR}/meld_data/input/${subject_id}/anat"
    if [[ ! -d "${input_dir}" ]]; then
        log_error "Input directory not found: ${input_dir}"
        exit 1
    fi
    
    # Check required input files
    local t1_file="${input_dir}/${subject_id}_T1w.nii.gz"
    local flair_file="${input_dir}/${subject_id}_FLAIR.nii.gz"
    
    if [[ ! -f "${t1_file}" ]]; then
        log_error "T1w file not found: ${t1_file}"
        exit 1
    fi
    
    if [[ ! -f "${flair_file}" ]]; then
        log_error "FLAIR file not found: ${flair_file}"
        exit 1
    fi
    
    # Log file sizes
    local t1_size=$(du -h "${t1_file}" | cut -f1)
    local flair_size=$(du -h "${flair_file}" | cut -f1)
    
    log_info "Subject data validation:"
    log_info "  T1w: ${t1_file} (${t1_size})"
    log_info "  FLAIR: ${flair_file} (${flair_size})"
    
    log_success "Subject data validation completed"
}

# Run the MELD Graph pipeline
run_meld_pipeline() {
    local subject_id="$1"
    
    log_info "Starting MELD Graph pipeline for subject: ${subject_id}"
    
    # Run the main pipeline script
    local pipeline_script="${MELD_GRAPH_DIR}/scripts/new_patient_pipeline/new_pt_pipeline.py"
    
    if [[ ! -f "${pipeline_script}" ]]; then
        log_error "Pipeline script not found: ${pipeline_script}"
        exit 1
    fi
    
    log_info "Executing: python ${pipeline_script} -id ${subject_id}"
    
    # Execute the pipeline
    python "${pipeline_script}" -id "${subject_id}" || {
        log_error "MELD pipeline execution failed"
        exit 1
    }
    
    log_success "MELD Graph pipeline completed successfully"
}

# Verify pipeline outputs
verify_outputs() {
    local subject_id="$1"
    
    log_info "Verifying pipeline outputs for subject: ${subject_id}"
    
    # Check predictions directory
    local predictions_dir="${MELD_GRAPH_DIR}/meld_data/output/predictions_reports/${subject_id}/predictions"
    if [[ -d "${predictions_dir}" ]]; then
        log_success "Predictions directory found: ${predictions_dir}"
        
        # List prediction files
        local prediction_files=$(find "${predictions_dir}" -name "*.nii.gz" -type f)
        if [[ -n "${prediction_files}" ]]; then
            log_info "Prediction files generated:"
            echo "${prediction_files}" | while read -r file; do
                local size=$(du -h "${file}" | cut -f1)
                log_info "  $(basename "${file}") (${size})"
            done
        else
            log_warn "No prediction files found"
        fi
    else
        log_warn "Predictions directory not found: ${predictions_dir}"
    fi
    
    # Check reports directory
    local reports_dir="${MELD_GRAPH_DIR}/meld_data/output/predictions_reports/${subject_id}/reports"
    if [[ -d "${reports_dir}" ]]; then
        log_success "Reports directory found: ${reports_dir}"
        
        # List report files
        local report_files=$(find "${reports_dir}" -name "*.pdf" -o -name "*.png" -o -name "*.csv" -type f)
        if [[ -n "${report_files}" ]]; then
            log_info "Report files generated:"
            echo "${report_files}" | while read -r file; do
                local size=$(du -h "${file}" | cut -f1)
                log_info "  $(basename "${file}") (${size})"
            done
        else
            log_warn "No report files found"
        fi
    else
        log_warn "Reports directory not found: ${reports_dir}"
    fi
    
    log_success "Output verification completed"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Get subject ID from command line argument
    local subject_id="${1:-}"
    
    if [[ -z "${subject_id}" ]]; then
        log_error "Subject ID not provided"
        log_error "Usage: $0 <subject_id>"
        log_error "Example: $0 sub-03"
        exit 1
    fi
    
    # Pipeline execution
    log_info "========================================="
    log_info "${SCRIPT_NAME} v${VERSION}"
    log_info "========================================="
    log_info "Subject ID: ${subject_id}"
    log_info "Start time: $(date)"
    log_info "========================================="
    
    # Execute pipeline steps
    validate_environment
    log_system_info
    initialize_pipeline
    validate_subject_data "${subject_id}"
    run_meld_pipeline "${subject_id}"
    verify_outputs "${subject_id}"
    
    # Pipeline completion
    log_info "========================================="
    log_success "Pipeline completed successfully!"
    log_info "Subject: ${subject_id}"
    log_info "End time: $(date)"
    log_info "========================================="
}

# Execute main function with all arguments
main "$@"
