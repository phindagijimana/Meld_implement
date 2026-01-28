#!/bin/bash
#
# MELD Graph Pipeline with Containerized FreeSurfer
# This script runs the MELD pipeline using FreeSurfer from an Apptainer container
#

set -e

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINER_DIR="$BASE_DIR/containers"
LICENSE_DIR="$BASE_DIR/freesurfer_license"
MELD_DATA="$SCRIPT_DIR/meld_data"

# FreeSurfer container
FS_CONTAINER="$CONTAINER_DIR/freesurfer-7.4.1.sif"
FS_LICENSE="$LICENSE_DIR/license.txt"

# Check if container exists
if [ ! -f "$FS_CONTAINER" ]; then
    echo "Error: FreeSurfer container not found at: $FS_CONTAINER"
    echo "Please ensure FreeSurfer container is downloaded."
    exit 1
fi

# Check if license exists
if [ ! -f "$FS_LICENSE" ]; then
    echo "============================================================"
    echo "ERROR: FreeSurfer License Not Found!"
    echo "============================================================"
    echo ""
    echo "FreeSurfer requires a FREE license to run."
    echo ""
    echo "To get your license:"
    echo "  1. Register at: https://surfer.nmr.mgh.harvard.edu/registration.html"
    echo "  2. Download the license.txt file from the email"
    echo "  3. Save it to: $LICENSE_DIR/license.txt"
    echo ""
    echo "For more details, see: $LICENSE_DIR/GET_LICENSE.md"
    echo ""
    echo "============================================================"
    exit 1
fi

echo "============================================================"
echo "MELD Graph with Containerized FreeSurfer"
echo "============================================================"
echo "FreeSurfer Container: $FS_CONTAINER"
echo "FreeSurfer License: $FS_LICENSE"
echo "MELD Data: $MELD_DATA"
echo "============================================================"
echo ""

# Activate conda environment (outside container for MELD Python)
if [ -z "$CONDA_DEFAULT_ENV" ] || [ "$CONDA_DEFAULT_ENV" != "meld_graph" ]; then
    echo "Activating meld_graph conda environment..."
    eval "$(/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/miniconda3/bin/conda shell.bash hook)"
    conda activate meld_graph
fi

# Create wrapper script directory
WRAPPER_DIR="$SCRIPT_DIR/.freesurfer_wrappers"
mkdir -p "$WRAPPER_DIR"

# Create wrapper scripts for FreeSurfer commands
# These will be called by MELD but execute inside the container
cat > "$WRAPPER_DIR/recon-all" << 'WRAPPER_EOF'
#!/bin/bash
FS_CONTAINER="__FS_CONTAINER__"
LICENSE_DIR="__LICENSE_DIR__"
MELD_DATA="__MELD_DATA__"

apptainer exec \
    --bind "$MELD_DATA:$MELD_DATA" \
    --bind "$LICENSE_DIR:/license" \
    --env FS_LICENSE=/license/license.txt \
    --env FREESURFER_HOME=/usr/local/freesurfer \
    "$FS_CONTAINER" \
    bash -c "source /usr/local/freesurfer/SetUpFreeSurfer.sh && recon-all $*"
WRAPPER_EOF

# Replace placeholders
sed -i "s|__FS_CONTAINER__|$FS_CONTAINER|g" "$WRAPPER_DIR/recon-all"
sed -i "s|__LICENSE_DIR__|$LICENSE_DIR|g" "$WRAPPER_DIR/recon-all"
sed -i "s|__MELD_DATA__|$MELD_DATA|g" "$WRAPPER_DIR/recon-all"
chmod +x "$WRAPPER_DIR/recon-all"

# Create similar wrappers for other FreeSurfer commands
for cmd in mri_convert mris_convert mris_ca_label surfreg; do
    cat > "$WRAPPER_DIR/$cmd" << 'WRAPPER_EOF2'
#!/bin/bash
FS_CONTAINER="__FS_CONTAINER__"
LICENSE_DIR="__LICENSE_DIR__"
MELD_DATA="__MELD_DATA__"
CMD_NAME="__CMD_NAME__"

apptainer exec \
    --bind "$MELD_DATA:$MELD_DATA" \
    --bind "$LICENSE_DIR:/license" \
    --env FS_LICENSE=/license/license.txt \
    --env FREESURFER_HOME=/usr/local/freesurfer \
    "$FS_CONTAINER" \
    bash -c "source /usr/local/freesurfer/SetUpFreeSurfer.sh && $CMD_NAME $*"
WRAPPER_EOF2
    
    sed -i "s|__FS_CONTAINER__|$FS_CONTAINER|g" "$WRAPPER_DIR/$cmd"
    sed -i "s|__LICENSE_DIR__|$LICENSE_DIR|g" "$WRAPPER_DIR/$cmd"
    sed -i "s|__MELD_DATA__|$MELD_DATA|g" "$WRAPPER_DIR/$cmd"
    sed -i "s|__CMD_NAME__|$cmd|g" "$WRAPPER_DIR/$cmd"
    chmod +x "$WRAPPER_DIR/$cmd"
done

# Add wrapper directory to PATH (so MELD pipeline finds these first)
export PATH="$WRAPPER_DIR:$PATH"

# Create a local FreeSurfer directory structure for checks
LOCAL_FS="$WRAPPER_DIR/freesurfer"
mkdir -p "$LOCAL_FS/bin"
mkdir -p "$LOCAL_FS/subjects"

# Extract fsaverage_sym template from container if not already present
if [ ! -d "$LOCAL_FS/subjects/fsaverage_sym" ]; then
    echo "Extracting fsaverage_sym template from container..."
    apptainer exec "$FS_CONTAINER" tar -C /usr/local/freesurfer/subjects -cf - fsaverage_sym | tar -C "$LOCAL_FS/subjects" -xf -
    echo "Template extraction complete."
fi

# Set FreeSurfer environment variables (for MELD to use)
export FREESURFER_HOME="$LOCAL_FS"
export SUBJECTS_DIR="$MELD_DATA/output/fs_outputs"
export FS_LICENSE="$FS_LICENSE"

# Create dummy SetUpFreeSurfer.sh to pass FreeSurfer initialization check
cat > "$LOCAL_FS/SetUpFreeSurfer.sh" << 'EOF'
#!/bin/bash
# Dummy FreeSurfer setup for container-based installation
# All FreeSurfer commands are wrapped to run in container
export FREESURFER_HOME="$(dirname "${BASH_SOURCE[0]}")"
exit 0
EOF
chmod +x "$LOCAL_FS/SetUpFreeSurfer.sh"

# Copy wrapper scripts to $FREESURFER_HOME/bin as well
cp "$WRAPPER_DIR/recon-all" "$LOCAL_FS/bin/"
cp "$WRAPPER_DIR/mri_convert" "$LOCAL_FS/bin/"
cp "$WRAPPER_DIR/mris_convert" "$LOCAL_FS/bin/"
cp "$WRAPPER_DIR/mris_ca_label" "$LOCAL_FS/bin/"
cp "$WRAPPER_DIR/surfreg" "$LOCAL_FS/bin/"

# Create dummy freeview command to pass FreeSurfer check
cat > "$WRAPPER_DIR/freeview" << 'EOF'
#!/bin/bash
# Dummy freeview for container setup
exit 0
EOF
chmod +x "$WRAPPER_DIR/freeview"

# Run the MELD pipeline (outside container, using conda env)
echo "Starting MELD pipeline..."
echo "Arguments: $@"
echo "PATH: $PATH"
echo "FREESURFER_HOME: $FREESURFER_HOME"
echo "FS_LICENSE: $FS_LICENSE"
echo "CONDA_DEFAULT_ENV: $CONDA_DEFAULT_ENV"
echo ""

cd "$SCRIPT_DIR"
echo "Running: python scripts/new_patient_pipeline/new_pt_pipeline.py $@"
python scripts/new_patient_pipeline/new_pt_pipeline.py "$@"
EXIT_CODE=$?
echo "Python script exited with code: $EXIT_CODE"

echo ""
echo "============================================================"
echo "Pipeline completed!"
echo "============================================================"


