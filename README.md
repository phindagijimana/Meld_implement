# MELD Graph Pipeline

Production-ready FCD lesion detection using Graph Neural Networks.

## Quick Start

```bash
# Native deployment
./meld run sub-001

# Docker deployment
cd docker_version && ./meld-docker run sub-001
```

## Setup

### Native Deployment (HPC/SLURM)

**Requirements:** Python 3.9+, SLURM, conda, 32GB RAM

```bash
# 1. Clone repository
git clone https://github.com/phindagijimana/Meld_graph_implementation.git
cd Meld_graph_implementation

# 2. Get licenses (both free)
# FreeSurfer: https://surfer.nmr.mgh.harvard.edu/registration.html → freesurfer_license/license.txt
# MELD: https://meld.org.uk/get-started/ → meld_license.txt

# 3. Automated setup (creates conda env, downloads FreeSurfer container)
./meld install

# 4. Prepare data (BIDS format in meld_graph/meld_data/input/)
# sub-001/anat/
#   ├── sub-001_T1w.nii.gz
#   └── sub-001_FLAIR.nii.gz

# 5. Run
./meld run sub-001
```

### Docker Deployment (Workstation)

**Requirements:** Singularity/Docker, 32GB RAM  
**Note:** Runs directly without SLURM. For HPC/OOD environments, use native deployment.

```bash
# 1. Clone and navigate
git clone https://github.com/phindagijimana/Meld_graph_implementation.git
cd Meld_graph_implementation/docker_version

# 2. Pull container
apptainer pull meld_graph_v2.2.4.sif docker://meldproject/meld_graph:v2.2.4

# 3. Get licenses (same as native)
# FreeSurfer → freesurfer_license.txt
# MELD → meld_license.txt

# 4. Prepare data (BIDS format in meld_data/input/)

# 5. Run
./meld-docker run sub-001
```

## CLI Reference

### Native (SLURM submission)

```bash
./meld install              # Automated setup
./meld run <subject>        # Submit to SLURM queue
./meld batch <sub1> <sub2>  # Submit multiple jobs
./meld status [subject]     # Check SLURM job status
./meld logs <subject>       # View logs
./meld results <subject>    # View results
./meld validate <subject>   # Validate data
./meld version              # Version info
./meld help                 # Help
```

### Docker (Direct execution)

```bash
cd docker_version
./meld-docker run <subject>        # Run directly (blocking)
./meld-docker batch <sub1> <sub2>  # Run multiple (parallel)
./meld-docker status [subject]     # Check results
./meld-docker logs <subject>       # View logs
./meld-docker results <subject>    # View results
./meld-docker validate <subject>   # Validate data
./meld-docker shell                # Interactive shell
./meld-docker version              # Version info
./meld-docker help                 # Help
```

**Deployment Selection:**
- **HPC/SLURM/OOD:** Use native deployment
- **Local workstation:** Use docker deployment

## Output

Results in `meld_graph/meld_data/output/predictions_reports/<subject>/`:
- `reports/MELD_report_<subject>.pdf` - Full report
- `reports/info_clusters_<subject>.csv` - Cluster details
- `predictions/prediction.nii.gz` - 3D volume

## Troubleshooting

```bash
# Native
./meld logs <subject>

# Docker
./meld-docker logs <subject>

# SLURM errors
cat logs/meld_pipeline_*.err
```

Common issues:
- FreeSurfer fails: Verify T1/FLAIR are 3D, 32GB+ RAM
- HDF5 lock errors: Normal for parallel jobs, auto-retries

See TECHNICAL_REFERENCE.md for details.
