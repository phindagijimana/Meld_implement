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

4. **Run container:**
   ```bash
   cd docker_test
   
   # Using wrapper script
   ./run_meld_container.sh python /app/meld_graph/scripts/new_patient_pipeline/new_pt_pipeline.py -id sub-001
   
   # Or direct Singularity
   apptainer exec \
     --bind meld_data:/data \
     --bind freesurfer_license.txt:/license.txt:ro \
     --bind meld_license.txt:/app/meld_license.txt:ro \
     meld_graph_v2.2.4.sif \
     python /app/meld_graph/scripts/new_patient_pipeline/new_pt_pipeline.py -id sub-001
   ```

**Container Deployment Notes:**
- Self-contained: All dependencies included
- Official MELD image with FastSurfer support
- Results in `docker_test/meld_data/output/`

---

## CLI Commands

### Core Commands

```bash
# Setup (native deployment only)
./meld install              # Setup environment and validate dependencies

# Processing
./meld run <subject>        # Process single subject
./meld batch <sub1> <sub2>  # Process multiple subjects in parallel

# Monitoring
./meld status               # Show all jobs status
./meld status <subject>     # Show specific subject status
./meld logs <subject>       # View processing logs

# Management
./meld stop <job-id>        # Cancel running job
./meld validate <subject>   # Validate input data before processing
./meld results <subject>    # Display results summary

# Utilities
./meld config               # Show configuration
./meld version              # Show version info
./meld help                 # Show help
```

### Usage Examples

```bash
# Single subject workflow
./meld validate sub-001      # Optional: check input data
./meld run sub-001           # Submit to SLURM
./meld status sub-001        # Monitor progress
./meld logs sub-001          # View logs if needed
./meld results sub-001       # View results when complete

# Batch processing
./meld batch sub-001 sub-002 sub-003 sub-004

# Monitor all jobs
squeue -u $USER              # SLURM queue status
./meld status                # Pipeline-specific status
```

---

## Pipeline Stages

1. **FreeSurfer Segmentation** (6-12 hours)
   - Cortical reconstruction with T1w and FLAIR
   - Surface extraction and parcellation

2. **Feature Extraction** (10-20 minutes)
   - Surface-based features (thickness, curvature, etc.)
   - FLAIR intensity sampling at multiple depths
   - Registration to template surface

3. **Preprocessing** (5-10 minutes)
   - Feature smoothing and clipping
   - Combat harmonization (optional)
   - Intra/inter-subject normalization
   - Asymmetry calculation

4. **Prediction** (2-5 minutes)
   - Graph Neural Network inference
   - Cluster detection and confidence scoring
   - PDF report generation with saliency maps

---

## Output Structure

```
meld_graph/meld_data/output/
├── fs_outputs/                          # FreeSurfer outputs
│   └── sub-001/
├── preprocessed_surf_data/              # Feature matrices (HDF5)
├── classifier_outputs/                  # Raw predictions
└── predictions_reports/                 # Final results
    └── sub-001/
        ├── predictions/
        │   ├── prediction.nii.gz        # 3D prediction volume
        │   ├── lh.prediction.nii.gz     # Left hemisphere
        │   └── rh.prediction.nii.gz     # Right hemisphere
        └── reports/
            ├── MELD_report_sub-001.pdf  # Full report
            ├── inflatbrain_sub-001.png  # Brain visualization
            ├── info_clusters_sub-001.csv # Cluster statistics
            └── saliency_*.png           # Feature importance maps
```

---

## Configuration

Key settings in `run_meld_pipeline.sh` (native) or `run_meld_container.sh` (Docker):

```bash
# SLURM Resources (native only)
#SBATCH --partition=general
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00

# Paths
FREESURFER_HOME=/path/to/freesurfer
SUBJECTS_DIR=/path/to/output
FS_LICENSE=/path/to/license.txt
```

---

## Interpreting Results

### Confidence Scores

- **High (>90%)**: Strong FCD likelihood - clinical review recommended
- **Medium (70-90%)**: Possible FCD - correlate with clinical findings
- **Low (<70%)**: Less certain - may warrant additional imaging

### PDF Report Contents

1. **Cluster Information**: Location, size, confidence score
2. **Brain Visualizations**: Predictions overlaid on brain surfaces
3. **Saliency Maps**: Features contributing to predictions
4. **Feature Profiles**: Quantitative measures for detected clusters

---

## Troubleshooting

### Common Issues

**Pipeline fails immediately:**
```bash
# Check environment
conda activate meld_graph
python --version  # Should be 3.9+

# Verify licenses
cat freesurfer_license/license.txt
cat meld_license.txt
```

**FreeSurfer segmentation fails:**
- Verify T1w image quality (3D acquisition, good SNR)
- Check FLAIR is 3D (2D FLAIR not supported)
- Ensure sufficient memory (32GB+)

**HDF5 file locking error (parallel jobs):**
- Jobs accessing shared files simultaneously
- Let jobs finish naturally or stagger submission times

**Out of memory:**
```bash
# Increase SLURM allocation in run_meld_pipeline.sh
#SBATCH --mem=64G
```

**Check logs:**
```bash
# SLURM logs
tail -f logs/meld_pipeline_<jobid>.out
cat logs/meld_pipeline_<jobid>.err

# Pipeline logs
tail -f meld_graph/meld_data/logs/MELD_pipeline_*.log
```

---

## Performance Notes

- **First run per subject**: 6-12 hours (FreeSurfer)
- **Reprocessing with existing FreeSurfer**: 15-30 minutes
- **Parallel jobs**: Limited by shared HDF5 file access during preprocessing
- **Recommended**: Stagger job submissions by 1-2 minutes for parallel processing

---

## Support & Documentation

- **MELD Documentation**: https://meld-graph.readthedocs.io/
- **Pipeline Help**: `./meld help`
- **MELD Community**: https://meld.org.uk/
- **Issues**: Check logs first, then consult MELD documentation

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
