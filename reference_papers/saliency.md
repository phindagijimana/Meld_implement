# MELD Graph — saliency (paper, theory, computation, interpretation)

This document explains **saliency** in **MELD Graph** as described in the **JAMA Neurology** paper (Ripart et al., 2025), the **machine-learning theory** (integrated gradients), how it is **computed in code**, and how to **read** the PDF / PNG outputs. For the companion **confidence** column in reports, see `confidence.md`.

---

## 1. What the paper says

### 1.1 Role of interpretability

The study presents MELD Graph not only as a detector but as an **interpretable** adjunct: outputs include **location**, **size**, **morphology/feature profiles**, **confidence**, and **which inputs drove the prediction**. Saliency is the technical tool used for that last part.

From the structured summary in `meld.md`:

- **Interpretability:** **integrated gradients** saliency for **feature importance**; together with confidence and calibration (ECE) so scores are not arbitrary.

### 1.2 What appears in the clinical-style report

The paper’s description of end-to-end output includes:

- Lesion **location** on the cortical surface and on native MRI  
- **Cluster size** and **model confidence**  
- **Feature profiles** (e.g. z-scored means in the most relevant vertices)  
- **Saliency maps (integrated gradients)** — **which features** most strongly **influenced** the model toward a lesional prediction for that cluster  

**Figure 3** (per `meld.md`) contrasts high- vs low-confidence cases with **surface views**, **T1/FLAIR** sections, and **feature bars colored by saliency**.

### 1.3 Worked examples (qualitative)

The paper illustrates how saliency aligns with known FCD phenomenology, for example:

- **High-confidence MRI-positive case:** strong saliency linked to **blurred gray–white boundary**, **thick cortex**, and **abnormal FLAIR** in gray matter.  
- **MRI-negative cases:** lower confidences (e.g. **7%–45%**) with patterns still highlighting subtle cortical abnormalities worth expert review.

Larger **detection / IoU** analyses in the paper also note that **higher confidence tends to correlate with better mask overlap** (e.g. correlation reported in `meld.md` §7.5), which indirectly links **saliency-backed** explanations to **stronger** predictions—not a guarantee for every subject.

### 1.4 Typical FCD feature patterns (context for reading bars)

The paper summarizes patterns often seen in **true** FCD lesions on the surface feature stack, e.g. **deep sulci**, **increased intrinsic curvature**, **increased thickness**, **decreased gray–white contrast**, **GM FLAIR** changes, **WM FLAIR** hyperintensity (especially **FCD IIb**). Saliency helps show **which of those channels** the network leaned on **for this patient and this cluster**—not every feature will light up in every case.

---

## 2. Theory: integrated gradients (IG)

### 2.1 What problem IG solves

Deep models map high-dimensional inputs (here: **many neuroimaging-derived features × many cortical vertices**) to outputs (here: **lesion vs not** per vertex). Clinicians need to know **which parts of the input** mattered, not only **where** the network painted a lesion.

**Saliency** in this project is implemented with **Integrated Gradients** (IG), a standard **feature-attribution** method from the Captum library (see `meld_graph/meld_graph/evaluation.py`). IG attributes the model’s output to **each input dimension** (here, roughly **per vertex × per feature channel**) by integrating gradients along a path from a **baseline** input to the **actual** input.

Intuitively:

- If increasing a particular **feature value at a vertex** (along the path from baseline to observed) **pushes** the model toward **lesion**, that dimension receives **positive** attribution.  
- If it **pushes against** lesion, attribution is **negative** or small.

IG is chosen because it satisfies useful **axioms** (e.g. sensitivity to relevant inputs, implementation invariance) compared with naive gradient×input tricks; the canonical reference is **Sundararajan et al., “Axiomatic Attribution for Deep Networks”** (ICML 2017).

### 2.2 What IG is *not*

- It is **not** a causal proof that a feature **caused** epilepsy or histology.  
- It is **not** independent of the **chosen baseline** and **model architecture**; attributions explain **this model’s** reasoning, not ground-truth biology by itself.  
- It is **not** a substitute for visual MRI quality control or expert read.

---

## 3. How saliency is obtained in MELD Graph (implementation)

All paths below refer to the **public `meld_graph`** code under this repository.

### 3.1 When saliency runs

The new-patient pipeline can compute saliency after **prediction + clustering** (`run_script_prediction.py` calls `eva.calculate_saliency()` when `saliency=True`). The **PDF report** expects per-cluster HDF5 datasets such as `saliencies_<cluster>` and `mask_salient_<cluster>`.

### 3.2 Model output used for attribution

`PredictionForSaliency` (`meld_graph/meld_graph/models.py`) wraps the trained graph model:

- It converts **log-softmax** logits to **probabilities** via `exp(log_softmax)`.  
- For saliency, it **aggregates** predicted lesion probability **over vertices in the cluster mask** (mean over selected vertices).  
- The IG **target** is the **lesion class** (`target=1` in the Captum call).

So attributions answer: *“Which input features at which vertices most changed this **cluster-level lesion score**?”*

### 3.3 Integrated Gradients call

In `Evaluator.calculate_saliency` (`meld_graph/meld_graph/evaluation.py`):

- **Library:** `captum.attr.IntegratedGradients`.  
- **Forward:** `attribute(inputs, additional_forward_args=mask, target=1, n_steps=25, method='gausslegendre', internal_batch_size=100)`.  
- **Scope:** For each **hemisphere** and each **cluster id** (excluding background `0`), compute attributions on that hemisphere’s **input feature tensor**, with the **cluster mask** passed as `additional_forward_args` so the forward wrapper averages lesion probability **only inside the cluster**.

This yields a **saliency matrix** shaped like **vertices × features** (for cortex-masked vertices, then packed into full-brain storage per hemisphere).

### 3.4 “Salient vertices” (`mask_salient_<cluster>`)

Raw IG values exist at **every vertex in the cluster**. For reporting and **confidence** (see `confidence.md`), the code **subselects** vertices:

1. For each vertex in the cluster, take the **mean saliency across feature dimensions**.  
2. Set a threshold at the **80th percentile** of those means inside the cluster → keep roughly the **top 20%** most salient vertices.  
3. If that yields **fewer than 125** vertices, fall back to the **125** highest-mean-saliency vertices in the cluster.

These boolean maps are saved as **`mask_salient_<cluster>`** and are also encoded in NIfTI outputs (salient vertices may appear with **label `cluster × 100`** alongside the base cluster id in clustered prediction products—see `evaluation.py` where `pred_clust_salient` assigns `cl*100`).

### 3.5 Aggregated saliency in the PDF (`plot_prediction_report.py`)

For each cluster page, the report:

1. Loads **`saliencies_<cluster>`** and **`mask_salient_<cluster>`** per hemisphere.  
2. Optionally **rescales** saliency for display (`× NVERT/2` in the plotting script—display convention).  
3. Builds **horizontal bar charts** of **mean z-scored feature values** (with error bars) **only over salient vertices**, for three **feature families** in parallel:

   - **Harmonised** (hatch `\\`)  
   - **Normalised** (hatch `//`)  
   - **Asymmetry** (hatch `--`)

4. **Bar face color** is driven by **`m.to_rgba(saliency_data)`**: each bar’s **mean saliency** for that feature (within the salient mask) maps through a **green → white → magenta** colormap (`#276419` → `#FFFFFF` → `#8E0152`). **Brighter / more magenta** indicates **stronger** attribution for that feature in that group.

5. Saves **`saliency_<subject>_<hemi>_c<cluster>.png`** and embeds the logic in the **PDF report** text (see also the report’s own “Information” page describing saliency coloring).

Surface panels show the **cluster** plus **salient** vertices overlaid (combined mask for visualization).

---

## 4. How to interpret saliency in practice

### 4.1 Reading the feature bars

- **Direction of the bar (horizontal axis):** **Z-scored feature mean** in salient vertices (relative to the cohort preprocessing—harmonised / normalised / asymmetry pipelines as labeled). Values far from 0 mean “unusual” for that feature type.  
- **Color of the bar:** **How much the model relied on that feature channel** when scoring the cluster as lesional (IG attribution summarized per feature). **More intense magenta** → **greater influence** on the lesion score for that cluster.  
- **Three hatch styles:** same morphometric **concept** (e.g. thickness, sulcal depth) shown under **three preprocessing views**; saliency can differ across them because the network uses **all 34 input channels** as defined in the paper.

### 4.2 Reading surface / MRI panels

- **Cluster outline:** where the model **called** a lesion on the mesh / volume.  
- **Salient vertices:** where, **within** that cluster, IG says the **evidence** was **concentrated**. These are the vertices that drive the **confidence** summary (max `result` on salient mask) in `confidence.md`.

### 4.3 Clinical cautions

| Do | Don’t |
|----|--------|
| Use saliency to **hypothesize** which MRI-derived patterns the model used (thickness vs FLAIR vs asymmetry, etc.). | Treat saliency as **histology** or **surgical outcome**. |
| Combine with **visual MRI**, **EEG**, and **expert read**. | Ignore **bad segmentation**—wrong surfaces make both **prediction** and **attribution** unreliable. |
| Remember **T1-only** runs **omit FLAIR features**; saliency cannot highlight FLAIR if those inputs were never fed. | Assume **absence** of saliency on a feature **proves** that feature is normal on raw MRI—only that **this model** did not lean on that channel strongly here. |

### 4.4 Relation to confidence

**Confidence** (report %) summarizes **how strong** the **lesion probability** is on **salient** vertices. **Saliency** explains **which features** pushed that score. A cluster can have **moderate confidence** but **clear** saliency on **thickness and curvature**, or **high confidence** with saliency spread across **many** features—use both panels together.

---

## 5. File and code index

| Topic | Location |
|--------|-----------|
| IG + mask building | `meld_graph/meld_graph/evaluation.py` — `calculate_saliency` |
| Wrapper for IG target | `meld_graph/meld_graph/models.py` — `PredictionForSaliency` |
| PDF / PNG feature bars & colors | `meld_graph/scripts/manage_results/plot_prediction_report.py` |
| Optional CLI flag | `meld_graph/scripts/classifier/evaluate_single_model.py` — `--saliency` |
| Pipeline hook | `meld_graph/scripts/new_patient_pipeline/run_script_prediction.py` |
| Paper-aligned narrative | `reference_papers/meld.md` — interpretability, Figure 3, §7.5–7.6 |

---

## 6. One-paragraph takeaway

**Saliency in MELD Graph** is **integrated gradients attribution** over the **surface feature stack**, targeting the model’s **lesion score inside each predicted cluster**. It is **summarized per feature** and **per salient vertex subset** to build **interpretable PDFs** that show **which morphometric / intensity patterns** drove the call. It supports **clinical sense-making** alongside **location** and **confidence**, but it remains **model-dependent**, **non-causal**, and **only as trustworthy** as the underlying **MRI, segmentation, and modality set** (T1 vs T1+FLAIR).
