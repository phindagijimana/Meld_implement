# Builder Review — MELD Graph (Ripart et al. 2025) + this workspace

**Paper:** Ripart M, et al. *Detection of Epileptogenic Focal Cortical Dysplasia Using Graph Neural Networks: A MELD Study.* **JAMA Neurol.** 2025;82(4):397-406. https://doi.org/10.1001/jamaneurol.2024.5406  

**Scope:** JAMA *Multicenter Epileptogenic Focal Cortical Dysplasia* study vs this repo’s **deployment** (Inzira-style: `LeGUI_br.md`, `build_reviewer.docx`). Deeper paper/implementation detail: `meld.md`, `meld_tech.md`, `saliency.md`.

**This repo in one line:** **`./meld`** and **`meld_config.sh`**; **`meld_graph/`** with `new_patient_pipeline/`; **`docker_version/meld-docker`** (Apptainer, e.g. `meld_graph_v2.2.4.sif`, `MELD_DEPLOY_ROOT` / `production.env`, SLURM/cohort).

---

## Context

- **MELD Graph:** surface GNN on **FreeSurfer-style features** (~34 channels × full hemisphere), **clustered** predictions, **NIfTI** + **PDF** (location, size, **confidence**, **integrated-gradients** saliency). Framed as **adjunct** radiology, not a solo diagnosis. Main paper story: **higher PPV** and **fewer spurious clusters** than **MELD MLP**; multicenter + **independent** test sites.  
- **We did not retrain the GNN;** we run **Apptainer + paths + SLURM** and document **interpretability** (saliency) against upstream code.

---

## Can it run? (usability, reproducibility)

| | |
|--|--|
| **Published** | Open **MELDProject/meld_graph** + weights; T1 + optional FLAIR → **FreeSurfer or FastSurfer** → features → model → report. |
| **Strengths here** | **`meld-docker`**: `check`, `run`/`batch`, `validate`, `logs`, `slurm`, cohort flows; flags passed through to **`new_pt_pipeline.py`** (`-harmo_code`, `--fastsurfer`, skip steps, no-report, etc.); **portable** `MELD_DEPLOY_ROOT` / `MELD_DATA_DIR` for NFS split layouts. |
| **Friction** | **FreeSurfer + MELD** licenses, **large** image/models, **long** per-subject runs. **BIDS**/cohort **`input/`** setup and **harmonization** (paper: ~**20** scans/site for ComBat; else **non-harmonized** option with documented tradeoffs) are **data** work, not fixed by the shell. |
| **Reproducibility** | Paper metrics assume **MELD-style** cohorts; **full** numeric replication needs data **not** all public. This tree gives **runnable entrypoints**, not a replay of the JAMA tables. Local **PPV/sensitivity** can differ with **site + harmonization** even with the same weights. **Unit tests** in `meld_graph` are **structural**; **smoke** tests (`meld_docker_smoke_test.sh`–class) are **image + license + sanity**, not imaging benchmarks. |

---

## Does it work off-paper? (performance, generalization, baselines)

- Treat JAMA numbers as a **prior** for **MELD-compatible** preprocessing; new hospitals should care about **QC, harmonization, and surfaces**, not only the checkpoint.  
- **Harmonization off** hits **specificity** especially; **multifocal** FCD and “all comers” epilepsy are **out of scope** in the paper. **Research** adjunct, not a cleared **clinical** product—governance is local.  
- **vs MELD MLP:** the differentiator the paper sells is **actionable** output (**PPV** / **off-mask clusters**), not a single summary AUC.  
- **This build:** `check` and **logs** = **ops** health, **not** local detection benchmarking.

---

## Can it be used? (clinical fit, trust, integration)

- **Useful** for **FCD-oriented** **research** triage: location, clusters, **confidence**; **experts** still decide treatment.  
- **Saliency** (`saliency.md`, Captum/IG in `meld_graph`) explains **model** drivers, not **causal** histology; low-confidence **MRI-negative** cases in the paper are a good reminder **not** to treat weak scores as binary positives.  
- **Fits** **BIDS → NIfTI** research stacks; **PACS/identity/reporting** need **institutional** layers. Value here: **container + SLURM + conventions**, not a hospital integration product.

---

## Limitations and builder insight

**Failure modes:** preprocessing **QC**; **NFS** I/O (prefer **scratch**/SSD for heavy work); wrong **`-harmo_code`** or **FLAIR** expectations; **version drift** (pinned **`meld_graph_*.sif`** vs untested images); **license** requirements.

**Bottom line:** The paper and open weights are **strong** on **PPV** and **interpretability** in a **multicenter** frame. The **builder** job is **stack + data**: Apptainer, licenses, **harmonization** plan, BIDS/cohort layout, **SLURM** capacity, and **QC**—not rereading the abstract alone.  

**Extensions worth considering:** CI on `meld-docker check` (+ optional smoke) on a **pinned** node; a **public tiny** BIDS fixture for onboarding; one **version matrix** across `meld_config.sh` and `meld-docker` pins.

---

## References

- Ripart et al. 2025 (DOI above). **Code:** https://github.com/MELDProject/meld_graph · **Apptainer:** https://meld-graph.readthedocs.io/en/latest/install_singularity.html  
- `meld.md`, `meld_tech.md`, `saliency.md`, `LeGUI_br.md`, `build_reviewer.docx`

*Last updated: 2026-04-23.*
