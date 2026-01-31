#!/bin/bash
# Quick safety check before running MELD pipeline

SUBJECT_ID="$1"

if [ -z "$SUBJECT_ID" ]; then
    echo "Usage: $0 <subject_id>"
    exit 1
fi

echo "════════════════════════════════════════════════════════════════"
echo "  MELD Pipeline Safety Check for: $SUBJECT_ID"
echo "════════════════════════════════════════════════════════════════"
echo ""

ISSUES=0
WARNINGS=0

# 1. Check for running jobs on same subject
echo "🔍 Checking for conflicting jobs..."
RUNNING=$(squeue -u $USER -o "%.18i %.50j" 2>/dev/null | grep -c "$SUBJECT_ID" || true)
if [ "$RUNNING" -gt 0 ]; then
    echo "  ❌ CRITICAL: Job already running for $SUBJECT_ID!"
    echo "     This will cause DATA CORRUPTION!"
    squeue -u $USER 2>/dev/null | grep "$SUBJECT_ID" || true
    ISSUES=$((ISSUES+1))
else
    echo "  ✅ No conflicting jobs"
fi

# 2. Check disk space
echo ""
echo "🔍 Checking disk space..."
AVAIL_GB=$(df /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/ | tail -1 | awk '{print int($4/1024/1024)}')
if [ "$AVAIL_GB" -lt 50 ]; then
    echo "  ❌ CRITICAL: Only ${AVAIL_GB}GB free (need >50GB)"
    ISSUES=$((ISSUES+1))
elif [ "$AVAIL_GB" -lt 100 ]; then
    echo "  ⚠️  WARNING: Only ${AVAIL_GB}GB free (recommended >100GB)"
    WARNINGS=$((WARNINGS+1))
else
    echo "  ✅ Adequate space: ${AVAIL_GB}GB available"
fi

# 3. Check input data
echo ""
echo "🔍 Checking input data..."
INPUT_DIR="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph/meld_data/input/$SUBJECT_ID/anat"
if [ ! -f "$INPUT_DIR/${SUBJECT_ID}_T1w.nii.gz" ]; then
    echo "  ❌ CRITICAL: T1w image missing"
    ISSUES=$((ISSUES+1))
else
    echo "  ✅ T1w image found"
fi

if [ ! -f "$INPUT_DIR/${SUBJECT_ID}_FLAIR.nii.gz" ]; then
    echo "  ⚠️  WARNING: FLAIR image missing (reduces sensitivity)"
    WARNINGS=$((WARNINGS+1))
else
    echo "  ✅ FLAIR image found"
fi

if [ ! -f "$INPUT_DIR/${SUBJECT_ID}_T1w.json" ]; then
    echo "  ⚠️  WARNING: T1w JSON sidecar missing"
    WARNINGS=$((WARNINGS+1))
else
    echo "  ✅ T1w metadata found"
fi

# 4. Check for partial previous runs
echo ""
echo "🔍 Checking for partial previous runs..."
if [ -d "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph/meld_data/output/fs_outputs/$SUBJECT_ID" ]; then
    if [ -f "/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph/meld_data/output/predictions_reports/$SUBJECT_ID/reports/MELD_report_${SUBJECT_ID}.pdf" ]; then
        echo "  ℹ️  INFO: Complete previous run found (will be overwritten)"
    else
        echo "  ⚠️  WARNING: Partial previous run detected"
        echo "     Pipeline will resume from checkpoint"
        WARNINGS=$((WARNINGS+1))
    fi
else
    echo "  ✅ No previous run (clean start)"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"

if [ $ISSUES -gt 0 ]; then
    echo "❌ UNSAFE TO RUN: $ISSUES critical issue(s) found"
    echo ""
    echo "DO NOT SUBMIT until issues are resolved!"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "⚠️  SAFE WITH WARNINGS: $WARNINGS warning(s) found"
    echo ""
    echo "Safe to run, but review warnings above."
    echo ""
    echo "To submit:"
    echo "  sbatch run_meld_pipeline_fixed.sh $SUBJECT_ID"
    exit 0
else
    echo "✅ ALL CLEAR - Safe to run"
    echo ""
    echo "To submit:"
    echo "  sbatch run_meld_pipeline_fixed.sh $SUBJECT_ID"
    exit 0
fi
