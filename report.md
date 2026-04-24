# Neuroimaging PDF reporting: MELD Graph design and a reusable pattern for other workflows

This document explains how **MELD Graph** builds its **clinical-style PDF reports**, which parts are **portable** to other pipelines (task fMRI, ASL, diffusion, segmentation, etc.), and how to implement a **workflow-agnostic reporting layer** with a small **data contract** plus **adapters**.

---

## 1. Goals of a good reporting layer

| Goal | Meaning |
|------|--------|
| **Separation** | Analysis code writes **artifacts** (NIfTI, CSV, HDF5, figures); reporting **only reads** them and writes **PDF/PNG**. |
| **Reproducibility** | Every report ends with **versions** (software, model, container, harmonisation). |
| **Interpretability** | Each “finding” (cluster, ROI, contrast) gets **metrics + optional explanation** (saliency, effect size, tract statistics). |
| **Safety** | Fixed **disclaimer** and **research-use** language appropriate to your governance. |

MELD follows this pattern: prediction steps run first; **`generate_prediction_report`** is invoked only after native-space maps exist.

---

## 2. How MELD Graph does it today (reference implementation)

### 2.1 Entry point in the new-patient pipeline

After NIfTIs are created, the pipeline calls **`generate_prediction_report`** (unless `--no_report`):

```159:170:meld_graph/scripts/new_patient_pipeline/run_script_prediction.py
        if not no_report:
            # Create individual reports of each identified cluster
            print(get_m(f'Create pdf report', subject_ids, 'STEP 4'))
            generate_prediction_report(
                subject_ids = subject_ids,
                data_dir = data_dir,
                prediction_path=classifier_output_dir,
                experiment_path=experiment_path, 
                output_dir = predictions_output_dir,
                harmo_code = harmo_code,
                hdf5_file_root = DEFAULT_HDF5_FILE_ROOT
            )
```

**Adoption idea:** your workflow’s `main` or `run_study.py` should call a single **`build_report()`** in the same way, after you know **artifact paths** are valid.

### 2.2 Core module

All MELD report logic lives in:

- **`meld_graph/scripts/manage_results/plot_prediction_report.py`**

It combines:

- **`fpdf2`** — subclass `PDF(FPDF)` for borders, header/footer, MELD logo, colored info/disclaimer boxes.
- **`matplotlib` / `matplotlib_surface_plotting`** — inflated surface views.
- **`nilearn.plotting`** — T1 **cut planes** and **contours** for cluster masks in native space.
- **`pandas`** — **`info_clusters_<subject>.csv`** per subject.
- **`Evaluator` / HDF5** — loads **`cluster_thresholded`**, feature matrices, and **saliency** tensors for each cluster.

### 2.3 Data flow inside `generate_prediction_report` (simplified)

```
HDF5 (result, cluster_thresholded, input_features, saliencies_*, mask_salient_*)
    → get_subj_data()  →  list of cluster IDs per hemisphere, confidences, saliencies
    → for each (hemi, cluster): matplotlib figures → PNGs on disk
    → FPDF: page 1 overview + N cluster pages + final provenance page
    → MELD_report_<subject>.pdf, info_clusters_<subject>.csv, inflatbrain_*.png
```

**Cluster detection for reporting** is driven by **non-zero labels** in **`cluster_thresholded`** (per-hemisphere arrays); background `0.0` is removed:

```250:265:meld_graph/scripts/manage_results/plot_prediction_report.py
    for hemi in ['left','right']:
        list_clust[hemi] = set(predictions[hemi])
        list_clust[hemi].remove(0.0)
        keys = [f'saliencies_{cl}' for cl in list_clust[hemi]] + [f'mask_salient_{cl}' for cl in list_clust[hemi]]
        saliencies.update(eva.load_data_from_file(subject_id, 
                                            keys=keys, 
                                            split_hemis=True))
    
        for cl in list_clust[hemi]:
            mask_salient = saliencies[f'mask_salient_{cl}'][hemi].astype(bool)
            confidence_cl_salient = data_dictionary['result'][hemi][mask_salient].max()
            confidences[f'confidence_{cl}'] =  confidence_cl_salient
```

If there are **no** clusters, the inner loop that fills the CSV and cluster PNGs does **not** add rows; the PDF can still be built with **empty cluster pages** (overview + software page only) — that matches “negative” MELD runs.

### 2.4 PDF page structure (MELD-specific content, generic layout)

The assembly order is **fixed**: **overview → (optional) one page per finding → software page**. Ordering of clusters is by **confidence** (descending):

```686:724:meld_graph/scripts/manage_results/plot_prediction_report.py
        #### order display in function of confidence
        clusters = np.array(range(1, n_clusters + 1))
        confidences_order = np.array(np.argsort([confidences[f'confidence_{float(cl)}'] for cl in clusters]))
        clusters = clusters[confidences_order[::-1]]
        #### Create page for each cluster with MRI view and saliencies
        for i, cluster in enumerate(clusters):
            # add page
            pdf.add_page()
            # add line contours
            pdf.lines()
            # add header
            pdf.custom_header(logo, txt1="MRI view & saliencies", txt2=f"{return_ith(i+1)} cluster")
            # add image
            im_mri = glob.glob(os.path.join(output_dir_sub, f"mri_{subject.subject_id}_*_c{cluster}.png"))[0]
            #add segmentation figure left
            pdf.image(im_mri, 5, 50, link='', type='', w=190, h=297/3)
            # add image
            im_sal = glob.glob(os.path.join(output_dir_sub, f"saliency_{subject.subject_id}_*_c{cluster}.png"))[0]
            pdf.image(im_sal, 5, 150, link='', type='', w=190, h=297/3)
            # add footer date
            pdf.custom_footer(footer_txt)
        
        #### create last page with info for reproducibility
        # add page
        pdf.add_page()
        # add line contours
        pdf.lines()
        # add header
        pdf.custom_header(logo, txt1="MELD report", txt2=f"Patient ID: {subject.subject_id}")
        # add info box
        pdf.info_box(text_info_3)
        # add footer date
        pdf.custom_footer(footer_txt)
        
        # save pdf
        file_path = os.path.join(output_dir_sub, f"MELD_report_{subject.subject_id}.pdf")
        pdf.output(file_path, "F")
```

**Provenance text** (MELD version, model name, FreeSurfer/FastSurfer, harmonisation) is built in **`get_info_soft()`** in the same file.

---

## 3. What transfers to other neuroimaging workflows

### 3.1 Portable (reuse as design)

- **“Artifact-first” reporting** — no re-inference inside the report step.
- **fpdf2** (or **WeasyPrint**, **LaTeX**, **reportlab**) for **multi-page** PDFs with a **branded template**.
- **A final “Methods / versions” page** (container digest, `git` SHA, BIDS, sequence params).
- **Per-finding section** (cluster, ROI, tract, network, contrast) with a **table or figure strip**.
- **Sidecar CSV/JSON** next to the PDF for **machine-readable** audit (QC, PACS research export).

### 3.2 MELD-specific (replace when changing modality)

- **Cortical mesh + fsaverage_sym** and **MELD HDF5** keys.
- **Integrated-gradients saliency** and **feature** lists tied to the **MELD GNN** (`plot_prediction_report.py` feature name lists and three harmonisation **prefixes**).
- **NIfTI value convention** (cluster id vs `cluster*100` for salient voxels) used for contours — see MRI plotting section in the same file.

**Rule of thumb:** keep **layout code** and **neuroanatomy plotting** in separate Python modules. MELD bundles both in one large function; a multi-workflow lab should **split** them.

---

## 4. A workflow-agnostic data contract (recommended)

Define a **single JSON (or Pydantic) object** that your report renderer understands. The **analysis code** (or a small `export_for_report.py`) produces this; **MELD** would be one **adapter** that fills it from HDF5.

### 4.1 Example schema: `ReportBundle` (illustrative)

```json
{
  "schema_version": "1.0",
  "report_id": "uuid-or-hash",
  "subject_id": "sub-01",
  "workflow": { "name": "meld_graph", "version": "2.2.4" },
  "input": { "bids_data_root": "/data/input" },
  "provenance": {
    "container_image": "meldproject/meld_graph:v2.2.4",
    "model_id": "23-10-30_LVHZ_dcp",
    "freesurfer": "7.2.0",
    "segmentation": "freesurfer",
    "harmonisation": { "code": "noHarmo", "applied": false }
  },
  "summary_pages": [
    { "type": "text+image", "title": "Overview", "body": "…", "figures": [ { "path": "inflatbrain.png", "caption": "Inflated surface" } ] }
  ],
  "findings": [
    {
      "finding_id": "f1",
      "order": 1,
      "label": "Left hemisphere — candidate 1",
      "metrics": { "confidence_pct": 72.3, "volume_mm3": null, "location_dk": "precentral" },
      "figures": [
        { "path": "mri_lh_c1.png", "role": "anat_mosaic" },
        { "path": "saliency_lh_c1.png", "role": "explanation" }
      ],
      "table_csv": { "path": "feature_zscores_f1.csv" }
    }
  ],
  "disclaimer": "Research use only. Not for clinical decisions.",
  "output": { "pdf": "MELD_report_sub-01.pdf", "csv": "info_clusters_sub-01.csv" }
}
```

**Adoption:** a **task-fMRI** workflow would fill **`findings`** with **contrasts/ROIs**; **diffusion** with **tract metrics**; **lesion** segmentation with **Dice + volume** — same renderer, different adapter.

### 4.2 Minimal internal Python types (stubs you can copy)

```python
# report_contract.py — workflow-agnostic; no MELD imports
from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, List, Optional, Dict

@dataclass
class ReportFigure:
    path: Path
    role: str  # e.g. "overview_surface", "anat_mosaic", "effect_plot"
    caption: str = ""

@dataclass
class ReportFinding:
    finding_id: str
    order: int
    title: str
    metrics: Dict[str, Any] = field(default_factory=dict)
    figures: List[ReportFigure] = field(default_factory=list)

@dataclass
class Provenance:
    software: Dict[str, str]  # e.g. {"meld": "2.2.4", "fsl": "6.0.0"}
    model: Optional[str] = None
    extra_notes: str = ""

@dataclass
class ReportBundle:
    subject_id: str
    workflow_name: str
    provenance: Provenance
    summary_figures: List[ReportFigure]
    findings: List[ReportFinding]
    disclaimer: str
```

### 4.3 Renderer interface (stubs)

```python
# pdf_renderer.py — depends only on fpdf2 (or your PDF backend)
from pathlib import Path
from report_contract import ReportBundle, ReportFigure

def render_meld_style_pdf(out_pdf: Path, bundle: ReportBundle, logo: Path) -> None:
    """MELD’s PDF subclass can be refactored into this function."""
    from fpdf import FPDF
    # 1) Subclass FPDF (borders, header, footer) — see plot_prediction_report.PDF
    # 2) Add summary page(s) from bundle.summary_figures
    # 3) for f in sorted(bundle.findings, key=lambda x: x.order): add one page
    # 4) add provenance page from bundle.provenance
    # 5) pdf.output(out_pdf)
    raise NotImplementedError
```

**Adoption path:** copy **`PDF(FPDF)`** from `plot_prediction_report.py` into `pdf_base.py` (drop MELD-specific strings from `__init__`), then implement **`render_meld_style_pdf`** to take **`ReportBundle`** instead of MELD globals.

---

## 5. MELD adapter: mapping current outputs → `ReportBundle` (sketch)

This is **not** in the repository today; it shows how to **wrap** the existing MELD code without rewriting physics.

```python
# meld_adapter.py — uses existing loaders + your new contract
def meld_hdf5_to_report_bundle(
    subject_id: str,
    hdf5_dir: Path,
    reports_dir: Path,
) -> ReportBundle:
    # Reuse: Evaluator, get_subj_data, or read already-written PNG/CSV
    # Build ReportFinding for each cluster with paths to
    #   mri_{subject}_*_c{k}.png, saliency_{subject}_*_c{k}.png
    # Provenance: get_info_soft() text split into key/value or stored as a blob page
    ...
```

**Practical first step** for adoption: do **not** deserialize HDF5 twice — run existing **`generate_prediction_report`** as-is, then add a second script **`bundle_from_meld_artifacts.py`** that **reads only PNG + CSV + log** to emit **`report_bundle.json`** for archival or a second **generic** PDF.

---

## 6. Checklist: adopting the pattern for a new pipeline

1. **List outputs** (NIfTI, CSV, images, trk, cifti, h5). Pick what the clinician or analyst must see in **one PDF**.
2. **Fix a version block** (pipeline version, `Docker` image digest, `git` SHA, key CLI flags).
3. **One finding = one ID**; define **max pages** and **order** (e.g. by **effect size** or **p**).
4. **Separate** “figure building” and “PDF layout” in **two modules** (MELD mixes them; splitting eases tests).
5. **Validate** the bundle before render (Pydantic / JSON schema).
6. **Unit test** the renderer on a **fixture ReportBundle** (no real MRI) — `fpdf2` is fast in CI.
7. **Disclaimers** and **governance** text reviewed by your institution (MELD’s text is MELD-specific).

---

## 7. File map (this repository)

| Purpose | File |
|--------|------|
| Report generation | `meld_graph/scripts/manage_results/plot_prediction_report.py` |
| FPDF layout subclass | `class PDF(FPDF)` at top of `plot_prediction_report.py` |
| Provenance text | `get_info_soft()` in `plot_prediction_report.py` |
| Called from pipeline | `meld_graph/scripts/new_patient_pipeline/run_script_prediction.py` |
| CLI to skip report | `meld_graph/scripts/new_patient_pipeline/new_pt_pipeline.py` (`--no_report`) |
| Saliency theory + code cross-links | `reference_papers/saliency.md` (if present in your tree) |

---

## 8. Limitations and extensions

- **fpdf2** is simple but not ideal for **very long** dynamic tables; for those, **HTML → PDF** (WeasyPrint) or **LaTeX** may be better.
- **Language / accessibility:** consider HTML reports with **alt text** for figures for broader deployment.
- **BIDS-derivatives:** store **`report.json`** and PDF under `derivatives/<pipeline>/` in your own convention.

---

## 9. Summary

- **MELD’s** reporting is a **mature example** of: **models → standard artifacts → matplotlib/nilearn figures → FPDF → PDF + CSV + PNG**.
- **Adoption for all workflows** means **extracting** the **template + contract + renderer** and **replacing** MELD-only steps (surface HDF5, saliency, DK atlas) with **adapters** that fill the same **ReportBundle**.
- Start small: **refactor the FPDF class** to **configuration-driven** strings and **pluggable** page loops; add **`ReportBundle` JSON** next to the PDF for any new workflow.

---

*Document version: 1.0. Generated for the Meld_Graph working tree; extend with your org’s SOPs and legal review of disclaimers.*
