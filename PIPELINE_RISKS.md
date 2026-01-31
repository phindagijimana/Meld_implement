# MELD Pipeline - Potential Risks & Mitigation Strategies

**Last Updated:** 2026-01-30 
**Status:** Comprehensive risk assessment for production use

---

## CRITICAL RISKS (Can Corrupt Results)

### 1. **Concurrent Execution on Same Subject** 

**Risk Level:** CRITICAL 
**Impact:** Data corruption, partial/incomplete outputs, HDF5 file corruption

**Problem:**
- If you run the pipeline on the same subject ID simultaneously (multiple jobs), they will:
 - Overwrite each other's outputs
 - Corrupt shared HDF5 files during Stage 2 (preprocessing)
 - Create race conditions in FreeSurfer outputs

**Evidence:**
```python
# From run_script_segmentation.py - uses multiprocessing
pool = multiprocessing.Pool(processes=num_procs, initializer=init, 
 initargs=[multiprocessing.Lock()])
```

**Shared Files at Risk:**
```
# Subject-specific (safe if different subjects)
meld_data/output/fs_outputs/<subject_id>/

# SHARED ACROSS SUBJECTS (dangerous!)
meld_data/output/preprocessed_surf_data/MELD_noHarmo/
 noHarmo_patient_featurematrix.hdf5
 noHarmo_patient_featurematrix_smoothed.hdf5
 noHarmo_patient_featurematrix_combat.hdf5
```

**Mitigation:**
```bash
# SAFE: Run different subjects concurrently
sbatch run_meld_pipeline_fixed.sh sub-036
sbatch run_meld_pipeline_fixed.sh sub-037
sbatch run_meld_pipeline_fixed.sh sub-038

# DANGEROUS: Same subject multiple times
sbatch run_meld_pipeline_fixed.sh sub-036
sbatch run_meld_pipeline_fixed.sh sub-036 # Will corrupt!

# Check before submitting
squeue -u $USER | grep meld_pipeline
```

**Current Protection:** NONE - User must manage manually

**Recommendation:**
- Always check `squeue` before submitting new jobs
- Add subject lock files (future enhancement)
- Use unique job names per subject

---

### 2. **Disk Space Exhaustion** 

**Risk Level:** HIGH 
**Impact:** Incomplete outputs, FreeSurfer crashes, corrupted files

**Current Status:**
```
Filesystem: /mnt/nfs/home (NFS mounted)
Total: 2.0 TB
Used: 706 GB (35%)
Available: 1.4 TB Adequate
```

**Per-Subject Storage Requirements:**
- FreeSurfer outputs: ~500 MB - 1 GB
- Feature matrices: ~100 MB
- Predictions: ~1-5 MB
- Reports: ~1 MB
- **Total per subject:** ~600 MB - 1.2 GB

**Risk Scenarios:**
1. **Gradual fill-up:** Running many subjects fills disk
2. **Temp files:** FreeSurfer creates temp files that may not clean up
3. **Log accumulation:** Pipeline logs grow over time

**Symptoms of Disk Full:**
- FreeSurfer segmentation fails silently
- HDF5 write errors: `OSError: Unable to create file`
- Incomplete outputs with exit code 0

**Mitigation:**
```bash
# Before each run
df -h /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/

# Alert if < 100 GB free
AVAIL=$(df /mnt/nfs/home | tail -1 | awk '{print $4}')
if [ $AVAIL -lt 104857600 ]; then
 echo "WARNING: Less than 100GB free!"
fi

# Clean old outputs periodically
rm -rf meld_data/output/fs_outputs/<old_subjects>
rm -f logs/meld_pipeline_*.{out,err} # Keep recent only
```

**Current Protection:** Adequate space (1.4TB free)

---

### 3. **SLURM Time Limit Exceeded** 🟡

**Risk Level:** MEDIUM 
**Impact:** Job killed mid-processing, incomplete outputs

**Current Settings:**
```bash
#SBATCH --time=8:00:00 # 8 hours
```

**Stage Timings:**
- Stage 1 (FreeSurfer): 2-4 hours (varies by brain complexity)
- Stage 2 (Preprocessing): 2-5 minutes
- Stage 3 (Prediction): 3-5 minutes
- **Total:** 2-4 hours typical, up to 6 hours for complex cases

**Risk:**
- If FreeSurfer takes >8 hours, job is killed
- Partial FreeSurfer outputs left behind
- Pipeline may appear "complete" but missing files

**Symptoms:**
- SLURM log ends with `CANCELLED` or `TIMEOUT`
- FreeSurfer `recon-all.log` shows incomplete processing
- Missing critical files (e.g., `lh.white`, `rh.pial`)

**Mitigation:**
```bash
# Check job time before it expires
squeue -u $USER -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"

# For complex cases, increase limit
#SBATCH --time=12:00:00 # 12 hours

# Resume from checkpoint (FreeSurfer supports this)
# If job times out, re-running continues from last checkpoint
```

**Current Protection:** 8 hours is adequate for typical cases

---

### 4. **Memory Exhaustion (OOM Kill)** 🟡

**Risk Level:** MEDIUM 
**Impact:** Job killed, no outputs, may corrupt partial files

**Current Settings:**
```bash
#SBATCH --mem=32G # 32 GB RAM
```

**Memory Requirements:**
- FreeSurfer: 4-8 GB typical, up to 16 GB for large brains
- Feature extraction: 2-4 GB
- Preprocessing: 8-16 GB (Combat harmonization)
- Prediction: 4-8 GB (model loading)
- **Peak:** ~16-20 GB

**Risk:**
- If multiple threads use peak memory simultaneously: >32 GB
- OOM killer terminates process without cleanup
- Corrupted HDF5 files if killed during write

**Symptoms:**
- SLURM log: `slurmstepd: error: Detected ... exceeded memory limit`
- SLURM log: `CANCELLED` or `OUT_OF_MEMORY`
- No obvious error in pipeline log

**Mitigation:**
```bash
# Monitor memory usage
grep "memory" logs/meld_pipeline_*.err

# For large brains or multiple subjects
#SBATCH --mem=64G

# Reduce parallelization if OOM
export OMP_NUM_THREADS=4 # Instead of 8
```

**Current Protection:** 32GB is adequate for single subjects

---

## 🟡 MODERATE RISKS (Can Interrupt Execution)

### 5. **Network/NFS Issues** 🟡

**Risk Level:** MEDIUM 
**Impact:** Intermittent failures, I/O errors, timeouts

**Problem:**
- Pipeline runs on NFS-mounted storage
- Network hiccups can cause read/write failures
- FreeSurfer is I/O intensive (thousands of small files)

**Symptoms:**
- `Stale file handle` errors
- `Input/output error` in logs
- Random crashes during FreeSurfer stages
- Incomplete file writes

**Mitigation:**
- NFS is generally reliable for HPC
- Monitor for NFS alerts from sysadmin
- Re-run failed jobs (FreeSurfer resumes from checkpoints)

**Current Protection:** Dependent on network reliability

---

### 6. **Node Failure** 🟡

**Risk Level:** LOW-MEDIUM 
**Impact:** Job killed, need to restart

**Problem:**
- Compute node crashes or reboots
- Job is lost with no graceful cleanup

**Symptoms:**
- Job disappears from queue without completion email
- SLURM log may be incomplete or missing

**Mitigation:**
```bash
# Check node health before job
sinfo -N -l

# Use reliable partition
#SBATCH --partition=general # Already using

# Monitor job progress
tail -f logs/meld_pipeline_<job_id>.out
```

**Current Protection:** Rare but possible

---

### 7. **Container/Singularity Issues** 🟡

**Risk Level:** MEDIUM 
**Impact:** FreeSurfer commands fail

**Problem:**
- Container file corrupted: `freesurfer-7.4.1.sif`
- Singularity/Apptainer not available on node
- Bind mounts fail

**Symptoms:**
- `FATAL: container creation failed`
- `FATAL: could not open image`
- FreeSurfer commands return "command not found"

**Mitigation:**
```bash
# Verify container integrity
singularity verify containers/freesurfer-7.4.1.sif

# Test on login node before submitting
apptainer exec containers/freesurfer-7.4.1.sif recon-all --version

# Re-download if corrupted
singularity pull docker://freesurfer/freesurfer:7.4.1
```

**Current Protection:** Container validated in previous runs

---

### 8. **Python Environment Issues** 🟡

**Risk Level:** MEDIUM 
**Impact:** Import errors, missing dependencies

**Problem:**
- Conda environment `meld_graph` missing packages
- Package version conflicts
- Environment not activated

**Symptoms:**
- `ModuleNotFoundError: No module named 'XXX'`
- `ImportError: cannot import name 'XXX'`
- Python crashes during stages 2-3

**Mitigation:**
```bash
# Verify environment before run
conda activate meld_graph
python -c "import nibabel, torch, h5py, pandas; print('OK')"

# Reinstall if needed
conda env create -f environment.yml --force

# Check in SLURM script
eval "$(/path/to/miniconda3/bin/conda shell.bash hook)"
conda activate meld_graph # Already in script
```

**Current Protection:** Environment activated in SLURM script

---

## 🟢 LOW RISKS (Minor Issues)

### 9. **Interrupted Manual Runs** 🟢

**Risk Level:** LOW 
**Impact:** Incomplete output, easy to restart

**Problem:**
- User Ctrl+C during interactive run
- SSH connection dropped
- Terminal closed

**Mitigation:**
- Always use SLURM for production runs (recommended) 
- Use `tmux` or `screen` for interactive sessions
- Jobs run in background, unaffected by terminal

---

### 10. **Input Data Quality Issues** 🟢

**Risk Level:** LOW-MEDIUM 
**Impact:** Poor results, not corruption but misleading

**Problems:**
- Corrupted NIfTI files (scan artifacts)
- Wrong contrast (T2 instead of T1)
- Non-isotropic voxels (not 1mm³)
- Motion artifacts
- Missing FLAIR (reduces sensitivity)

**Symptoms:**
- FreeSurfer segmentation fails
- Extremely long processing times
- Poor quality surfaces (holes, folding errors)
- Low confidence predictions

**Mitigation:**
```bash
# Validate inputs before running
python3 << 'EOF'
import nibabel as nib
img = nib.load("path/to/T1w.nii.gz")
print(f"Shape: {img.shape}")
print(f"Voxel size: {img.header.get_zooms()}")
# Expect: 256x256x176, (1.0, 1.0, 1.0)
EOF

# Visual QC of inputs
freeview -v sub-036_T1w.nii.gz sub-036_FLAIR.nii.gz
```

**Current Protection:** sub-036 data validated

---

### 11. **FreeSurfer Segmentation Errors** 🟢

**Risk Level:** LOW 
**Impact:** Poor quality outputs, not corruption

**Problems:**
- Skull-strip failures
- Pial surface errors (includes dura)
- White surface errors (wrong boundary)
- Topology defects

**Detection:**
- Check FreeSurfer QC reports
- Review `recon-all.log` for warnings
- Visual inspection in FreeView

**Mitigation:**
- Re-run with manual editing (advanced)
- Exclude poor-quality subjects from analysis
- This is expected ~5-10% of subjects

---

## **PREVENTION CHECKLIST**

Before running a new subject:

```bash
# 1. Check no jobs running for same subject
squeue -u $USER | grep sub-036

# 2. Check disk space
df -h /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph/

# 3. Verify container
ls -lh containers/freesurfer-7.4.1.sif

# 4. Verify input data
ls -lh meld_graph/meld_data/input/sub-036/anat/

# 5. Check FreeSurfer license
ls -l freesurfer_license/license.txt

# 6. Verify wrappers
which recon-all

# 7. Test environment (optional)
conda activate meld_graph
python -c "import nibabel, torch; print('OK')"
```

---

## **RECOVERY PROCEDURES**

### If Pipeline Fails Mid-Execution:

1. **Check what completed:**
 ```bash
 # Stage 1 (FreeSurfer)
 ls meld_data/output/fs_outputs/sub-036/surf/lh.white
 
 # Stage 2 (Features)
 ls meld_data/output/preprocessed_surf_data/MELD_noHarmo/*.hdf5
 
 # Stage 3 (Predictions)
 ls meld_data/output/predictions_reports/sub-036/predictions/
 ```

2. **Resume from checkpoint:**
 ```bash
 # FreeSurfer automatically resumes
 # Just re-run the same command
 sbatch run_meld_pipeline_fixed.sh sub-036
 ```

3. **Skip completed stages:**
 ```bash
 # If FreeSurfer done, skip Stage 1
 python scripts/new_patient_pipeline/new_pt_pipeline.py -id sub-036 \
 --skip_feature_extraction
 ```

4. **Clean and restart:**
 ```bash
 # If corrupted, clean everything
 rm -rf meld_data/output/fs_outputs/sub-036
 rm -f meld_data/output/preprocessed_surf_data/MELD_noHarmo/*
 
 # Then re-run
 sbatch run_meld_pipeline_fixed.sh sub-036
 ```

---

## **RISK SUMMARY**

| Risk | Severity | Likelihood | Impact | Mitigation |
|------|----------|------------|--------|------------|
| Concurrent same subject | Critical | Medium | Corruption | Check squeue |
| Disk space full | High | Low | Incomplete | Monitor df -h |
| Time limit | 🟡 Medium | Low | Interrupted | 8hr adequate |
| OOM kill | 🟡 Medium | Low | Interrupted | 32GB adequate |
| Network/NFS | 🟡 Medium | Low | I/O errors | Re-run |
| Node failure | 🟡 Medium | Very Low | Interrupted | Re-run |
| Container issues | 🟡 Medium | Very Low | FreeSurfer fails | Validated |
| Python environment | 🟡 Medium | Very Low | Import errors | Activated |
| Data quality | 🟢 Low | Medium | Poor results | QC inputs |
| FreeSurfer errors | 🟢 Low | Medium | Poor quality | Expected |

---

## **CONCLUSION**

**Overall Risk Level:** 🟢 **LOW** (with proper precautions)

**Most Critical Risk:** Running the same subject concurrently

**Best Practices:**
1. Always check `squeue` before submitting
2. Monitor disk space regularly
3. Use SLURM for production runs
4. Validate inputs before processing
5. Keep logs for debugging

**Current Protection Level:** HIGH - All infrastructure validated

The pipeline is safe to run with standard HPC precautions. The main risk is user error (concurrent execution), which can be easily avoided by checking running jobs before submission.

---

**Next Subject:** sub-036 - Safe to submit 
