# MELD Graph Official Container Setup

This directory contains the official MELD Graph v2.2.4 Singularity container and a convenient wrapper script for running it.

## Quick Start

### Run Full Pipeline
```bash
./run_meld_container.sh sub-test001
```

### Run Individual Stages
```bash
# Segmentation only
./run_meld_container.sh sub-test001 segmentation

# Preprocessing only
./run_meld_container.sh sub-test001 preprocessing

# Prediction only
./run_meld_container.sh sub-test001 prediction
```

### Validate Subject Data
```bash
./run_meld_container.sh --validate sub-test001
```

### Interactive Shell
```bash
./run_meld_container.sh --shell
```

### Run Tests
```bash
./run_meld_container.sh --test
```

## Directory Structure

```
docker_test/
├── meld_graph_v2.2.4.sif          # Singularity container (4.7GB)
├── run_meld_container.sh          # Wrapper script
├── freesurfer_license.txt         # FreeSurfer license
├── meld_license.txt               # MELD license
└── meld_data/                     # Data directory
    ├── input/                     # Input BIDS data
    │   └── sub-*/anat/           # Subject anatomical scans
    ├── output/                    # Pipeline outputs
    │   ├── fs_outputs/           # FreeSurfer results
    │   └── predictions/          # Prediction results
    ├── models/                    # Pre-trained models
    └── meld_params/               # MELD parameters
```

## Container Contents

- **Python**: 3.9.25
- **FreeSurfer**: 7.2.0 (built-in)
- **FastSurfer**: 1.1.2
- **PyTorch**: 1.10.0
- **MELD Graph**: v2.2.4

## Adding New Subjects

Place subject data in BIDS format:

```bash
meld_data/input/
└── sub-NEWSUBJECT/
    └── anat/
        ├── sub-NEWSUBJECT_T1w.nii.gz       # Required
        ├── sub-NEWSUBJECT_T1w.json         # Optional
        ├── sub-NEWSUBJECT_FLAIR.nii.gz     # Optional
        └── sub-NEWSUBJECT_FLAIR.json       # Optional
```

Then run:
```bash
./run_meld_container.sh sub-NEWSUBJECT
```

## Comparison with Custom Setup

| Feature | Custom Setup | Official Container |
|---------|--------------|-------------------|
| Version | v2.2.2 based | v2.2.4 (latest) |
| FreeSurfer | 7.4.1 (separate) | 7.2.0 (built-in) |
| SLURM | ✓ Integrated | Manual |
| Batch Processing | ✓ Automated | Manual |
| Monitoring | ✓ Dashboard | Manual |
| Retry Logic | ✓ Built-in | None |
| Use Case | Production HPC | Validation & Testing |

## Troubleshooting

### Container Not Found
```bash
# Pull the container again
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/docker_test
export TMPDIR=$PWD/tmp
apptainer pull docker://meldproject/meld_graph:v2.2.4
```

### License Issues
Check license files exist:
```bash
ls -l freesurfer_license.txt meld_license.txt
```

### Data Not Found
Ensure data directory structure is correct:
```bash
ls -R meld_data/input/
```

## Advanced Usage

### Run Custom Python Script
```bash
apptainer exec \
  --bind ./meld_data:/data \
  --bind ./freesurfer_license.txt:/license.txt:ro \
  --bind ./meld_license.txt:/app/meld_license.txt:ro \
  --env FS_LICENSE=/license.txt \
  --env MELD_LICENSE=/app/meld_license.txt \
  meld_graph_v2.2.4.sif \
  python your_script.py
```

### Access FreeSurfer Tools
```bash
./run_meld_container.sh --shell
# Inside container:
recon-all -version
mri_convert --help
```

### Check Container Contents
```bash
apptainer inspect meld_graph_v2.2.4.sif
```

## Support

- **MELD Team**: meld.study@gmail.com
- **Documentation**: https://meld-graph.readthedocs.io/
- **GitHub**: https://github.com/MELDProject/meld_graph

## Version Info

- **Container Version**: v2.2.4
- **Downloaded**: 2026-02-12
- **Size**: 4.7GB (compressed SIF)
- **Original Image**: meldproject/meld_graph:v2.2.4
