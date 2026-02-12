#!/bin/bash

################################################################################
# MELD Graph Official Container Wrapper Script
# 
# This script provides an easy interface to run the official MELD Graph v2.2.4
# Singularity container with proper license bindings and environment setup.
#
# Usage:
#   ./run_meld_container.sh <subject_id>
#   ./run_meld_container.sh <subject_id> [stage]
#   ./run_meld_container.sh --help
#   ./run_meld_container.sh --shell
#   ./run_meld_container.sh --test
#
# Examples:
#   ./run_meld_container.sh sub-001                    # Run full pipeline
#   ./run_meld_container.sh sub-001 segmentation       # Run only segmentation
#   ./run_meld_container.sh sub-001 preprocessing      # Run only preprocessing
#   ./run_meld_container.sh sub-001 prediction         # Run only prediction
#   ./run_meld_container.sh --shell                    # Interactive shell
#   ./run_meld_container.sh --test                     # Run test suite
#
################################################################################

set -e

# Configuration
CONTAINER_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/docker_test"
CONTAINER_IMAGE="${CONTAINER_DIR}/meld_graph_v2.2.4.sif"
MELD_DATA_DIR="${CONTAINER_DIR}/meld_data"
FS_LICENSE="${CONTAINER_DIR}/freesurfer_license.txt"
MELD_LICENSE="${CONTAINER_DIR}/meld_license.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}  MELD Graph Official Container (v2.2.4)${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_help() {
    cat << EOF
MELD Graph Official Container Wrapper

Usage:
  $(basename "$0") <subject_id>                  Run full pipeline
  $(basename "$0") <subject_id> [stage]          Run specific stage
  $(basename "$0") --help                        Show this help
  $(basename "$0") --shell                       Open interactive shell
  $(basename "$0") --test                        Run test suite
  $(basename "$0") --validate <subject_id>       Validate subject data

Stages:
  segmentation      Run FreeSurfer segmentation and feature extraction
  preprocessing     Run preprocessing and normalization
  prediction        Run GNN prediction and generate reports

Examples:
  $(basename "$0") sub-001
  $(basename "$0") sub-001 segmentation
  $(basename "$0") --shell
  $(basename "$0") --validate sub-001

Environment:
  Container:  ${CONTAINER_IMAGE}
  Data:       ${MELD_DATA_DIR}
  FS License: ${FS_LICENSE}
  MELD Lic:   ${MELD_LICENSE}

EOF
}

validate_environment() {
    print_info "Validating environment..."
    
    # Check container exists
    if [ ! -f "$CONTAINER_IMAGE" ]; then
        print_error "Container image not found: $CONTAINER_IMAGE"
        exit 1
    fi
    print_success "Container image found"
    
    # Check data directory
    if [ ! -d "$MELD_DATA_DIR" ]; then
        print_error "Data directory not found: $MELD_DATA_DIR"
        exit 1
    fi
    print_success "Data directory found"
    
    # Check licenses
    if [ ! -f "$FS_LICENSE" ]; then
        print_error "FreeSurfer license not found: $FS_LICENSE"
        exit 1
    fi
    print_success "FreeSurfer license found"
    
    if [ ! -f "$MELD_LICENSE" ]; then
        print_error "MELD license not found: $MELD_LICENSE"
        exit 1
    fi
    print_success "MELD license found"
    
    # Check apptainer
    if ! command -v apptainer &> /dev/null; then
        print_error "apptainer not found in PATH"
        exit 1
    fi
    print_success "Apptainer found: $(apptainer --version)"
}

run_container() {
    local cmd="$@"
    
    apptainer exec \
        --bind "${MELD_DATA_DIR}:/data" \
        --bind "${FS_LICENSE}:/license.txt:ro" \
        --bind "${MELD_LICENSE}:/app/meld_license.txt:ro" \
        --env FS_LICENSE=/license.txt \
        --env MELD_LICENSE=/app/meld_license.txt \
        --env FREESURFER_HOME=/opt/freesurfer-7.2.0 \
        --pwd /app \
        "${CONTAINER_IMAGE}" \
        $cmd
}

validate_subject() {
    local subject_id="$1"
    local input_dir="${MELD_DATA_DIR}/input/${subject_id}/anat"
    
    print_info "Validating subject: $subject_id"
    
    if [ ! -d "$input_dir" ]; then
        print_error "Subject directory not found: $input_dir"
        return 1
    fi
    
    # Check for T1w
    if ls "$input_dir"/*T1w.nii.gz 1> /dev/null 2>&1; then
        print_success "T1w image found"
    else
        print_error "T1w image not found in $input_dir"
        return 1
    fi
    
    # Check for FLAIR (optional)
    if ls "$input_dir"/*FLAIR.nii.gz 1> /dev/null 2>&1; then
        print_success "FLAIR image found"
    else
        print_warning "FLAIR image not found (optional)"
    fi
    
    return 0
}

run_full_pipeline() {
    local subject_id="$1"
    
    print_header
    print_info "Running full MELD pipeline for: $subject_id"
    echo ""
    
    validate_environment
    echo ""
    
    validate_subject "$subject_id" || exit 1
    echo ""
    
    print_info "Starting pipeline..."
    echo ""
    
    run_container python /app/scripts/new_patient_pipeline/new_pt_pipeline.py "$subject_id"
    
    echo ""
    print_success "Pipeline completed for $subject_id"
}

run_stage() {
    local subject_id="$1"
    local stage="$2"
    
    print_header
    print_info "Running $stage stage for: $subject_id"
    echo ""
    
    validate_environment
    echo ""
    
    case "$stage" in
        segmentation)
            print_info "Running segmentation and feature extraction..."
            run_container python /app/scripts/new_patient_pipeline/run_script_segmentation.py "$subject_id"
            ;;
        preprocessing)
            print_info "Running preprocessing and normalization..."
            run_container python /app/scripts/new_patient_pipeline/run_script_preprocessing.py "$subject_id"
            ;;
        prediction)
            print_info "Running prediction and report generation..."
            run_container python /app/scripts/new_patient_pipeline/run_script_prediction.py "$subject_id"
            ;;
        *)
            print_error "Unknown stage: $stage"
            echo "Valid stages: segmentation, preprocessing, prediction"
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Stage $stage completed for $subject_id"
}

open_shell() {
    print_header
    print_info "Opening interactive shell in container..."
    echo ""
    
    validate_environment
    echo ""
    
    print_info "You are now inside the MELD Graph container"
    print_info "Data directory is mounted at: /data"
    print_info "MELD scripts are in: /app/scripts/new_patient_pipeline/"
    print_info "Type 'exit' to leave the container"
    echo ""
    
    run_container /bin/bash
}

run_tests() {
    print_header
    print_info "Running MELD Graph test suite..."
    echo ""
    
    validate_environment
    echo ""
    
    run_container pytest -v
    
    echo ""
    print_success "Tests completed"
}

# Main script
main() {
    cd "$CONTAINER_DIR"
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --shell|-s)
            open_shell
            exit 0
            ;;
        --test|-t)
            run_tests
            exit 0
            ;;
        --validate|-v)
            if [ -z "$2" ]; then
                print_error "Subject ID required for validation"
                exit 1
            fi
            print_header
            validate_environment
            echo ""
            validate_subject "$2"
            exit 0
            ;;
        --*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            # Subject ID provided
            SUBJECT_ID="$1"
            
            if [ -n "$2" ]; then
                # Stage specified
                run_stage "$SUBJECT_ID" "$2"
            else
                # Run full pipeline
                run_full_pipeline "$SUBJECT_ID"
            fi
            ;;
    esac
}

# Run main function
main "$@"
