# MELD Graph Official Container - Quick Reference

## Location
```
/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/docker_test/
```

## Essential Commands

### Run Full Pipeline
```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/docker_test
./run_meld_container.sh sub-YOURSUBJECT
```

### Run Specific Stage
```bash
# Segmentation (FreeSurfer + features)
./run_meld_container.sh sub-YOURSUBJECT segmentation

# Preprocessing (normalization)
./run_meld_container.sh sub-YOURSUBJECT preprocessing

# Prediction (GNN + reports)
./run_meld_container.sh sub-YOURSUBJECT prediction
```

### Validate Data
```bash
./run_meld_container.sh --validate sub-YOURSUBJECT
```

### Interactive Shell
```bash
./run_meld_container.sh --shell
```

### Compare Results (Custom vs Container)
```bash
./compare_results.sh sub-YOURSUBJECT
```

## Input Data Format

Place data in:
```
meld_data/input/sub-YOURSUBJECT/anat/
├── sub-YOURSUBJECT_T1w.nii.gz       # Required
└── sub-YOURSUBJECT_FLAIR.nii.gz     # Optional (recommended)
```

## Output Location

Results appear in:
```
meld_data/output/predictions/sub-YOURSUBJECT/predictions/
├── sub-YOURSUBJECT.lh.pdf            # Left hemisphere report
├── sub-YOURSUBJECT.rh.pdf            # Right hemisphere report
├── info_clusters_lh.csv              # Left clusters data
└── info_clusters_rh.csv              # Right clusters data
```

## Container Specifications

- **Version**: v2.2.4 (Latest official)
- **Size**: 4.7 GB
- **Python**: 3.9.25
- **FreeSurfer**: 7.2.0
- **License Required**: Yes (both FreeSurfer + MELD)

## Key Differences from Custom Setup

| Feature | Your Custom Setup | Official Container |
|---------|------------------|-------------------|
| FreeSurfer | 7.4.1 | 7.2.0 |
| MELD Version | ~v2.2.2 | v2.2.4 |
| SLURM | Integrated | Manual |
| Location | `../meld_graph/` | `./docker_test/` |
| Use For | Production runs | Validation/testing |

## Troubleshooting

### Check licenses are accessible
```bash
ls -l freesurfer_license.txt meld_license.txt
```

### View container details
```bash
apptainer inspect meld_graph_v2.2.4.sif
```

### Test container
```bash
./run_meld_container.sh --test
```

## Example Workflow

```bash
# 1. Navigate to container directory
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/docker_test

# 2. Copy your subject data
mkdir -p meld_data/input/sub-NEW/anat
cp /path/to/T1.nii.gz meld_data/input/sub-NEW/anat/sub-NEW_T1w.nii.gz
cp /path/to/FLAIR.nii.gz meld_data/input/sub-NEW/anat/sub-NEW_FLAIR.nii.gz

# 3. Validate data
./run_meld_container.sh --validate sub-NEW

# 4. Run pipeline
./run_meld_container.sh sub-NEW

# 5. View results
ls -lh meld_data/output/predictions/sub-NEW/predictions/

# 6. Compare with custom setup (if available)
./compare_results.sh sub-NEW
```

## Support

- **Documentation**: See `README.md` in this directory
- **MELD Team**: meld.study@gmail.com
- **Online Docs**: https://meld-graph.readthedocs.io/
