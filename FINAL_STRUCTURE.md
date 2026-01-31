# MELD Pipeline - Clean Directory Structure

**Last Updated:** 2026-01-30 
**Status:** **CLEANED & ORGANIZED**

---

## **PRODUCTION-READY STRUCTURE**

```
Meld_Graph/
 PRODUCTION SCRIPTS
 run_meld_pipeline_fixed.sh Main SLURM submission script
 pipeline_safety_check.sh Pre-flight safety checker

 DOCUMENTATION
 README.md Main project readme
 PRODUCTION_FIXES_APPLIED.md Production fixes (PRIMARY DOC)
 PIPELINE_STATUS.md Pipeline readiness status
 PIPELINE_RISKS.md Infrastructure risks
 CODE_LEVEL_RISKS.md Code-level risks
 SUB03_RESULTS_ANALYSIS.md Validation results

 CONFIGURATION
 meld_config.sh Original configuration

 🧬 CORE PIPELINE
 meld_graph/ Main pipeline code
 scripts/ Pipeline stages
 meld_graph/ Core modules
 meld_data/ Data & outputs

 INFRASTRUCTURE
 .freesurfer_wrappers/ FreeSurfer container wrappers
 freesurfer_license/ FreeSurfer license
 containers/ FreeSurfer container
 logs/ SLURM job logs

 .gitignore Version control
```

---

## **CLEANED UP (6 files removed)**

### Removed Files:
- `complete_meld_sub03.sh` (test script)
- `finish_meld_sub03.sh` (test script)
- `test_production_fixes.sh` (test script)
- `PIPELINE_FIXES.md` (superseded documentation)
- `meld_graph/extract_features_sub03.py` (test script)
- `meld_graph/complete_hdf5_sub03.py` (test script)

**All removed files were:**
- Temporary test scripts
- Subject-specific (sub-03 debugging)
- No production dependencies

---

## **ESSENTIAL FILES KEPT**

### Production Scripts (2)
```bash
run_meld_pipeline_fixed.sh # Main pipeline - CRITICAL
pipeline_safety_check.sh # Safety checker - RECOMMENDED
```

### Documentation (6)
All documentation kept for reference:
- **Primary**: `PRODUCTION_FIXES_APPLIED.md` (read this first!)
- Status: `PIPELINE_STATUS.md`
- Risks: `PIPELINE_RISKS.md`, `CODE_LEVEL_RISKS.md`
- Validation: `SUB03_RESULTS_ANALYSIS.md`
- Readme: `README.md`

### Infrastructure (4 directories)
```
.freesurfer_wrappers/ # CRITICAL - don't delete!
freesurfer_license/ # REQUIRED
containers/ # REQUIRED (FreeSurfer 7.4.1)
logs/ # Job logs
```

---

## **HOW TO USE**

### Quick Start
```bash
cd /mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/Meld_Graph

# 1. Safety check
./pipeline_safety_check.sh sub-036

# 2. Submit job
sbatch run_meld_pipeline_fixed.sh sub-036
```

### Documentation Guide
1. **Start here**: `PRODUCTION_FIXES_APPLIED.md`
2. **Understand risks**: `PIPELINE_RISKS.md` + `CODE_LEVEL_RISKS.md`
3. **Check status**: `PIPELINE_STATUS.md`
4. **See validation**: `SUB03_RESULTS_ANALYSIS.md`

---

## **VERIFICATION**

```bash
# Check essential files exist
ls run_meld_pipeline_fixed.sh # 
ls pipeline_safety_check.sh # 
ls .freesurfer_wrappers/recon-all # 
ls freesurfer_license/license.txt # 
ls containers/freesurfer-7.4.1.sif # 
ls meld_graph/scripts/new_patient_pipeline/new_pt_pipeline.py # 
```

---

## **DIRECTORY SIZE**

```
Total: ~1.6 MB (documentation + scripts)
- Core scripts: ~15 KB
- Documentation: ~70 KB
- PDF paper: ~1.5 MB
```

*Note: Actual data/outputs in meld_graph/meld_data/ not included in this count*

---

## **READY FOR PRODUCTION**

This cleaned structure contains:
- All production-ready scripts
- Comprehensive documentation
- Essential infrastructure
- No temporary files
- No obsolete code

**Next step:** Run sub-036! 
