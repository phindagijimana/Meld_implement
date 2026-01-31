# MELD Pipeline - Code-Level Risks & Bugs

**Last Updated:** 2026-01-30 
**Severity:** MEDIUM - Some bugs exist but have workarounds

---

## **CONFIRMED BUGS IN CODE**

### **BUG #1: Silent Success on Stage Failures** 

**Severity:** HIGH 
**Impact:** Pipeline reports success even when stages 1 or 3 fail

**Location:** `new_pt_pipeline.py` lines 144 and 172

**Problem:**
```python
# Line 142-144
if result == False:
 print(get_m(f'Segmentation has failed...')) 
 sys.exit() # BUG: No exit code! Returns 0 (success)

# Line 170-172 
if result == False:
 print(get_m(f'Prediction has failed...')) 
 sys.exit() # BUG: No exit code! Returns 0 (success)
```

**Why it's dangerous:**
- When Stage 1 (segmentation) or Stage 3 (prediction) fails, the pipeline calls `sys.exit()` without an exit code
- Python interprets `sys.exit()` as `sys.exit(0)` which means **SUCCESS**
- SLURM thinks the job completed successfully
- User may not notice the failure
- **Partial/corrupted outputs** left behind

**Correct behavior:**
```python
sys.exit(1) # Non-zero = failure
# or
sys.exit(-1) # Also indicates failure
```

**Real-world impact:**
- In our sub-03 run, this didn't trigger because no stages failed
- But if FreeSurfer had failed, the job would have reported "success"

**Workaround:**
Always check the actual outputs, not just the exit code:
```bash
# Don't trust this alone:
echo $? # May show 0 even on failure

# Always verify outputs exist:
ls meld_data/output/predictions_reports/sub-036/reports/*.pdf
```

---

### **BUG #2: Stage 2 (Preprocessing) Has No Error Checking** 🟡

**Severity:** MEDIUM 
**Impact:** Stage 2 failures are never detected

**Location:** `new_pt_pipeline.py` lines 150-156

**Problem:**
```python
# Stage 1 - HAS error checking 
result = run_script_segmentation(...)
if result == False:
 sys.exit() # (Bug #1 applies, but at least it checks)

# Stage 2 - NO error checking 
run_script_preprocessing(...) 
# No result captured! No failure check!

# Stage 3 - HAS error checking 
result = run_script_prediction(...)
if result == False:
 sys.exit()
```

**Why it's dangerous:**
- `run_script_preprocessing()` doesn't return a value (returns `None`)
- The main pipeline never checks if it succeeded
- If Stage 2 fails:
 - HDF5 files may not be created or corrupted
 - Pipeline continues to Stage 3
 - Stage 3 crashes with confusing error (missing HDF5 file)

**Why it hasn't caused problems (yet):**
- Stage 2 is very robust - rarely fails
- When it does fail, it usually crashes Python entirely (not silent)
- Our sub-03 run: Stage 2 completed successfully

**Workaround:**
Check for HDF5 files after Stage 2:
```bash
ls meld_data/output/preprocessed_surf_data/MELD_*/
# Should see 3 .hdf5 files
```

---

### **BUG #3: Unreachable `else` After `except`** 

**Severity:** LOW (Dead code, doesn't affect functionality) 
**Impact:** None - the code never executes

**Location:** Multiple files (lines 116-118, 229-231, etc.)

**Problem:**
```python
try:
 subject_ids = pd.read_csv(list_ids)
except:
 subject_ids = np.loadtxt(list_ids, dtype='str')
else: # BUG: This 'else' never executes!
 sys.exit('Could not open file')
```

**Python behavior:**
- `try/except/else` - `else` runs only if NO exception occurred
- But if no exception, the code already loaded the file successfully
- The `else` block with `sys.exit()` is unreachable dead code

**Why it doesn't matter:**
- The error handling still works (caught by `except`)
- The `else` was meant to be additional error handling but isn't needed
- This is a code quality issue, not a functional bug

**Impact:** None - just confusing dead code

---

## 🟡 **POTENTIAL CODE-LEVEL RISKS**

### **RISK #1: Multiprocessing Race Conditions** 🟡

**Severity:** MEDIUM 
**Location:** `run_script_segmentation.py` (parallel mode)

**Problem:**
The code uses multiprocessing with locks for parallel subject processing:
```python
pool = multiprocessing.Pool(processes=num_procs, 
 initializer=init, 
 initargs=[multiprocessing.Lock()])
```

**Potential issues:**
1. **Shared file writes:** Multiple processes writing to same log files
2. **HDF5 corruption:** HDF5 files are shared across subjects, not thread-safe
3. **Race in temp file creation:** Demographic files use process IDs

**Current protection:**
- We're NOT using `--parallelise` flag (runs sequentially) 
- Single subject runs avoid most race conditions 

**When it could break:**
```bash
# This could have race conditions:
python new_pt_pipeline.py --ids subjects_list.txt --parallelise
```

**Mitigation:**
- Use SLURM parallelism (multiple jobs) instead of `--parallelise`
- Let each subject run as separate SLURM job
- Avoid `--parallelise` until you understand the risks

---

### **RISK #2: No Atomic File Operations** 🟡

**Severity:** MEDIUM 
**Impact:** Partial writes if interrupted

**Problem:**
The code writes files directly without atomic operations:
```python
# If interrupted during write, file is corrupted
with h5py.File(output_file, 'w') as f:
 f.create_dataset('data', data=large_array) # Not atomic!
```

**When it breaks:**
- Job killed mid-write (time limit, OOM, Ctrl+C)
- NFS hiccup during write
- Power failure / node crash

**Result:**
- Partial HDF5 files (corrupted, unreadable)
- Partial NIfTI files (wrong size, crashes nibabel)

**Why we haven't seen it:**
- Our runs completed successfully
- NFS is generally reliable

**Mitigation:**
- Write to temp file, then atomic rename (code doesn't do this)
- Check file sizes after writing
- Re-run if suspect corruption

---

### **RISK #3: Exception Handling Too Broad** 🟡

**Severity:** LOW 
**Impact:** Real errors might be masked

**Problem:**
```python
try:
 subject_ids = pd.read_csv(list_ids)
except: # Catches EVERYTHING, even bugs!
 subject_ids = np.loadtxt(list_ids)
```

**Why it's risky:**
- Bare `except:` catches ALL exceptions (KeyboardInterrupt, MemoryError, etc.)
- A typo in variable name would be silently caught
- Makes debugging harder

**Better practice:**
```python
try:
 subject_ids = pd.read_csv(list_ids)
except (FileNotFoundError, pd.errors.ParserError): # Specific!
 subject_ids = np.loadtxt(list_ids)
```

**Impact:** Low - the fallback usually works

---

### **RISK #4: No Validation of Intermediate Outputs** 🟡

**Severity:** MEDIUM 
**Impact:** Bad data propagates through stages

**Problem:**
The pipeline doesn't validate outputs between stages:
```python
# Stage 1: Creates FreeSurfer outputs
run_subject_segmentation(...)

# Stage 2: Assumes Stage 1 succeeded, no checks!
run_data_processing_new_subjects(...)
```

**Missing validations:**
- No check if FreeSurfer surfaces exist before feature extraction
- No check if HDF5 files exist before prediction
- No check if HDF5 has expected shape/size
- No checksum validation

**Why it matters:**
- Corrupted FreeSurfer outputs → garbage features → wrong predictions
- Empty HDF5 file → crash in Stage 3
- Partial HDF5 → wrong number of vertices → array shape mismatch

**Mitigation:**
Manually verify key outputs:
```bash
# After Stage 1
ls -lh meld_data/output/fs_outputs/sub-036/surf/lh.white
test -s meld_data/output/fs_outputs/sub-036/surf/lh.white || echo "Empty!"

# After Stage 2 
ls -lh meld_data/output/preprocessed_surf_data/MELD_noHarmo/*.hdf5
```

---

## **WHAT'S ACTUALLY SAFE**

Despite these bugs, the pipeline is generally reliable because:

### **1. Python Crashes on Critical Errors** 
- If HDF5 file missing: `FileNotFoundError` → job fails immediately
- If array shape mismatch: `ValueError` → Python crashes
- If out of memory: `MemoryError` → OS kills job
- These DON'T trigger the silent success bug (Bug #1)

### **2. Our Fixed Bugs Work** 
- Nibabel deprecation: Fixed 
- FreeSurfer initialization: Fixed 
- Path issues: Fixed 
- These were all Python crashes, not silent failures

### **3. FreeSurfer is Robust** 
- FreeSurfer creates checkpoints
- Can resume from interruption
- Validates its own outputs internally

### **4. Single Subject Mode is Safe** 
- No multiprocessing race conditions
- No shared state between runs
- Clean separation

---

## **HOW TO PROTECT YOURSELF**

### **Before Running:**
```bash
# 1. Run safety check
./pipeline_safety_check.sh sub-036

# 2. Check no conflicts
squeue -u $USER
```

### **After Running:**
```bash
# 1. Check exit code (but don't trust it alone!)
echo $?

# 2. Check SLURM log for errors
grep -i "error\|fail\|abort" logs/meld_pipeline_*.err

# 3. Verify all outputs exist
ls meld_data/output/fs_outputs/sub-036/surf/lh.white
ls meld_data/output/preprocessed_surf_data/MELD_noHarmo/*.hdf5
ls meld_data/output/predictions_reports/sub-036/predictions/*.nii.gz
ls meld_data/output/predictions_reports/sub-036/reports/*.pdf

# 4. Check file sizes (not zero/tiny)
find meld_data/output/predictions_reports/sub-036/ -type f -size 0
# Should return nothing

# 5. Verify predictions are not all zeros
python3 << 'EOF'
import nibabel as nib
import numpy as np
img = nib.load("meld_data/output/predictions_reports/sub-036/predictions/prediction.nii.gz")
data = np.asanyarray(img.dataobj)
print(f"Prediction range: [{data.min()}, {data.max()}]")
print(f"Non-zero voxels: {np.count_nonzero(data)}")
# If all zeros, check if subject is control (expected) or patient (possible failure)
EOF
```

### **If Something Seems Wrong:**
```bash
# 1. Check pipeline log
cat meld_data/logs/MELD_pipeline_*.log | grep -i error

# 2. Check FreeSurfer log
cat meld_data/output/fs_outputs/sub-036/scripts/recon-all.log | tail -100

# 3. Clean and re-run
rm -rf meld_data/output/fs_outputs/sub-036
rm -f meld_data/output/preprocessed_surf_data/MELD_noHarmo/*
sbatch run_meld_pipeline_fixed.sh sub-036
```

---

## **RISK SUMMARY TABLE**

| Code Issue | Severity | Likelihood | Can Corrupt? | Workaround |
|-----------|----------|------------|--------------|------------|
| Silent success (Bug #1) | High | Low | No | Check outputs |
| No Stage 2 check (Bug #2) | 🟡 Medium | Very Low | Yes | Check HDF5 files |
| Multiprocessing races | 🟡 Medium | Low | Yes | Don't use --parallelise |
| No atomic writes | 🟡 Medium | Very Low | Yes | Check file sizes |
| Broad exception handling | 🟢 Low | Very Low | No | N/A |
| No output validation | 🟡 Medium | Low | Yes | Manual checks |

---

## **BOTTOM LINE**

**Are there code bugs?** Yes, but manageable.

**Can they corrupt results?** Potentially, but:
- Most bugs cause crashes (detectable) not silent corruption
- We're using safe configuration (no parallelism, single subjects)
- Manual output verification catches issues

**Is it safe to run sub-036?** **YES** 

**Protection strategy:**
1. Run one subject at a time
2. Don't use `--parallelise` flag
3. Verify outputs after each run (use checklist above)
4. Check logs for errors
5. Don't trust exit code alone

**Code quality:** C+ (works, but needs improvement) 
**Production readiness:** B (safe with manual verification) 
**Recommended for use:** YES (with precautions above)

---

## **PROPOSED FIXES** (For Future Development)

These bugs should be fixed in the codebase:

```python
# FIX #1: new_pt_pipeline.py line 144
if result == False:
 print(get_m(f'Segmentation has failed...')) 
 sys.exit(1) # Non-zero exit code

# FIX #2: new_pt_pipeline.py line 150-156
result = run_script_preprocessing(...) # Capture result
if result == False: # Check for failure
 print(get_m(f'Preprocessing has failed...'))
 sys.exit(1)

# FIX #3: Make run_script_preprocessing return bool
def run_script_preprocessing(...):
 try:
 # ... existing code ...
 return True # Success
 except Exception as e:
 print(f"Preprocessing failed: {e}")
 return False # Failure

# FIX #4: Validate intermediate outputs
def validate_freesurfer_outputs(subject_id):
 required_files = [
 f"fs_outputs/{subject_id}/surf/lh.white",
 f"fs_outputs/{subject_id}/surf/rh.white",
 # ... etc
 ]
 for f in required_files:
 if not os.path.exists(f) or os.path.getsize(f) == 0:
 return False
 return True
```

---

**For current use:** The pipeline is safe enough for research use with manual verification. 
**For production use:** These bugs should be fixed first.
