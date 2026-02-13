# MELD Graph Pipeline

Production-ready pipeline for FCD (Focal Cortical Dysplasia) lesion detection using Graph Neural Networks.

## Quick Start

```bash
# Process subjects
./meld run sub-001
./meld batch sub-001 sub-002 sub-003

# Check progress
./meld status
./meld logs sub-001

# View results
./meld results sub-001
```

## Deployment Options

### Option 1: Native Deployment (Recommended for HPC)

**Prerequisites:**
- Python 3.9+
- SLURM workload manager
- FreeSurfer 7.2+ (containerized via Singularity)
- 32GB+ RAM per job

**Setup:**

1. **Clone repository:**
   ```bash
   git clone <repository-url>
   cd Meld_Graph
   ```

2. **Create conda environment:**
   ```bash
   conda env create -f meld_graph/environment.yml
   conda activate meld_graph
   ```

3. **Get FreeSurfer license** (free):
   - Register at: https://surfer.nmr.mgh.harvard.edu/registration.html
   - Save license to: `freesurfer_license/license.txt`

4. **Get MELD license** (free):
   - Request at: https://meld.org.uk/get-started/
   - Save to: `meld_license.txt`

5. **Configure FreeSurfer container:**
   ```bash
   # Download FreeSurfer Singularity container
   cd containers
   apptainer pull freesurfer-7.4.1.sif docker://freesurfer/freesurfer:7.4.1
   ```

6. **Prepare input data** (BIDS format):
   ```bash
   meld_graph/meld_data/input/
   └── sub-001/
       └── anat/
           ├── sub-001_T1w.nii.gz
           └── sub-001_FLAIR.nii.gz
   ```

7. **Run pipeline:**
   ```bash
   ./meld run sub-001
   ```

**Native Deployment Architecture:**
- Custom FreeSurfer wrappers (`.freesurfer_wrappers/`)
- Python scripts in `meld_graph/scripts/`
- SLURM integration via `run_meld_pipeline.sh`
- Results in `meld_graph/meld_data/output/`

---

### Option 2: Docker/Container Deployment

**Prerequisites:**
- Docker or Singularity/Apptainer
- 32GB+ RAM

**Setup:**

1. **Pull official MELD container:**
   ```bash
   # For Docker
   docker pull meldproject/meld_graph:v2.2.4
   
   # For Singularity (HPC)
   cd docker_test
   apptainer pull meld_graph_v2.2.4.sif docker://meldproject/meld_graph:v2.2.4
   ```

2. **Get licenses** (same as native):
   - FreeSurfer license → `docker_test/freesurfer_license.txt`
   - MELD license → `docker_test/meld_license.txt`

3. **Prepare data directory:**
   ```bash
   docker_test/meld_data/
   └── input/
       └── sub-001/
           └── anat/
               ├── sub-001_T1w.nii.gz
               └── sub-001_FLAIR.nii.gz
   ```

4. **Run pipeline:**
   ```bash
   cd docker_test
   ./run_meld_container.sh sub-001
   ```

**Container CLI Commands:**
```bash
# Process subject
./run_meld_container.sh sub-001

# Process specific stage
./run_meld_container.sh sub-001 segmentation
./run_meld_container.sh sub-001 preprocessing
./run_meld_container.sh sub-001 prediction

# Validate input
./run_meld_container.sh --validate sub-001

# Interactive shell
./run_meld_container.sh --shell

# Help
./run_meld_container.sh --help
```

**Container Architecture:**
- Self-contained: All dependencies included
- Official MELD v2.2.4 with FastSurfer
- Results in `docker_test/meld_data/output/`

---

## CLI Commands

### Native Deployment CLI

```bash
# Setup and validation
./meld install              # Setup environment
./meld validate <subject>   # Validate input data

# Processing
./meld run <subject>        # Process single subject
./meld batch <sub1> <sub2>  # Process multiple subjects

# Monitoring
./meld status [subject]     # Check processing status
./meld logs <subject>       # View logs
./meld results <subject>    # View results summary

# Management
./meld stop <job-id>        # Cancel job
./meld config               # Show configuration
./meld version              # Version info
./meld help                 # Full help
```

### Docker/Container CLI

```bash
# Processing
cd docker_test
./run_meld_container.sh <subject>              # Full pipeline
./run_meld_container.sh <subject> <stage>      # Specific stage

# Stages: segmentation, preprocessing, prediction

# Utilities
./run_meld_container.sh --validate <subject>   # Validate data
./run_meld_container.sh --shell                # Interactive shell
./run_meld_container.sh --help                 # Help
```

### Usage Examples

**Native Deployment:**
```bash
# Single subject
./meld validate sub-001      # Optional: check data
./meld run sub-001           # Submit to SLURM
./meld status sub-001        # Monitor
./meld results sub-001       # View results

# Batch processing
./meld batch sub-001 sub-002 sub-003
```

**Docker Deployment:**
```bash
cd docker_test

# Single subject
./run_meld_container.sh --validate sub-001   # Optional: check data
./run_meld_container.sh sub-001              # Run pipeline

# Stage-by-stage
./run_meld_container.sh sub-001 segmentation
./run_meld_container.sh sub-001 preprocessing
./run_meld_container.sh sub-001 prediction
```

---

## Output Structure

```
output/
├── fs_outputs/sub-001/              # FreeSurfer
├── preprocessed_surf_data/          # Features (HDF5)
├── classifier_outputs/              # Raw predictions
└── predictions_reports/sub-001/
    ├── predictions/
    │   └── prediction.nii.gz        # 3D volume
    └── reports/
        ├── MELD_report_sub-001.pdf  # Full report
        └── info_clusters_sub-001.csv # Cluster details
```

---

## Troubleshooting

**Environment issues:**
```bash
conda activate meld_graph
python --version  # Should be 3.9+
```

**FreeSurfer fails:** Verify T1 and FLAIR are 3D, sufficient memory (32GB+)

**HDF5 lock errors:** Normal for parallel jobs, automatically retries

**Check logs:**
```bash
# Native
./meld logs sub-001

# Docker
docker_test/meld_data/logs/

# SLURM
logs/meld_pipeline_<jobid>.out
```

See TECHNICAL_REFERENCE.md for detailed troubleshooting.

---

## Performance

- First run: 6-12 hours (FreeSurfer)
- Reprocessing: 15-30 minutes
- Parallel: Stagger submissions by 30-60s

---

## License

This pipeline implementation uses:
- MELD Graph (MIT License)
- FreeSurfer (FreeSurfer Software License)
- FastSurfer (Apache 2.0 License)

See individual components for detailed licensing terms.

---

## Version

**Pipeline Version**: 1.0.0  
**MELD Graph Version**: 2.2.2+  
**FreeSurfer Version**: 7.4.1  
**Last Updated**: 2026-02-13
