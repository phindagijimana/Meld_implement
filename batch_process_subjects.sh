#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <subject1> [subject2] [subject3] ..."
    echo ""
    echo "Example:"
    echo "  $0 sub-URMC01 sub-URMC02 sub-URMC03"
    exit 1
fi

echo "========================================"
echo "  MELD Graph Batch Processing"
echo "========================================"
echo ""
echo "Submitting ${#@} subjects to SLURM..."
echo ""

JOB_IDS=()

for subject in "$@"; do
    echo "Submitting: $subject"
    
    JOB_OUTPUT=$(sbatch run_meld_pipeline.sh "$subject" 2>&1)
    
    if [ $? -eq 0 ]; then
        JOB_ID=$(echo "$JOB_OUTPUT" | grep -oP 'Submitted batch job \K[0-9]+')
        JOB_IDS+=("$JOB_ID")
        echo "  Job ID: $JOB_ID"
    else
        echo "  ERROR: Failed to submit $subject"
        echo "  $JOB_OUTPUT"
    fi
    
    sleep 1
done

echo ""
echo "========================================"
echo "  Batch Submission Complete"
echo "========================================"
echo ""
echo "Submitted ${#JOB_IDS[@]} jobs: ${JOB_IDS[*]}"
echo ""
echo "Monitor progress:"
echo "  squeue -j $(IFS=,; echo "${JOB_IDS[*]}")"
echo ""
echo "View logs:"
for i in "${!JOB_IDS[@]}"; do
    echo "  tail -f logs/meld_pipeline_${JOB_IDS[$i]}.out"
done
echo ""
