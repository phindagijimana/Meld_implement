# Builder Review — LeGUI (Davis et al. 2021) + local deployment

Evaluation of the *Frontiers in Neuroscience* methods paper and this workspace’s implementation, using the **Inzira Labs Builder Review** style (usability, reproducibility, performance, generalization, clinical use, interpretability, integration, limitations, and builder-oriented conclusions). Full criteria templates may be kept **locally** (e.g. Word/Markdown copies); they are **not** required in the minimal GitHub tree.

**Primary reference:** Davis TS, Caston RM, Philip B, et al. *LeGUI: A Fast and Accurate Graphical User Interface for Automated Detection and Anatomical Localization of Intracranial Electrodes.* Front Neurosci. 2021;15:769872. https://doi.org/10.3389/fnins.2021.769872

**Typical local layout:** `LeGUI` (CLI), `run_LeGUI.sh`, `verify_legui_setup.sh`, docs; plus **locally obtained** `MATLAB_Runtime/v911/`, `LeGUI_Linux_v1.2/` (release zip), and optionally `legui-repo/` from [Rolston-Lab/LeGUI](https://github.com/Rolston-Lab/LeGUI).

---

## Context

LeGUI is a **MATLAB/SPM12-based GUI** for the full intracranial electrode workflow: CT–MRI coregistration, MNI normalization, automated electrode detection (ECoG + SEEG), brain-shift projection / spacing correction, labeling, atlas-based anatomy, and export for analysis. The authors provide **open source (GPL v3)** and **compiled binaries** for Windows, macOS, and Linux tied to a specific **MATLAB Runtime** release (v1.2 → **R2021b**).

This workspace adds a **deployment shell**: MATLAB Runtime install, verification script, **`./LeGUI`** CLI (`install`, `start`, `logs`, `stop`, `checks`), and documentation—not a rewrite of the scientific method.

---

## Platform fit and reproducibility

### Usability

**Published offering**

- Single integrated GUI vs chaining separate tools; SPM12 for core registration/segmentation; standalone executables + MATLAB Runtime for users without a MATLAB license.
- Paper and user materials describe inputs (pre-implant T1, post-implant CT, ideally ≤1 mm), AC–PC alignment, and expected time on the order of ~1 h per case (mixed user + compute).

**This implementation**

- **Strength:** One command surface (`./LeGUI install` → `./LeGUI start`) after MCR is present; `checks` wraps filesystem + `ldd` validation.
- **Friction:** **MATLAB Runtime R2021b** is large (~3.7 GB download); silent install is long; **GUI requires a display** (desktop, VNC, remote desktop, or X11 forwarding)—typical for the product class, but a hard constraint on headless batch clusters.
- **Hidden steps:** Atlas licensing/SPM Anatomy toolbox behavior, DICOM quirks, and per-site CT/MRI quality still drive manual cleanup (false-positive electrodes, labeling), as the paper acknowledges.

### Reproducibility

**What the paper supports**

- Fixed algorithmic story (SPM unified segmentation, threshold search for CT detection, etc.) and validation on **51 datasets** with reported detection sensitivity and atlas agreement statistics.
- Code and v1.2 release are pinned to a **specific runtime**, which helps binary reproducibility.

**Gaps for an external builder**

- End-to-end numerical replication of *your* patient requires **your** imaging; LeGUI does not ship patient data.
- Atlases and normalization are **MNI-oriented**; cross-tool comparisons (e.g. FreeSurfer-based pipelines) will not match voxel-for-voxel without harmonization.
- **Our deployment** reproduces *runnable infrastructure* (MCR + binary + CLI); it does not independently re-validate the paper’s metrics on new data.

**Observed**

- Sensitivity of automatic detection to electrode vendor/geometry (e.g. Dixi SEEG vs Ad-Tech) matches the paper’s stratified results; optimal CT thresholds are **dataset-specific** (bimodal HU distribution)—a reason not to hard-code one global threshold.

---

## Performance, generalization, and comparison

### Performance (real vs reported)

**Paper**

- ~93% automatic detection sensitivity with manageable false positives; timing ~30 min for heavy image steps; assignment and QC time user-dependent.
- Atlas label agreement **73%** (1.3 mm sphere) vs expert, **94%** when using **1 cm** neighborhood labels—shows resolution matters.

**Builder expectation**

- On a new institution’s data, treat paper metrics as **prior**, not guarantee; local QC and optional hand correction remain part of the workflow.
- **This build:** `verify_legui_setup.sh` confirms **dynamic linker** resolution against the bundled MCR; it does **not** benchmark segmentation or detection on imaging.

### Generalization

- Trained/validated cohort is **epilepsy surgical monitoring** (Utah + small Washington set); generalization to **non-epilepsy** iEEG research is plausible but not demonstrated as a separate validation study.
- **Scanner/protocol variability** is partially addressed (multi-site test in paper); extreme CT artifacts, unusual implants, or >250 contacts (default cap) need code/config attention.
- **Regulatory:** paper states LeGUI is **not** FDA-evaluated; clinical use beyond research must respect local governance.

### Comparison to existing methods

- The paper’s **Table 1** positions LeGUI against tools like iElvis, ALICE, iElectrodes, iELU, iEEGView: different mixes of FreeSurfer dependency, runtime length, ECoG vs SEEG support, and unified GUI. **Builder takeaway:** LeGUI trades **FreeSurfer** depth for **SPM + shorter wall time** and **single-interface** operation, at the cost of depending on **MathWorks runtime** for compiled use.

---

## Clinical relevance, interpretability, and integration

### Clinical relevance

- **High** for research groups localizing **SEEG/ECoG** for seizure networks or cognitive iEEG: outputs (MNI coordinates, atlas labels, gray/white) align with common analysis needs.
- **Clinical production** (e.g. surgical planning CAD) is **out of scope** of the publication and this deployment; interpretability of labels still requires imaging QA and expert review at gyral boundaries.

### Interpretability and trust

- **Strength:** Linked 2D/3D visualization, atlas overlays, inline SEEG projection, and explicit saved structures (`ChannelMap.mat`, etc.) support **inspection** of what the tool decided.
- **Trust limits:** Automatic labels are only as good as normalization and atlas warping; the paper honestly notes finer mismatches (e.g. STG vs MTG at borders).

### Integration potential

- **Research integration:** Exports to MATLAB `.mat` / NIfTI ecosystem; custom MNI atlases via `atlases/` folder; natural adjacency to **BIDS**-organized DICOM→NIfTI workflows (manual or scripted upstream).
- **Clinical integration:** Would still require DICOM routing, QC, identity/consent boundaries, and clinical reporting—**not** provided here.
- **This repo’s CLI** improves **operability** (install/check/start/logs/stop) but does not add HL7/PACS connectors.

---

## Limitations and failure modes

- **GUI/display** requirement; headless automation is not the product’s design center.
- **MATLAB Compiler Runtime** version lock-in with compiled releases; mismatched R2021b vs app build causes hard failures.
- **SPM/MATLAB** toolchain: HPC sites may prefer Apptainerized MATLAB or stricter module policies—extra packaging work for centralized IT.
- **NFS/home latency** (as in this deployment) can slow installs and I/O-heavy segmentation; local SSD may be preferable for heavy batch processing.
- **iEEG-specific**; not a general neuroimaging segmentation platform.

---

## Builder insight

LeGUI is **strong on runnable integration of a fragmented workflow** (one GUI, ECoG + SEEG, reasonable validation story). The **builder gap** for new sites is less about code availability and more about **environment + data harmonization**: pinning **MCR R2021b**, securing a **graphical execution path**, and budgeting **QC time** for electrode detection and labeling.

**Potential extensions (system-level)**

- **Container image** bundling MCR + LeGUI binary + entrypoint script for Apptainer/Docker (display still required for interactive use).
- **Optional Xvfb** path only for smoke tests—not a substitute for real QC visualization.
- **CI job** that runs `verify_legui_setup.sh` on a golden image after installs.
- **BIDS helper** script: scaffold `sourcedata/` → DICOM pick conventions LeGUI expects, document channel mapping conventions per institution.

---

## References (selected)

- Davis et al. 2021 *Front. Neurosci.* — LeGUI methods and validation (DOI above).
- Rolston-Lab/LeGUI — source and releases: https://github.com/Rolston-Lab/LeGUI
- `LeGUI.md` — concise paper summary in this folder.
- Builder Review criteria (local or internal docs) — full dimension list if needed for alignment with other reviews.

---

*Last updated: 2026-04-14.*
