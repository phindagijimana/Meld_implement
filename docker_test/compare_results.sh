#!/bin/bash

################################################################################
# Compare Results Between Custom Setup and Official Container
#
# This script helps compare outputs from your custom MELD setup vs the
# official container to validate consistency.
#
# Usage:
#   ./compare_results.sh <subject_id>
#
################################################################################

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <subject_id>"
    echo "Example: $0 sub-test001"
    exit 1
fi

SUBJECT_ID="$1"

# Paths
CUSTOM_OUTPUT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/meld_graph/meld_data/output"
CONTAINER_OUTPUT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/docker_test/meld_data/output"

echo "========================================================================"
echo "  Comparing Results: Custom Setup vs Official Container"
echo "  Subject: $SUBJECT_ID"
echo "========================================================================"
echo ""

# Check if outputs exist
echo "Checking output directories..."
echo ""

if [ -d "${CUSTOM_OUTPUT}/predictions/${SUBJECT_ID}" ]; then
    echo "[✓] Custom setup output found"
    CUSTOM_EXISTS=1
else
    echo "[✗] Custom setup output NOT found: ${CUSTOM_OUTPUT}/predictions/${SUBJECT_ID}"
    CUSTOM_EXISTS=0
fi

if [ -d "${CONTAINER_OUTPUT}/predictions/${SUBJECT_ID}" ]; then
    echo "[✓] Container output found"
    CONTAINER_EXISTS=1
else
    echo "[✗] Container output NOT found: ${CONTAINER_OUTPUT}/predictions/${SUBJECT_ID}"
    CONTAINER_EXISTS=0
fi

echo ""

if [ $CUSTOM_EXISTS -eq 0 ] || [ $CONTAINER_EXISTS -eq 0 ]; then
    echo "ERROR: One or both outputs missing. Please run both pipelines first."
    exit 1
fi

# Compare FreeSurfer outputs
echo "========================================================================"
echo "  FreeSurfer Outputs"
echo "========================================================================"
echo ""

CUSTOM_FS="${CUSTOM_OUTPUT}/fs_outputs/${SUBJECT_ID}"
CONTAINER_FS="${CONTAINER_OUTPUT}/fs_outputs/${SUBJECT_ID}"

if [ -d "$CUSTOM_FS" ] && [ -d "$CONTAINER_FS" ]; then
    echo "Comparing FreeSurfer surface statistics..."
    
    # Compare left hemisphere
    if [ -f "${CUSTOM_FS}/stats/lh.aparc.stats" ] && [ -f "${CONTAINER_FS}/stats/lh.aparc.stats" ]; then
        echo ""
        echo "Left Hemisphere (lh.aparc.stats):"
        echo "  Custom:    $(wc -l < ${CUSTOM_FS}/stats/lh.aparc.stats) lines"
        echo "  Container: $(wc -l < ${CONTAINER_FS}/stats/lh.aparc.stats) lines"
    fi
    
    # Compare right hemisphere
    if [ -f "${CUSTOM_FS}/stats/rh.aparc.stats" ] && [ -f "${CONTAINER_FS}/stats/rh.aparc.stats" ]; then
        echo ""
        echo "Right Hemisphere (rh.aparc.stats):"
        echo "  Custom:    $(wc -l < ${CUSTOM_FS}/stats/rh.aparc.stats) lines"
        echo "  Container: $(wc -l < ${CONTAINER_FS}/stats/rh.aparc.stats) lines"
    fi
else
    echo "[!] FreeSurfer outputs not found for comparison"
fi

echo ""

# Compare predictions
echo "========================================================================"
echo "  Prediction Outputs"
echo "========================================================================"
echo ""

CUSTOM_PRED="${CUSTOM_OUTPUT}/predictions/${SUBJECT_ID}"
CONTAINER_PRED="${CONTAINER_OUTPUT}/predictions/${SUBJECT_ID}"

# Compare cluster information
echo "Cluster Information:"
for hemi in lh rh; do
    CUSTOM_CSV="${CUSTOM_PRED}/predictions/info_clusters_${hemi}.csv"
    CONTAINER_CSV="${CONTAINER_PRED}/predictions/info_clusters_${hemi}.csv"
    
    if [ -f "$CUSTOM_CSV" ] && [ -f "$CONTAINER_CSV" ]; then
        CUSTOM_CLUSTERS=$(tail -n +2 "$CUSTOM_CSV" | wc -l)
        CONTAINER_CLUSTERS=$(tail -n +2 "$CONTAINER_CSV" | wc -l)
        
        echo ""
        echo "  ${hemi} clusters:"
        echo "    Custom:    $CUSTOM_CLUSTERS clusters"
        echo "    Container: $CONTAINER_CLUSTERS clusters"
        
        if [ $CUSTOM_CLUSTERS -gt 0 ] && [ $CONTAINER_CLUSTERS -gt 0 ]; then
            echo ""
            echo "    Top cluster confidence scores:"
            echo "    Custom:"
            tail -n +2 "$CUSTOM_CSV" | head -3 | awk -F',' '{print "      - " $1 ": " $3}'
            echo "    Container:"
            tail -n +2 "$CONTAINER_CSV" | head -3 | awk -F',' '{print "      - " $1 ": " $3}'
        fi
    fi
done

echo ""

# Compare PDF reports
echo "========================================================================"
echo "  Report Files"
echo "========================================================================"
echo ""

for hemi in lh rh; do
    CUSTOM_PDF="${CUSTOM_PRED}/predictions/${SUBJECT_ID}.${hemi}.pdf"
    CONTAINER_PDF="${CONTAINER_PRED}/predictions/${SUBJECT_ID}.${hemi}.pdf"
    
    if [ -f "$CUSTOM_PDF" ]; then
        CUSTOM_SIZE=$(du -h "$CUSTOM_PDF" | cut -f1)
        echo "[✓] Custom ${hemi} PDF: ${CUSTOM_SIZE}"
    else
        echo "[✗] Custom ${hemi} PDF not found"
    fi
    
    if [ -f "$CONTAINER_PDF" ]; then
        CONTAINER_SIZE=$(du -h "$CONTAINER_PDF" | cut -f1)
        echo "[✓] Container ${hemi} PDF: ${CONTAINER_SIZE}"
    else
        echo "[✗] Container ${hemi} PDF not found"
    fi
    echo ""
done

# Summary
echo "========================================================================"
echo "  Summary"
echo "========================================================================"
echo ""
echo "Custom Setup:"
echo "  Location: ${CUSTOM_OUTPUT}"
echo "  FreeSurfer: 7.4.1"
echo "  MELD Version: ~v2.2.2"
echo ""
echo "Official Container:"
echo "  Location: ${CONTAINER_OUTPUT}"
echo "  FreeSurfer: 7.2.0"
echo "  MELD Version: v2.2.4"
echo ""
echo "Note: Minor differences are expected due to:"
echo "  - Different FreeSurfer versions (7.4.1 vs 7.2.0)"
echo "  - Different MELD Graph versions (v2.2.2 vs v2.2.4)"
echo "  - Algorithm updates between versions"
echo ""
echo "For detailed comparison, manually inspect the PDF reports:"
echo "  Custom:    ${CUSTOM_PRED}/predictions/${SUBJECT_ID}.*.pdf"
echo "  Container: ${CONTAINER_PRED}/predictions/${SUBJECT_ID}.*.pdf"
echo ""
