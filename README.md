# MELD Graph Pipeline - Professional Implementation

## Overview

This repository contains a professional implementation of the MELD Graph pipeline for FCD (Focal Cortical Dysplasia) lesion detection from MRI scans. The implementation follows software engineering best practices with comprehensive error handling, logging, and documentation.

## Features

- **Professional Code Structure**: Well-organized, commented code at senior-engineer level
- **Comprehensive Error Handling**: Robust error detection and recovery mechanisms
- **Detailed Logging**: Timestamped logs with multiple severity levels
- **Environment Validation**: Automatic validation of dependencies and data
- **SLURM Integration**: Optimized for high-performance computing environments
- **Modular Design**: Separated configuration and execution logic

## Architecture

```
Meld_Graph/
├── run_meld_pipeline.sh          # Main pipeline script (generic)
├── run_meld_sub03.sh             # Subject-specific script
├── meld_config.sh                # Configuration file
├── meld_graph/                   # MELD Graph installation
├── containers/                   # FreeSurfer containers
├── freesurfer_license/           # FreeSurfer licenses
└── logs/                         # Pipeline logs
```

## Prerequisites

- **MELD Graph 2.2.2+**
- **FreeSurfer 7.4.1+** (containerized)
- **Python 3.9+**
- **SLURM workload manager**
- **Conda environment management**
- **FreeSurfer License** (free - see setup below)

## FreeSurfer License Setup

**IMPORTANT**: FreeSurfer requires a free license file to run. You must obtain and place this license before running the pipeline.

### Getting Your License (Free & Quick)

1. **Register for a FreeSurfer License** (takes 2 minutes):
   - Go to: https://surfer.nmr.mgh.harvard.edu/registration.html
   - Fill out the registration form
   - You'll receive an email with a `license.txt` file attached

2. **Place the License File**:
   ```bash
   # Save the license.txt file to this location:
   cp /path/to/your/downloaded/license.txt freesurfer_license/license.txt
   ```

3. **Verify the License**:
   ```bash
   cat freesurfer_license/license.txt
   ```
   The file should contain your email and a license key.

### Already Have a FreeSurfer License?

If you already have a FreeSurfer license on your system, simply copy it:

```bash
# Find existing license
find ~ -name "license.txt" 2>/dev/null | grep -i freesurfer

# Copy to the required location
cp /path/to/existing/license.txt freesurfer_license/license.txt
```

**For detailed instructions, see:** [`freesurfer_license/GET_LICENSE.md`](freesurfer_license/GET_LICENSE.md)

## Quick Start

### 1. Run Pipeline for Specific Subject

```bash
# Submit SLURM job for sub-03
sbatch run_meld_sub03.sh

# Or use generic pipeline script
sbatch run_meld_pipeline.sh sub-03
```

### 2. Monitor Job Status

```bash
# Check job queue
squeue -u $USER

# View job logs
tail -f logs/meld_sub03_<job_id>.out
```

### 3. Verify Outputs

```bash
# Check predictions
ls -la meld_graph/meld_data/output/predictions_reports/sub-03/predictions/

# Check reports
ls -la meld_graph/meld_data/output/predictions_reports/sub-03/reports/
```

## Configuration

The pipeline uses a centralized configuration file (`meld_config.sh`) that contains:

- **System Configuration**: SLURM settings, resource allocation
- **Path Configuration**: All file and directory paths
- **Environment Configuration**: Conda environments, Python paths
- **Validation Configuration**: File size limits, quality checks
- **Performance Configuration**: Timeouts, memory limits

## Pipeline Stages

### Stage 1: Segmentation and Feature Extraction
- FreeSurfer cortical reconstruction
- Surface-based feature extraction
- Template surface registration
- Feature sampling and normalization

### Stage 2: Feature Preprocessing
- Feature smoothing
- Harmonization (optional)
- Intra-subject normalization
- Inter-subject normalization

### Stage 3: Lesion Prediction and Reports
- MELD classifier execution
- Prediction back-projection to native space
- PDF report generation
- Quality control outputs

## Output Files

### Predictions
- `prediction.nii.gz`: Whole-brain prediction volume
- `lh.prediction.nii.gz`: Left hemisphere prediction
- `rh.prediction.nii.gz`: Right hemisphere prediction

### Reports
- `MELD_report_<subject_id>.pdf`: Comprehensive PDF report
- `inflatbrain_<subject_id>.png`: Inflated brain visualization
- `info_clusters_<subject_id>.csv`: Cluster information summary

## Error Handling

The pipeline includes comprehensive error handling:

- **Environment Validation**: Checks all dependencies and paths
- **Data Validation**: Verifies input file integrity
- **Resource Monitoring**: Tracks memory and disk usage
- **Graceful Degradation**: Continues processing when possible
- **Detailed Logging**: Captures all errors with context

## Logging

All operations are logged with timestamps and severity levels:

- **INFO**: General information and progress updates
- **WARN**: Non-critical issues that don't stop execution
- **ERROR**: Critical errors that require attention
- **SUCCESS**: Successful completion of major steps
- **DEBUG**: Detailed debugging information

## Quality Control

The pipeline performs automatic quality control:

- **File Size Validation**: Ensures input files meet minimum requirements
- **Disk Space Monitoring**: Prevents out-of-space errors
- **Memory Usage Tracking**: Monitors resource consumption
- **Output Verification**: Confirms all expected outputs are generated

## Troubleshooting

### Common Issues

1. **Surface Registration Failures**
   - Ensure FreeSurfer license is valid
   - Check FreeSurfer container integrity
   - Verify input data quality

2. **Memory Issues**
   - Increase SLURM memory allocation
   - Check for memory leaks in long-running jobs
   - Monitor system memory usage

3. **Disk Space Issues**
   - Clean up old output files
   - Increase disk space allocation
   - Use compression for large files

### Debug Mode

Enable debug mode for detailed troubleshooting:

```bash
python scripts/new_patient_pipeline/new_pt_pipeline.py -id sub-03 --debug_mode
```

## Performance Optimization

### Resource Allocation
- **CPU**: 8 cores recommended for FreeSurfer
- **Memory**: 32GB minimum for complex subjects
- **Time**: 6-12 hours depending on data complexity

### Parallel Processing
Enable parallel processing for multiple subjects:

```bash
python scripts/new_patient_pipeline/new_pt_pipeline.py -ids subjects_list.txt --parallelise
```

## Contributing

When modifying the pipeline:

1. **Follow Code Standards**: Use consistent formatting and commenting
2. **Update Documentation**: Keep README and comments current
3. **Test Thoroughly**: Validate changes with multiple subjects
4. **Error Handling**: Ensure robust error detection and recovery
5. **Logging**: Add appropriate logging for new functionality

## License

This implementation follows the MELD Graph project licensing terms. Please refer to the original MELD Graph documentation for licensing details.

## Support

For technical support:

1. **Check Logs**: Review pipeline logs for error messages
2. **Validate Environment**: Ensure all dependencies are properly installed
3. **Review Documentation**: Consult MELD Graph official documentation
4. **Contact Support**: Reach out to the MELD Graph community

## Version History

- **v2.0** (2025-10-28): Professional implementation with comprehensive error handling
- **v1.0** (2025-10-22): Initial implementation

---

*This implementation represents a professional-grade approach to running the MELD Graph pipeline with emphasis on reliability, maintainability, and user experience.*