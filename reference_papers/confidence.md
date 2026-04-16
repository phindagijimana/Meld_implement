# MELD Graph — confidence score (what it is, what affects it, how to read it)

This note explains the **per-cluster confidence** reported in **`info_clusters_<subject>.csv`** and in the **PDF report** (“Confidence score = …%”). It is written for clinicians and analysts using the public MELD Graph pipeline and matches how the **reference implementation** builds the report (see code pointers below).

---

## 1. What the confidence score is *not*

- It is **not** a generic **image quality** score (not SNR, motion grade, or “scan quality”).
- It is **not** a calibrated probability that this patient has FCD, stated as a single number for the whole brain.
- It is **not** a replacement for clinical judgment, EEG, or expert MRI review.

It is a **model-internal summary** of how strongly the **surface-based detector** supports the **lesional** label on the vertices that define a given **cluster**.

---

## 2. What the network actually outputs

After inference, MELD stores (among other things) a per-vertex field often referred to as **`result`**: a **lesion score** in \([0, 1]\) (conceptually aligned with “how lesional” each surface vertex looks to the model). Clusters are groups of connected vertices above a threshold; **saliency** and **salient masks** highlight vertices the model relied on most for that cluster.

For **deeper statistical work** (calibration plots, expected calibration error), the project also uses **MC dropout** and **softmax**-based analyses in notebooks. The **clinical report’s** confidence number is a **simpler, cluster-level summary** of the same underlying `result` field, not a separate “quality meter.”

---

## 3. How the report confidence is computed (step by step)

Implementation: `meld_graph/scripts/manage_results/plot_prediction_report.py`, function `get_subj_data`, and the block that builds `info_clusters`.

1. **Load** per-hemisphere maps: `result` (vertex-wise lesion scores), `cluster_thresholded` (cluster labels), and saliency-derived keys `mask_salient_<cluster>` for each cluster.
2. For each cluster \(c\) and hemisphere, take vertices where **`mask_salient_c`** is true (the **salient** subset of that cluster).
3. Compute  
   **`confidence_raw`** = **maximum** of `result` over those salient vertices.  
   (So the score emphasizes the **strongest** lesional signal within the model’s “important” vertices for that cluster.)
4. The value written to the CSV and report is  
   **`confidence`** = **`round(confidence_raw × 100, 2)`**  
   i.e. a **percentage on a 0–100 scale**.

So if you see **19.81**, that means **`confidence_raw ≈ 0.198`** before scaling.

---

## 4. Relation to the JAMA Neurology paper

The peer-reviewed paper (Ripart et al., *JAMA Neurol.* 2025) presents MELD Graph as an **interpretable** tool and discusses **confidence** together with **location, size, and morphology**, and reports **calibration** (e.g. expected calibration error) so readers know predicted confidences are meant to be **meaningful across bins of similar scores**, not arbitrary decoration.

That **cohort-level** calibration does **not** automatically make every **single-subject** percentage a literal “% chance of FCD.” Use the score as **relative model certainty for that cluster**, in light of the full report and clinical context.

See also: `reference_papers/meld.md` (methods summary, metrics, interpretability).

---

## 5. What can affect the confidence score?

Factors that can **raise, lower, or distort** the reported percentage include:

### 5.1 Data and modalities

- **T1-only vs T1+FLAIR:** The pipeline extracts **FLAIR-related** surface features when FLAIR exists. **T1-only** runs give the model **fewer channels**; clusters may still appear but scores often reflect **weaker or noisier** evidence compared with full feature stacks.
- **Acquisition parameters** (resolution, contrast, vendor sequence): They change the derived morphometric and intensity-related maps. **Harmonisation** (when used) tries to reduce scanner/site shift; **no harmonisation** can leave features farther from the training distribution.

### 5.2 Segmentation and surfaces

- **FreeSurfer / FastSurfer quality:** Errors in pial/white surfaces, skull strip, or topology fixes propagate into **thickness, curvature, sulcal depth, gray–white contrast**, etc. Noisy or biased features can **suppress** lesion scores or create **spurious** patches.
- **Long or failed recon:** If surfaces are wrong, **confidence is not trustworthy** even if a number is printed.

### 5.3 Model and thresholds

- **Cluster definition and saliency mask:** Confidence uses only vertices inside **`mask_salient_<cluster>`**. If saliency is tight or fragmented, the **max** over a small set can be **volatile** (high or low).
- **Threshold logic for “high vs low confidence cluster”:** The report text can label a case as having a **high confidence cluster** vs presenting a **low confidence** cluster instead, depending on how the predicted max compares to configured thresholds (see `threshold_text` in the same script). That is **separate** from the numeric column but affects how the PDF frames the finding.

### 5.4 Truth and biology (not observed by the model)

- **Real lesion vs no lesion:** Low confidence may mean “no strong lesional pattern.” High confidence still requires **clinical correlation** (paper reports PPV at cohort level, not 100% per cluster).
- **Atypical or MRI-subtle FCD:** The model may **under-call** or assign **moderate** scores.

---

## 6. How to interpret the number in practice

| Observation | Reasonable reading |
|-------------|---------------------|
| **Higher % (e.g. toward the upper part of the 0–100 scale)** | The model’s **peak** lesional score on **salient** vertices in that cluster is **stronger**. Prioritize that cluster in the PDF (saliency bars, anatomy, Z-scores). |
| **Lower % (e.g. under ~20–30)** | The model is **less certain** about that cluster. It is still a **candidate** region to discuss, not a dismissal of epilepsy workup—especially on **T1-only** or borderline segmentation. |
| **Several clusters** | Compare **relative** confidences; the report often **sorts** clusters by confidence. |
| **T1-only** | Interpret conservatively: missing FLAIR features removes evidence the model was trained to use when available. |

**Practical workflow:** Read the **PDF** (inflated views, slice overlays, feature panels), check **location** and **size** in `info_clusters_*.csv`, and use confidence as **one axis** of evidence together with **QC of recon** and **clinical data**.

---

## 7. Code references (for maintainers)

- Report confidence aggregation: `meld_graph/scripts/manage_results/plot_prediction_report.py` — `get_subj_data` (max of `result` on `mask_salient_*`), and the `info_clusters` block (`× 100`).
- Broader confidence / calibration utilities: `meld_graph/meld_graph/confidence.py`, `meld_graph/notebooks/plot_confidence_calibration.ipynb`.

---

## 8. Short takeaway

**Confidence %** = **100 × (max vertex-wise lesional score on salient vertices in that cluster)**. It reflects **model certainty for that surface patch**, influenced indirectly by **scan quality, recon quality, available modalities, harmonisation, and biology**—but it is **not** itself an image-quality metric. Use it as a **graded hint** alongside the full MELD report and standard clinical judgment.
