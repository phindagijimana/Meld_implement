# New Patient Protocol: DICOM → NIfTI → BIDS → MELD

DICOM to a MELD report with `docker_version/meld-docker`. Paths here are placeholders (`<MELD_ROOT>`, `<Cohort>`, `sub-001`). Chart identifiers (eMRN, accession, name) belong only in `meld_input_mapping.csv`, `SUBJECT_ID_MAPPING.csv`, and `intake/` on the share.

## Paths (Linux NFS)

| Role | Path |
|------|------|
| **Deployment** | `<MELD_ROOT>/docker_version` |
| **Raw DICOM exports** | `<MELD_ROOT>/intake/` |
| **Cohort BIDS data** | `docker_version/meld_data/<CohortFolder>/` |
| **Pipeline input (symlinks)** | `docker_version/meld_data/input/sub-<id>/` |
| **Results** | `docker_version/meld_data/output/predictions_reports/sub-<id>/` |
| **Master subject index** | `<MELD_ROOT>/SUBJECT_ID_MAPPING.csv` |
| **Cohort mapping** | `meld_data/<CohortFolder>/meld_input_mapping.csv` |

Mac equivalent: `<share>/Meld_Graph/...`

---

## Overview

```text
intake (DICOM under RIS folder)
        │
        ▼  dcm2niix → create/use nii/ next to DICOM
   <RIS>/nii/*.nii.gz + *.json   ← canonical pre-BIDS NIfTI (keep here)
        │
        ▼  copy/rename to BIDS names
meld_data/<Cohort>/sub-<id>/anat/
        ├── sub-<id>_T1w.nii.gz
        ├── sub-<id>_T1w.json
        ├── sub-<id>_FLAIR.nii.gz   (if available)
        └── sub-<id>_FLAIR.json
        │
        ▼  meld_input_mapping.csv + SUBJECT_ID_MAPPING.csv
        │
        ▼  ./meld-docker validate + slurm
meld_data/input/sub-<id>  →  symlink to cohort
        │
        ▼  FreeSurfer or FastSurfer + MELD
predictions_reports/sub-<id>/reports/MELD_report_*.pdf
```

---

## 1. Plan the subject ID and cohort

1. **Choose a pipeline subject label:** `sub-<label>` used for flat `anat/`, SLURM job names, and `output/fs_outputs/sub-<label>/`. It must work with **PyBIDS** inside the container (see §1.1).
2. **Avoid ambiguous punctuation in `<label>`** (underscores, `_ses-`, and mid-label hyphens break lookup — §1.1).
3. **Choose a cohort folder** under `meld_data/`, for example `CohortA`.
4. **Fill the request form (§12)** and record identifiers on NFS only (see §5–§6; do not paste into git):
   - RIS accession folder under `intake/` (e.g. `RIS########`)
   - Intake folder name, typically `<internal-chart-id>_sub-<label>` under `intake/`
   - Cohort, pipeline subject ID, scan date, and DICOM/`nii/` paths in mapping **Notes**

### 1.1 PyBIDS-safe pipeline IDs (critical)

`./meld-docker validate` only checks that **`anat/*T1w.nii.gz` exists**. The running pipeline resolves T1 via `get_anat_files()` in the container:

1. Legacy **MELD layout:** `input/sub-<id>/T1/*.nii*` (if present, PyBIDS is skipped).
2. Else **PyBIDS** on the whole `meld_data/input/` tree using `meld_bids_config.json`.

PyBIDS parses BIDS **entities from filenames**. The subject query uses everything after `sub-` in your ID. The **parsed** subject entity must match that string exactly.

**Rules for flat pipeline folders** (`sub-<label>/anat/sub-<label>_T1w.nii.gz`):

| Rule | Why |
|------|-----|
| **No `_` inside `<label>`** | Each `_` starts another BIDS entity; e.g. `sub-003ses4_5_2022-01` indexes as subject `003ses4`, not the full string → pipeline crash (`subject_dict` is `None`). |
| **No `_ses-` inside `<label>`** | BIDS treats `_ses-` as a **session** delimiter, not part of the subject. |
| **No `-` inside `<label>`** (this PyBIDS build) | e.g. `sub-003-4-5-2022-01` indexes as subject `003` only. |
| **Prefer one continuous token** | Alphanumeric after `sub-`, e.g. `002`, `003ses20220405`. |

**Recommended patterns**

| Use case | Pipeline ID example | Human session in CSV |
|----------|---------------------|----------------------|
| Single visit | `sub-001` | (none or `ses-01`) |
| Multi-visit, date-encoded | `sub-003ses20220405` | `ses-4_5_2022-01` |
| Multi-visit, short ordinal | `sub-003ses1` | full session label in Notes |

**Do not use (fail PyBIDS unless you add `T1/` — §4.1)**

| Bad pipeline ID | Parsed subject (typical) |
|-----------------|---------------------------|
| `sub-003_ses-4_5_2022-01` | subject/session split at `_ses-` |
| `sub-003ses4_5_2022-01` | `003ses4` |
| `sub-003ses4-5-2022-01` | `003ses4` |

**Fallback if an ID cannot be made PyBIDS-safe:** add `sub-<id>/T1/` with a single symlink to `anat/sub-<id>_T1w.nii.gz`. The container uses MELD layout first; results use the same voxels as `anat/`. Prefer fixing the ID instead when possible.

**Session names in canonical BIDS** (`ses-4_5_2022-01` under `sub-<patient>/`) do **not** affect FreeSurfer/MELD math — only organization and CSV metadata. **The T1 file staged for that visit** defines the result.

---

## 2. Locate DICOM and create `nii/`

Typical layout under `intake`:

```text
intake/E########_sub-<label>/
  └── <RIS accession>/          e.g. RIS24515584
        ├── DICOM/...           series tree from export
        ├── REPORTS/ ...
        └── nii/                ← create this; all dcm2niix output lives here
              ├── <series>_2.nii.gz
              ├── <series>_2.json
              └── ...           (one subfolder per series is OK, e.g. 000024FA_nii/)
```

**Convention:** Once you identify the DICOM series folder(s) for T1 (and FLAIR if present), **`mkdir -p <RIS>/nii`** and convert **into `nii/`**, not directly into the cohort BIDS folder. The files in `nii/` are the **working NIfTI archive** referenced in mapping CSVs and used as the source for the BIDS copy step.

Before converting:

- Confirm **which series** is T1w (e.g. AX 3D MPRAGE, SAG FSPGR BRAVO).
- Confirm whether **FLAIR** exists (e.g. `3D_T2_FLAIR`) on the same study when possible.
- Note scanner, date, and protocol from DICOM or PACS — these go into the mapping CSV **Notes** column.

**FLAIR strongly recommended** when available: MELD uses GM/WM FLAIR features; T1-only runs still work but with reduced sensitivity and no FLAIR saliency in cluster CSVs.

Example path pattern (same patient, placeholders):

- DICOM: `intake/<intake-folder>/RIS########/DICOM/.../<series-uid>/`
- NIfTI: `intake/<intake-folder>/RIS########/nii/<dcm2niix-output>.nii.gz`

---

## 3. DICOM → NIfTI (`dcm2niix` → `nii/`)

Run on the **DICOM series directory** (leaf folder containing `.dcm` files). Output goes to **`nii/`** under the same RIS folder.

```bash
STUDY="<MELD_ROOT>/intake/<intake-folder>/RIS########"
DICOM_DIR="${STUDY}/DICOM/00000228/AADACDDC/AAC9F6BF/0000CDFE"
NII_DIR="${STUDY}/nii"

mkdir -p "$NII_DIR"
dcm2niix -z y -o "$NII_DIR" "$DICOM_DIR"
```

Use default dcm2niix filenames (e.g. `FMRI_comprehensive_3mm_2.nii.gz`) — record the **original filename** in `meld_input_mapping.csv` (`T1w Original Filename`).

For a second series (FLAIR), convert into the same `nii/` tree (or a subfolder such as `nii/00007F51_nii/` if you convert per-series).

Check output:

```bash
python3 -c "
import nibabel as nib
from pathlib import Path
p = next(Path('$NII_DIR').glob('*.nii.gz'))
img = nib.load(p)
print('File:', p.name, 'Shape:', img.shape, 'Zooms:', img.header.get_zooms()[:3])
"
```

Keep each `.json` sidecar next to its `.nii.gz` in `nii/`.

---

## 4. `nii/` → BIDS in the cohort folder

**Required layout** (flat session — what `meld-docker validate` expects):

```text
meld_data/<Cohort>/sub-<id>/
  └── anat/
        ├── sub-<id>_T1w.nii.gz
        ├── sub-<id>_T1w.json
        ├── sub-<id>_FLAIR.nii.gz   (optional)
        └── sub-<id>_FLAIR.json     (optional)
```

Copy or move from **`intake/.../nii/`** into the cohort `anat/` folder with BIDS names:

```bash
COHORT_ANAT="<MELD_ROOT>/docker_version/meld_data/CohortB/sub-002/anat"
SRC="${STUDY}/nii/FMRI_comprehensive_3mm_2.nii.gz"
SRC_JSON="${STUDY}/nii/FMRI_comprehensive_3mm_2.json"

mkdir -p "$COHORT_ANAT"
cp "$SRC" "$COHORT_ANAT/sub-002_T1w.nii.gz"
cp "$SRC_JSON" "$COHORT_ANAT/sub-002_T1w.json"
```

Rules:

- Filenames must match the subject folder: `sub-001/anat/sub-001_T1w.nii.gz`.
- **Do not** point MELD at `nii/` directly — always stage through cohort BIDS `anat/`.
- Leave the **`nii/`** copies in place as the audit trail; mapping **Notes** should list both `nii/` and BIDS paths.
- Reference cohort for layout: `meld_data/CohortA/sub-001/`.

**Multiple sessions (one MELD job per session):** You need **two different FreeSurfer subject directories**, so do **not** run one SLURM job on a multi-session BIDS tree alone. Use **dual layout**:

```text
meld_data/<Cohort>/
  sub-<patient>/                          ← canonical BIDS (audit / reporting)
    ses-<human-label>/anat/
      sub-<patient>_T1w.nii.gz            ← same patient prefix in filenames
      sub-<patient>_T1w.json
  sub-<patient>ses<YYYYMMDD>/             ← flat pipeline subject (one per visit)
    anat/
      sub-<patient>ses<YYYYMMDD>_T1w.nii.gz
      sub-<patient>ses<YYYYMMDD>_T1w.json
```

- **Canonical tree:** session labels can use underscores (e.g. `ses-4_5_2022-01`); filenames stay `sub-<patient>_T1w.*`.
- **Pipeline tree:** PyBIDS-safe ID per §1.1 (e.g. `sub-003ses20220405` for scan date 2022-04-05).
- **Mapping CSV:** `Subject ID` = pipeline ID; **Session** column = human BIDS session label; **Notes** link RIS, `nii/`, and canonical BIDS path.
- **Sync:** `./meld-docker slurm` symlinks each flat `sub-*` with top-level `anat/*T1w` into `input/`. The parent `sub-<patient>/` folder **without** top-level `anat/` is skipped (expected warning).

### 4.1 Optional `T1/` fallback (non–PyBIDS-safe IDs)

If you must keep an ID with `_` or `_ses-` in the label:

```bash
PIPE=sub-003ses4_5_2022-01   # example: PyBIDS-unsafe
mkdir -p "meld_data/<Cohort>/${PIPE}/T1"
ln -sf "../anat/${PIPE}_T1w.nii.gz" "meld_data/<Cohort>/${PIPE}/T1/${PIPE}_T1w.nii.gz"
```

Remove `T1/` when you rename to a PyBIDS-safe ID so lookup uses BIDS `anat/` only.

---

## 5. Cohort mapping CSV

Create or append a row in:

`meld_data/<Cohort>/meld_input_mapping.csv`

Use the same columns as `CohortA/meld_input_mapping.csv` (Subject ID, Type, Patient ID, scan metadata, filenames, Processing Status, cluster fields, Notes).

**Notes should include** (relative to `Meld_Graph` root when possible):

- DICOM path under `intake/...`
- NIfTI path if kept outside BIDS
- BIDS path: `docker_version/meld_data/<Cohort>/sub-<id>/anat/sub-<id>_T1w.nii.gz`
- Scanner, protocol, FLAIR yes/no, dcm2niix version

Set **Processing Status** to `PENDING` before the run; update to `SUCCESS` / method and cluster stats after completion.

---

## 6. Master subject index

Append a row to:

`<MELD_ROOT>/SUBJECT_ID_MAPPING.csv`

Key fields: `meld_subject_id`, study date, `urmc_meld_test_folder`, `input_cohort`, `input_path`, `t1w_bids_path`, `has_meld_fs_output`, `has_meld_predictions`, `source_mapping_file`, `notes`. Chart identifiers (eMRN, name, RIS) live in this NFS file only — see `SUBJECT_ID_MAPPING_README.txt`.

See `SUBJECT_ID_MAPPING_README.txt` on the share for column definitions.

---

## 7. Sync input and validate

All commands from `docker_version/`:

```bash
cd <MELD_ROOT>/docker_version

./meld-docker check
./meld-docker validate sub-<id>
```

`validate` checks:

- `meld_data/input/sub-<id>/anat/*T1w.nii.gz` (via cohort symlink)
- Optional `*FLAIR.nii.gz`
- `meld_data/input/dataset_description.json` and `meld_bids_config.json`

**Validate passing does not guarantee the container finds T1** if the pipeline ID is PyBIDS-unsafe (§1.1). Before a long SLURM run, optionally confirm in the container or watch the first minute of logs for `T1 file used : ...` (not an immediate `TypeError: 'NoneType' object is not subscriptable`).

**Sync:** `./meld-docker slurm sub-<id>` runs cohort sync first — it symlinks each `meld_data/<Cohort>/sub-*` into `meld_data/input/sub-*`. Do not create real directories under `input/` unless intentional (known issue: `sub-004` / `sub-001` as non-symlinks block sync).

---

## 8. Run MELD on SLURM

### FreeSurfer (default, slower, reference segmentation)

```bash
cd <MELD_ROOT>/docker_version
SLURM_PARTITION=general SLURM_TIME_LIMIT=24:00:00 ./meld-docker slurm sub-<id>
```

Typical wall time: **~4–5 hours** (FreeSurfer ~4 h + MELD).

### FastSurfer (faster)

```bash
SLURM_PARTITION=interactive SLURM_TIME_LIMIT=11:00:00 \
  ./meld-docker slurm sub-<id> --fastsurfer
```

Typical wall time: **~1.5–2 hours**.

### Environment knobs

| Variable | Default | Purpose |
|----------|---------|---------|
| `SLURM_PARTITION` | (site default) | `general`, `interactive`, etc. |
| `SLURM_TIME_LIMIT` | `24:00:00` | Job wall time |
| `SLURM_MEM` | `64G` | RAM |
| `SLURM_CPUS_PER_TASK` | `8` | CPUs |

---

## 9. FreeSurfer vs FastSurfer on the **same** T1 (comparison runs)

You **cannot** run two pipelines concurrently on the same `sub-<id>` — shared locks and output dirs:

- `meld_data/locks/sub-<id>.lock`
- `output/fs_outputs/sub-<id>/`
- `output/predictions_reports/sub-<id>/`

**Protocol for comparison:**

1. Run primary subject (e.g. FastSurfer on `sub-002`).
2. Create a **second subject ID** with the same T1w via symlinks:

```bash
COHORT=".../meld_data/CohortB"
NEW=sub-002FS
BASE=sub-002
mkdir -p "${COHORT}/${NEW}/anat"
ln -sf "../../${BASE}/anat/${BASE}_T1w.nii.gz" "${COHORT}/${NEW}/anat/${NEW}_T1w.nii.gz"
ln -sf "../../${BASE}/anat/${BASE}_T1w.json" "${COHORT}/${NEW}/anat/${NEW}_T1w.json"
```

3. Add a second row to `meld_input_mapping.csv` (Type: `Derived (FreeSurfer)` or similar).
4. Run `./meld-docker slurm sub-<new-id>` without `--fastsurfer`.

BIDS filenames must use the **new** subject prefix (`sub-002FS_T1w.nii.gz`), not the source subject name.

---

## 10. Monitor and collect results

```bash
squeue -u "$USER"
./meld-docker status sub-<id>
./meld-docker logs sub-<id>
./meld-docker results sub-<id>
```

**Outputs:**

```text
meld_data/output/predictions_reports/sub-<id>/reports/
  ├── MELD_report_sub-<id>.pdf
  ├── info_clusters_sub-<id>.csv
  ├── inflatbrain_sub-<id>.png
  └── saliency / MRI figures
```

**Logs:**

- `meld_data/logs/slurm_sub-<id>_<jobid>.out`
- `meld_data/logs/MELD_pipeline_sub-<id>_*.log`
- `meld_data/output/fs_outputs/sub-<id>/scripts/recon-all.log`

After success, update mapping CSVs: Processing Status, cluster count, confidence, location, SLURM job ID, elapsed time.

---

## 11. Re-runs, cancel, rename, and cleanup

If FreeSurfer fails or stops mid-`recon-all`:

1. Remove partial outputs to avoid resume conflicts:

```bash
rm -rf meld_data/output/fs_outputs/sub-<id>
rm -rf meld_data/output/predictions_reports/sub-<id>
rm -f meld_data/locks/sub-<id>.lock
# optional: remove old slurm/pipeline logs for clarity
```

2. Resubmit `./meld-docker slurm sub-<id>`.

**Cancelling SLURM and changing pipeline subject ID** (e.g. fixing PyBIDS naming):

```bash
scancel <jobid>
rm -f meld_data/locks/sub-<old-id>.lock
rm -rf meld_data/output/fs_outputs/sub-<old-id>
rm -rf meld_data/output/predictions_reports/sub-<old-id>
# rename cohort folder + anat/*_T1w.* ; update input/ symlink
rm -f meld_data/input/sub-<old-id>
ln -sfn "../<Cohort>/sub-<new-id>" meld_data/input/sub-<new-id>
# update meld_input_mapping.csv and SUBJECT_ID_MAPPING.csv
```

Remove **`T1/`** if the new ID is PyBIDS-safe. Delete **all** old-ID output dirs so cancelled runs do not collide with reruns. SLURM `.out` logs can stay as audit history.

If a job exits SLURM `COMPLETED` but `recon-all` is incomplete, treat as failed — check `recon-all.log` and node load; prefer `general` with adequate time limit when `interactive` is congested.

---

## 12. New patient request form (fill before processing)

Use this table for each MELD request (email, ticket, or lab spreadsheet). **Chart IDs and names stay on NFS** in mapping CSVs — this form can be shared with whoever runs the pipeline without putting eMRN in git.

| Item | Why | Your answer |
|------|-----|-------------|
| **Path(s) to DICOM or intake folder** | Starting point under `intake/` (one path per RIS visit if multiple) | |
| **Cohort** | Where BIDS and CSV live, e.g. `CohortC` | |
| **BIDS patient label** | Canonical tree: `sub-005` (new vs existing patient) | |
| **One or multiple scans** | **One SLURM job per visit**; list each visit and canonical **session label** (`ses-*`) | |
| **Pipeline subject ID(s)** | PyBIDS-safe flat ID per visit, e.g. `sub-005ses20220405` (§1.1) | |
| **T1 series** | If several MPRAGE/3D sequences, which is **clinical T1** (series desc / folder name) | |
| **FLAIR** | Yes/no; which series if yes (strongly recommended when available) | |
| **Segmentation + SLURM** | **FreeSurfer** (default) or **FastSurfer** (`--fastsurfer`); partition + wall time, e.g. `interactive` + `11:00:00` | |

After the form is complete, run the checklist (§13) and record full paths plus eMRN/RIS in **`meld_input_mapping.csv`** and **`SUBJECT_ID_MAPPING.csv`** on NFS.

**Copy-paste prompt for automated setup (optional):**  
*“Cohort `<Cohort>`, BIDS patient `sub-<label>`, intake path(s) `<path>`, `<N>` scan(s), session(s) `<ses-…>`, T1-only / T1+FLAIR, `<FreeSurfer|FastSurfer>` on `<partition>`.”*

---

## 13. Checklist (new patient)

- [ ] **Request form (§12) filled**
- [ ] Pipeline subject ID chosen (PyBIDS-safe per §1.1; multi-session = one flat ID per visit)
- [ ] If multi-session: canonical BIDS under `sub-<patient>/ses-*/anat/` **and** flat pipeline folder(s)
- [ ] DICOM series identified (T1 ± FLAIR)
- [ ] `nii/` created under RIS folder; `dcm2niix` output saved there
- [ ] Selected volumes copied/renamed to BIDS in `meld_data/<Cohort>/sub-<id>/anat/`
- [ ] Row added to `meld_input_mapping.csv` (PENDING)
- [ ] Row added to `SUBJECT_ID_MAPPING.csv`
- [ ] `./meld-docker validate sub-<id>` passes
- [ ] SLURM job submitted (`slurm` syncs input automatically)
- [ ] Results verified; CSVs updated to SUCCESS with cluster metrics
- [ ] Handoff email sent if needed (§16; paths on share, identifiers only in email/NFS)
- [ ] No PHI committed to git (data stay on NFS; see `docs/DATA_PRIVACY.md`)

---

## 14. Worked examples

Paths are relative to `<MELD_ROOT>/docker_version/`. Intake NIfTI stays under `../intake/` (§2–§3) and is copied into `meld_data/<Cohort>/`. Durations are typical, not a guarantee.

### Example A — `sub-001` (`meld_data/CohortA`, T1-only structural)

| Step | Path under `docker_version/` |
|------|--------------------------------|
| **Cohort BIDS** | `meld_data/CohortA/sub-001/anat/sub-001_T1w.nii.gz` (+ `.json`) |
| **Pipeline input** | `meld_data/input/sub-001` → symlink to `../CohortA/sub-001` |
| **Cohort mapping** | `meld_data/CohortA/meld_input_mapping.csv` |
| **MELD run** | FreeSurfer (default), about 4 hours |
| **Results** | `meld_data/output/predictions_reports/sub-001/reports/MELD_report_sub-001.pdf` |
| **Segmentation** | `meld_data/output/fs_outputs/sub-001/` |

**Source NIfTI (pre-BIDS):** `../intake/<intake-folder>/RIS########/nii/*T1w*.nii.gz` → copied/renamed to BIDS above. **No FLAIR** — 0 clusters above threshold (expected for T1-only). Exact RIS/`nii/` names recorded in cohort mapping CSV on NFS.

---

### Example B — `sub-002` (`meld_data/CohortB`, fMRI-derived T1)

| Step | Path under `docker_version/` |
|------|--------------------------------|
| **Cohort BIDS** | `meld_data/CohortB/sub-002/anat/sub-002_T1w.nii.gz` |
| **Pipeline input** | `meld_data/input/sub-002` → `../CohortB/sub-002` |
| **Cohort mapping** | `meld_data/CohortB/meld_input_mapping.csv` |
| **MELD run** | FastSurfer, about 1.5–2 hours |
| **Results** | `meld_data/output/predictions_reports/sub-002/reports/MELD_report_sub-002.pdf` |

**Source NIfTI:** `../intake/<intake-folder>/RIS########/nii/` (fMRI-derived T1 in that case). **T1-only** — example outcome: 1 cluster, posterior cingulate, **~90%** confidence.

**FreeSurfer comparison (same T1, second subject ID):**

| | |
|--|--|
| **Cohort BIDS** | `meld_data/CohortB/sub-002FS/anat/sub-002FS_T1w.nii.gz` (symlink to Example B T1w) |
| **MELD run** | FreeSurfer on `general`, about 4 hours |
| **Results** | `meld_data/output/predictions_reports/sub-002FS/reports/MELD_report_sub-002FS.pdf` |

See §9 for why `sub-002FS` is a separate ID from `sub-002`.

---

### Example C — `sub-003` (`meld_data/CohortC`, two sessions, T1-only)

Same patient, **two scans**, **two SLURM jobs**, **no FLAIR**. Illustrates canonical BIDS + PyBIDS-safe pipeline IDs (§4).

| Visit | Canonical BIDS | Pipeline subject ID |
|-------|----------------|---------------------|
| 2022-04-05 | `CohortC/sub-003/ses-4_5_2022-01/anat/sub-003_T1w.nii.gz` | `sub-003ses20220405` |
| 2025-10-23 | `CohortC/sub-003/ses-10_23_2025-02/anat/sub-003_T1w.nii.gz` | `sub-003ses20251023` |

| Step | Detail |
|------|--------|
| **Intake** | `intake/<intake-folder>/RIS########/nii/` after `dcm2niix` (SAG MPRAGE, 160 slices per visit) |
| **Pipeline BIDS** | `meld_data/CohortC/sub-003ses20220405/anat/sub-003ses20220405_T1w.nii.gz` (and matching 2025 ID) |
| **Input symlinks** | `meld_data/input/sub-003ses20220405` → `../CohortC/sub-003ses20220405` |
| **Mapping** | `CohortC/meld_input_mapping.csv` — Session column keeps `ses-4_5_2022-01` / `ses-10_23_2025-02`; Subject ID = pipeline ID |
| **Master index** | `SUBJECT_ID_MAPPING.csv` — one row per pipeline subject |
| **Validate** | `./meld-docker validate sub-003ses20220405` (and 20251023); FLAIR warning OK for T1-only |
| **Run** | `./meld-docker slurm sub-003ses20220405` and separate job for `sub-003ses20251023` (FreeSurfer default) |

**Naming lessons from this case:** IDs like `sub-003_ses-…` or `sub-003ses4_5_2022-01` failed at runtime despite validate; date-suffixed IDs `sub-003ses20220405` resolve T1 via PyBIDS from `anat/` without `T1/`.

---

## 15. Quick reference commands

```bash
cd <MELD_ROOT>/docker_version

./meld-docker check
./meld-docker validate sub-002
./meld-docker slurm sub-002 --fastsurfer
./meld-docker slurm sub-002FS          # FreeSurfer comparison
./meld-docker slurm sub-003ses20220405          # multi-session visit 1
./meld-docker slurm sub-003ses20251023          # multi-session visit 2
./meld-docker results sub-002
```

---

## 16. Email handoff to collaborators (after SUCCESS)

Use a short email so others can find **DICOM**, **pipeline input**, and **MELD reports** on the shared drive. Use **share-relative paths** (the same tree your colleagues open under `<share>/Meld_Graph/`). **Do not put eMRN or patient names in git** — fill those only in the email or the mapping CSVs when you send it.

**Subject (example):** `MELD — sub-<label> — <T1 protocol> — paths on the shared drive`

**Body template:**

```text
Hi,

I have run <T1 protocol, e.g. SAG MPRAGE / AX 3D MPRAGE> <(T1-only | T1+FLAIR)>, and:

The DICOM files are here:
<share>/Meld_Graph/intake/<intake-folder>/<RIS>/DICOM/
<Repeat DICOM line if multiple RIS visits.>

<If FastSurfer was run — optional:>
FastSurfer:
The input is here:
<share>/Meld_Graph/docker_version/meld_data/<Cohort>/sub-<pipeline-id>/
The output is here:
<share>/Meld_Graph/docker_version/meld_data/output/predictions_reports/sub-<pipeline-id>/reports/

<If FreeSurfer was run — default or comparison ID:>
FreeSurfer:
The input is here< (same T1 as FastSurfer, or separate pipeline ID if comparison — see §9)>:
<share>/Meld_Graph/docker_version/meld_data/<Cohort>/sub-<pipeline-id>/
The output is here:
<share>/Meld_Graph/docker_version/meld_data/output/predictions_reports/sub-<pipeline-id>/reports/

<Optional one line from mapping CSV after run:>
MELD summary: <N> cluster(s)<, location, confidence if useful>. T1-only runs often have 0 or low-confidence clusters.

Let me know if you are able to see these folders.

Thanks,
<Your name>
```

**Multi-session (one email, two visits):** list **DICOM per RIS**, then **one input/output block per pipeline subject ID** (e.g. `sub-<patient>ses20220405` and `sub-<patient>ses20251023`). Optionally mention canonical BIDS under `meld_data/<Cohort>/sub-<patient>/ses-*/anat/` for audit only.

**FastSurfer + FreeSurfer on the same T1:** use **two pipeline IDs** (§9), e.g. `sub-<label>` for FastSurfer and `sub-<label>FS` or `sub-<prefix>freesurfer<label>` for FreeSurfer — each with its own `predictions_reports/sub-*/reports/` folder.

**Mac users:** same tree under `<share>/Meld_Graph/...`.

**Where to copy paths from:** §12 form, `meld_input_mapping.csv` Notes (after SUCCESS), and `output/predictions_reports/sub-<id>/reports/MELD_report_*.pdf`.

---

## 17. Related docs

- `README.md` — clone and run
- `REPRODUCIBILITY.md` — pinned image, weights, and what will still differ
- `TECHNICAL_REFERENCE.md` — pipeline details
- `docs/DATA_PRIVACY.md` — what not to push to GitHub (also `docs/DATA_PRIVACY.docx`)
- **Word copies (same folder on NFS):** `docs/NEW_PATIENT_MELD_PROTOCOL.docx`, `docs/DATA_PRIVACY.docx` — regenerate from Markdown with `pandoc docs/<name>.md -o docs/<name>.docx` after editing the `.md` source.
- Upstream: [MELD Graph Singularity install](https://meld-graph.readthedocs.io/en/latest/install_singularity.html)
