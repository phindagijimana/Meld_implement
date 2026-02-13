# MELD Graph Pipeline - Technical Reference

## Confidence Score Calculation

### Overview

The confidence score represents the model's certainty in detecting FCD lesions. It is calculated using the maximum prediction value within the most salient (important) vertices of a detected cluster.

### Calculation Steps

1. **Model Prediction**: Graph Neural Network generates prediction scores (0-1) for each vertex
2. **Thresholding**: Apply adaptive threshold to identify potential lesion clusters
3. **Saliency Analysis**: Use Integrated Gradients to identify top 20% most important vertices
4. **Confidence Extraction**: Take maximum prediction within salient vertices, multiply by 100

Example from code:
```python
# From plot_prediction_report.py
mask_salient = saliencies[f'mask_salient_{cl}'][hemi].astype(bool)
confidence_cl_salient = data_dictionary['result'][hemi][mask_salient].max()
confidence = round(confidence_cl_salient * 100, 2)
```

### Confidence Interpretation

**Clinical Ranges:**
- **High (>90%)**: Strong FCD likelihood - clinical review recommended
- **Medium (70-90%)**: Possible FCD - correlate with clinical findings
- **Low (<70%)**: Less certain - may warrant additional imaging

**Important Notes:**
- Confidence is NOT diagnostic certainty
- Low confidence does not exclude FCD
- Context matters: clinical history, imaging quality, scan parameters
- Be cautious when:
  - Scan quality is poor
  - Non-standard acquisition parameters
  - Lesion is in difficult location (e.g., temporal pole)

### Factors Affecting Confidence

1. **Lesion characteristics**: Size, location, severity
2. **Image quality**: SNR, resolution, artifacts
3. **Feature abnormality**: Degree of deviation from normal
4. **Model certainty**: Training data similarity
5. **Saliency concentration**: How focused the important features are

### Aggregation Methods

The pipeline supports different confidence aggregation:
- `max`: Maximum prediction in salient region (default, used in reports)
- `median`: Median prediction in salient region
- `mean`: Mean prediction in salient region

Location: `meld_graph/meld_graph/confidence.py`

### Expected Calibration Error (ECE)

The model is calibrated so predicted confidence should match actual accuracy. ECE measures this alignment. Lower ECE means better calibration.

---

## Pipeline Architecture

### Core Components

**1. FreeSurfer Segmentation** (6-12 hours)
- Cortical reconstruction with T1w and FLAIR
- Surface extraction and parcellation
- Template surface registration

**2. Feature Extraction** (10-20 minutes)
- Surface-based features: thickness, curvature, sulcal depth
- FLAIR intensity at multiple cortical depths (0, 0.25, 0.5, 0.75mm; WM at 0.5, 1mm)
- Grey-white matter contrast

**3. Preprocessing** (5-10 minutes)
- Feature smoothing (6 iterations, 3mm FWHM)
- Combat harmonization (optional, for multi-site)
- Intra-subject normalization
- Inter-subject normalization using MELD control cohort
- Asymmetry calculation (left-right differences)

**4. Prediction** (2-5 minutes)
- Graph Neural Network (GCN architecture)
- Monte Carlo dropout for uncertainty
- Saliency map generation (Integrated Gradients)
- Cluster detection and analysis

### Data Format

**Input** (BIDS format):
```
input/
└── sub-001/
    └── anat/
        ├── sub-001_T1w.nii.gz      # 3D T1-weighted (required)
        └── sub-001_FLAIR.nii.gz    # 3D FLAIR (required)
```

**Output**:
```
output/
├── fs_outputs/sub-001/              # FreeSurfer results
├── preprocessed_surf_data/          # Feature matrices (HDF5)
├── classifier_outputs/              # Raw predictions
└── predictions_reports/sub-001/
    ├── predictions/
    │   └── prediction.nii.gz        # 3D volume
    └── reports/
        ├── MELD_report_sub-001.pdf  # Full report
        ├── info_clusters_sub-001.csv # Cluster details
        └── saliency_sub-001_*.png   # Feature importance
```

---

## HDF5 Parallel Processing

### File Locking Implementation

The pipeline uses retry logic with exponential backoff to handle concurrent HDF5 file access from parallel jobs.

**Module**: `meld_graph/meld_graph/hdf5_io.py`

**Key Features**:
- Exponential backoff: 0.5s base delay, max 30s
- Up to 10 retry attempts
- Jitter to avoid thundering herd
- Clear error messages

**Affected Files**:
- `noHarmo_patient_featurematrix.hdf5` (94 MB)
- `noHarmo_patient_featurematrix_smoothed.hdf5` (112 MB)
- `noHarmo_patient_featurematrix_combat.hdf5` (352 MB)

**Best Practices**:
- Stagger parallel job submissions by 30-60 seconds
- Limit to 3-4 simultaneous jobs in preprocessing stage
- Monitor logs for retry messages

---

## Input Requirements

### T1-weighted Image

- **Required**: 3D acquisition
- **Recommended**: MPRAGE, SPGR, or equivalent
- **Resolution**: 1mm isotropic (0.8-1.2mm acceptable)
- **Quality**: Good SNR, minimal motion artifacts

### FLAIR Image

- **Required**: 3D acquisition (2D not supported)
- **Recommended**: 3D FLAIR sequence
- **Resolution**: 1mm isotropic preferred
- **Registration**: Should be in same space as T1 or co-registered

### Common Issues

**2D FLAIR**: Pipeline will fail. Convert to 3D or exclude FLAIR features.

**Poor T1 quality**: FreeSurfer may fail. Check:
- Motion artifacts
- Adequate brain coverage
- Proper contrast

**Misalignment**: T1 and FLAIR should be aligned. Pre-register if needed.

---

## Resource Requirements

### Compute

- **CPU**: 8 cores recommended
- **Memory**: 32GB minimum, 64GB for complex cases
- **Time**: 6-12 hours first run, 15-30 minutes if FreeSurfer exists
- **Storage**: ~2GB per subject

### Environment

- Python 3.9+
- FreeSurfer 7.2+ (containerized)
- SLURM workload manager (for HPC)
- HDF5 1.10+ (for parallel I/O)

---

## Troubleshooting

### FreeSurfer Fails

- Check T1 is 3D
- Verify FLAIR is 3D
- Ensure adequate memory (32GB+)
- Review FreeSurfer logs: `output/sub-*/scripts/`

### HDF5 Lock Errors

- Normal for parallel processing
- Should automatically retry
- If persistent: stagger job submissions

### Low Prediction Scores

- May indicate no FCD present
- Check image quality
- Review clinical correlation
- Consider manual inspection

### Missing Results

- Check logs: `./meld logs sub-001`
- Verify input data: `./meld validate sub-001`
- Review SLURM errors: `logs/meld_pipeline_*.err`

---

## Version Information

**Pipeline Version**: 1.0.0  
**MELD Graph**: 2.2.2+  
**FreeSurfer**: 7.4.1  
**Python**: 3.9+  
**HDF5**: 1.14.2
