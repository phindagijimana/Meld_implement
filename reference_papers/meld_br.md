# Builder Review — MELD Graph (Ripart et al. 2025) + this workspace

Evaluation of the *JAMA Neurology* original investigation and this repository’s **deployment and pipeline wiring**, using the same **Inzira Labs–style** lens as `LeGUI_br.md` and the criteria in `build_reviewer.docx` (usability, reproducibility, performance vs claims, generalization, clinical use, interpretability, integration, limitations, and builder-oriented conclusions).

**Primary reference:** Ripart M, Spitzer H, Williams LZJ, et al. *Detection of Epileptogenic Focal Cortical Dysplasia Using Graph Neural Networks: A MELD Study.* **JAMA Neurol.** 2025;82(4):397-406. https://doi.org/10.1001/jamaneurol.2024.5406

**Typical local layout here:** top-level **`./meld`** (SLURM-oriented production CLI), **`meld_config.sh`** and **`meld_graph/`** (vendored **MELDProject/meld_graph**-style tree with `scripts/new_patient_pipeline/`, tests, BIDS config); **`docker_version/`** with **`meld-docker`** (Apptainer/Singularity **v2.2.4** `meld_graph_*.sif`), optional **`production.env`**, and **`meld_docker_smoke_test.sh`**. See also `meld_tech.md`, `meld.md`, and `saliency.md` in this folder for paper and implementation detail.

---

## Context

MELD Graph is a **public** graph-neural approach to **FCD lesion detection** on the cortical surface: hand-crafted **FreeSurfer-derived features** (34 channels at ~160k vertices per hemisphere), **whole-hemisphere** context, **clustered** surface predictions, **PDF reports** (location, size, **confidence**, feature profiles, **integrated-gradients saliency**), and **native-space NIfTI** outputs. The paper positions it as a **radiological adjunct**, not a stand-alone diagnosis, with multicenter + **independent three-center** test arms and a strong **PPV / false-positive cluster** story vs the earlier **MELD MLP**.

This workspace does not re-derive the GNN; it adds **runnable operations**: **containerized** execution aligned with upstream docs, **HPC/SLURM** submission, **path and cohort** conventions, and local notes on **interpretability** (e.g. saliency path in `meld_graph` and `saliency.md`).

---

## Platform fit and reproducibility

### Usability

**Published offering**

- Clear clinical framing (FCD, drug-resistant epilepsy), **STARD**-aligned reporting, and a **code + pre-trained model** story via **MELDProject/meld_graph**.
- End-to-end expectation: **T1** (+ **FLAIR** when available) → **segmentation** (FreeSurfer or FastSurfer) → feature pipeline → **inference** → **report**.

**This implementation**

- **Strengths:**  
  - **`meld-docker`** provides a **single Apptainer interface** (`check`, `run`, `batch`, `validate`, `logs`, `status`, `results`, **`slurm` / cohort flows**) with **documented** passthrough to `new_pt_pipeline.py` (e.g. **`-harmo_code`**, **`--fastsurfer`**, `--skip_feature_extraction`, report toggles).  
  - **Portable roots** via `MELD_DEPLOY_ROOT`, `MELD_DATA_DIR`, and optional **`production.env`**—suitable for **NFS** layouts where the bundle and heavy `meld_data/` diverge.  
  - Top-level **`./meld`** targets **SLURM batch** use with install/run/batch/status pattern analogous to other lab “production” CLIs.  
- **Friction:** The full path still depends on **licenses** (FreeSurfer, MELD), **large** container/model artifacts, and **long** per-subject wall time (FreeSurfer-class steps dominate). **Report/PDF** and **NIfTI** paths assume a working preprocessing chain—this is a **compute-heavy** product class, not a single Python cell.

**Hidden steps (builder reality)**

- **BIDS**-style organization and `input/` **sync** for cohorts are part of “making it go” on a real filesystem; the paper’s statistics assume **MELD-style** curation and **harmonization** where site shift matters.  
- **Scanner harmonization** is a **first-class** paper topic; new sites with **fewer than about 20** usable scans face the **non-harmonized** tradeoff the supplement documents—**not** something the shell layer fixes.

### Reproducibility

**What the paper supports**

- Prespecified metrics (**sensitivity, specificity, PPV, IoU**), **bootstrap** CIs, and **independent** holdout centers; emphasis on **fewer** off-target **clusters** vs MELD MLP.  
- **Open code** and **versioned** model artifacts when following upstream releases.

**Gaps for an external builder**

- **Cohort data** for replication of the exact numbers is **not** all public (see data-sharing statement in the paper / supplement). **Our deployment** reproduces *runnable stack + same pipeline entrypoints*; it does not independently re-validate JAMA table entries on a full replica dataset.  
- **Harmonization** and **per-site** acquisition variability mean **local** PPV/sensitivity can **differ** from the paper even when the same weights are used.

**Observed from implementation**

- Tests under `meld_graph/meld_graph/test/` (e.g. cohort/subject) support **structural** sanity of the Python package, not end-to-end imaging benchmarks.  
- **`meld_docker_smoke_test.sh`**-style checks are the right class of **CI-ish** signal: **image + licenses + minimal execution**, not a repeat of the multicenter study.

---

## Performance, generalization, and comparison

### Performance (real vs reported)

**Paper (high level)**

- Main test split: **higher PPV** and **better IoU** for MELD Graph vs MELD MLP; **capped** false-positive **clusters** vs baseline—central to the clinical usability claim.  
- **Independent** cohort: similar **PPV** story with site independence caveats.  
- **ECE** and **confidence** described as **reasonably** calibrated; **IoU** vs **confidence** correlation reported.

**Builder expectation**

- Treat published metrics as a **strong prior** for **MELD-like** data and preprocessing; for a **new** hospital, prioritize **prevalence, QC, harmonization, and MELD**-compatible surfaces over chasing the same point estimates.  
- **This build:** `check` and logs validate **operational** health; they do **not** benchmark **detection** on local MRI.

### Generalization

- The paper is explicit about **scanner harmonization** and the **~20-scans** guidance for ComBat-style steps on new data; **without** harmonization, **specificity** in particular can move (as summarized in `meld.md`).  
- **Lesion types** and **multifocal** FCD are **limitations** in the paper; the model is **not** scoped to all epilepsy etiologies.  
- **Regulatory:** framed as **research** adjunct; local governance applies for any **clinical** use of outputs.

### Comparison to existing methods

- The natural baseline is **MELD MLP** (patch, lower PPV in the same cohort design); other competitors are classical radiology and **assorted** prior ML detours with **higher** false-positive loads. **Builder takeaway:** the paper’s “product” differentiator is **actionable** outputs (**PPV** + **cluster** behavior), not only **AUC**-style abstractions.

---

## Clinical relevance, interpretability, and integration

### Clinical relevance

- **High** for **epilepsy surgery / radiology research** groups needing **FCD-first** screening: outputs include **location**, **cluster** summaries, and **confidence** for triage.  
- **Surgical** or **treatment** decisions remain **expert**; the tool is an **adjunct** consistent with the publication.

### Interpretability and trust

- **Strength:** **Integrated gradients** (see `saliency.md` and `evaluation` paths in `meld_graph`) tie **which features** pushed the **lesion** class for a **cluster**—aligned with the paper’s figure narrative.  
- **Trust limits:** Saliency explains **this model**, not **histology**; **baseline** and **architecture** sensitivity apply as for any attribution method.  
- **Practical trust:** The **low-confidence MRI-negative** examples in the paper are a useful **mental model**—the UI/report path should **not** over-sell a **7%** score as a **binary** “lesion present.”

### Integration potential

- **Research:** **BIDS**-aware inputs, **NIfTI** in native T1, **PDF** for humans—fits a **DICOM → BIDS / NIfTI** upstream and **MELD**-style **downstream** analysis.  
- **Clinical PACS** routing, **identity**, and **reporting** are **out of scope** of this repository—would require **institutional** wrappers.  
- **This repo’s** value is **Apptainer + SLURM + path hygiene**, reducing **HPC** integration risk vs ad hoc notebook runs.

---

## Limitations and failure modes

- **Preprocessing chain:** FreeSurfer/FastSurfer **failures**, motion, or **contrast** issues propagate; there is no substitute for **QC**.  
- **Compute and storage:** **NFS latency** and shared **home** can hurt **I/O**-heavy steps—local **SSD** or **scratch** for working dirs is often wiser (same class of issue as in `LeGUI_br.md` for **SPM** steps).  
- **Harmonization** codes and **site** metadata must be **honest**; wrong **`-harmo_code`** or **missing** FLAIR when expected can shift behavior.  
- **Container** + **model version** lock-in: the wrapper pins expectations to a **specific** `meld_graph_*.sif` lineage; drifting from upstream’s **recommended** image without testing is a **hard** failure mode.  
- **Licensing** (FreeSurfer, MELD) is **mandatory** for *legal* not just *technical* runs.

---

## Builder insight

MELD Graph is **strong on open, interpretable, multicenter-anchored** evidence for a **graph** alternative to **patch** FCD detection, and the paper is unusually clear about **PPV** and **off-target clusters** as **usability** metrics. The **builder gap** for a new site is **not** “get the paper PDF” but **stand up a reproducible stack**: **Apptainer image + licenses + harmonization strategy + BIDS/cohort layout + SLURM** capacity—and budget **QC** time and **calibrated** reading of **confidence** and **saliency**.

**Potential extensions (system-level)**

- **CI** on a small fixture: `meld-docker check` (and optionally a **smoke** path) on a **pinned** test host.  
- **Documented** “golden” **one-subject** BIDS **snippet** in-repo (synthetic or public) for **onboarding** without sharing MELD-private data.  
- **Tie-out** between **`meld_config.sh`** and **`meld-docker`** version pins so operators see **one** version matrix.  
- **Runbooks** for **multi-cohort** `input/` **sync** and **SLURM** array patterns (this repo’s cohort commands point in that direction already).

---

## References (selected)

- Ripart et al. 2025 *JAMA Neurol.* — MELD Graph methods and results (DOI above).  
- MELDProject/meld_graph — public code: https://github.com/MELDProject/meld_graph  
- Upstream **Singularity/Apptainer** install story: https://meld-graph.readthedocs.io/en/latest/install_singularity.html  
- `meld.md` — paper summary; `meld_tech.md` / `saliency.md` — local technical notes.  
- Builder review criteria — `build_reviewer.docx` (Inzira framework); `LeGUI_br.md` — parallel builder review in this folder.

---

*Last updated: 2026-04-23.*
