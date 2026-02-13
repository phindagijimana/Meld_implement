# MELD Graph Pipeline

Production-ready FCD lesion detection using Graph Neural Networks.

## Quick Start

```bash
# Native deployment
./meld run sub-001

# Docker deployment
cd docker_test && ./run_meld_container.sh sub-001
```

## Setup

### Native Deployment (HPC/SLURM)

**Requirements:** Python 3.9+, SLURM, FreeSurfer container, 32GB RAM

```bash
# 1. Clone and setup environment
git clone <repo-url> && cd Meld_Graph
conda env create -f meld_graph/environment.yml
conda activate meld_graph

# 2. Get licenses (both free)
# FreeSurfer: https://surfer.nmr.mgh.harvard.edu/registration.html → freesurfer_license/license.txt
# MELD: https://meld.org.uk/get-started/ → meld_license.txt

# 3. Get FreeSurfer container
cd containers
apptainer pull freesurfer-7.4.1.sif docker://freesurfer/freesurfer:7.4.1

# 4. Prepare data (BIDS format)
# meld_graph/meld_data/input/sub-001/anat/
#   ├── sub-001_T1w.nii.gz
#   └── sub-001_FLAIR.nii.gz

# 5. Run
./meld run sub-001
```

### Docker Deployment

**Requirements:** Singularity/Docker, 32GB RAM

```bash
# 1. Pull container
cd docker_test
apptainer pull meld_graph_v2.2.4.sif docker://meldproject/meld_graph:v2.2.4

# 2. Get licenses (same as native)
# Place in docker_test/freesurfer_license.txt and docker_test/meld_license.txt

# 3. Prepare data
# docker_test/meld_data/input/sub-001/anat/ (same structure as native)

# 4. Run
./run_meld_container.sh sub-001
```

## CLI Reference

### Native

```bash
./meld run <subject>        # Process subject
./meld batch <sub1> <sub2>  # Process multiple
./meld status [subject]     # Check status
./meld logs <subject>       # View logs
./meld validate <subject>   # Validate data
./meld help                 # Full help
```

### Docker

```bash
cd docker_test
./run_meld_container.sh <subject>           # Full pipeline
./run_meld_container.sh <subject> <stage>   # Specific stage (segmentation/preprocessing/prediction)
./run_meld_container.sh --validate <subject># Validate
./run_meld_container.sh --help              # Help
```

## Output

Results in `meld_graph/meld_data/output/predictions_reports/<subject>/`:
- `reports/MELD_report_<subject>.pdf` - Full report with confidence scores
- `reports/info_clusters_<subject>.csv` - Cluster details
- `predictions/prediction.nii.gz` - 3D prediction volume

## Troubleshooting

```bash
# Check environment
conda activate meld_graph && python --version

# View logs
./meld logs <subject>  # Native
cat logs/meld_pipeline_*.err  # SLURM errors
```

Common issues:
- **FreeSurfer fails**: Verify T1 and FLAIR are 3D, 32GB+ RAM
- **HDF5 lock errors**: Normal for parallel jobs, auto-retries
- **Pipeline errors**: Check logs above

See TECHNICAL_REFERENCE.md for detailed information.
