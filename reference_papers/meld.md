# MELD Graph — JAMA Neurology 2025 (detailed summary)

This document summarizes the peer-reviewed paper corresponding to the PDF in this folder:  
`jamaneurology_ripart_2025_oi_240097_1743609742.55929.pdf`.

**Full citation:** Ripart M, Spitzer H, Williams LZJ, et al; MELD FCD writing group. *Detection of Epileptogenic Focal Cortical Dysplasia Using Graph Neural Networks: A MELD Study.* **JAMA Neurol.** 2025;82(4):397-406.  
**DOI:** [10.1001/jamaneurol.2024.5406](https://doi.org/10.1001/jamaneurol.2024.5406)  
**Published online:** February 24, 2025. **Correction:** April 14, 2025 (typographical fixes in Methods/Results, Figure 2, Conflict of Interest Disclosures).  
**Corresponding author:** Mathilde Ripart, PhD — UCL Great Ormond Street Institute of Child Health (m.ripart@ucl.ac.uk).  
**Article type:** Original Investigation; section *AI in Neurology*. Reporting aligned with **STARD** (Standards for Reporting of Diagnostic Accuracy).

---

## 1. Clinical problem and why it matters (Importance / Introduction)

- **Focal cortical dysplasia (FCD)** is a major cause of **drug-resistant focal epilepsy** that can be **surgically remediable** (context cites ~65% postoperative seizure freedom in related literature).
- Many FCDs are **hard to see on MRI** and are treated as **“MRI-negative”** in routine practice, which delays diagnosis, surgical planning, and can worsen outcomes.
- Prior **machine-learning** detectors improved detection somewhat but often flag **many putative lesions**, so each candidate region has a **low positive predictive value (PPV)**—clinicians cannot efficiently trust or act on outputs.
- A key limitation of earlier MELD and related approaches: models often work on **small independent cortical patches** (~1 cm³), which **cannot integrate whole-hemisphere context** or **prioritize** among scattered abnormal patches.

**Core advance argued in the paper:** **MELD Graph** is a **graph neural network** (graph-based **nnU-Net**-style architecture) that processes **entire cortical hemispheres** with rich surface features, aiming for **better specificity**, **higher PPV**, and **interpretable** outputs for clinical translation.

---

## 2. Research questions (structured summary boxes in the paper)

- **Question:** Can diagnosis of epilepsy-causing FCDs be improved using state-of-the-art AI (graph neural networks)?
- **Findings (high level):** In 703 patients with FCD-related epilepsy, MELD Graph detected a large fraction of lesions in **MRI-negative** cases with **high PPV**; reports give **location, size, morphology, and confidence**.
- **Meaning:** Public, interpretable tool validated on a large multicenter cohort; intended as a **radiological adjunct** for earlier detection and surgical planning.

---

## 3. Objective

Evaluate **efficacy** and **interpretability** of **graph neural networks** for **automatic FCD detection** on MRI using the **Multicenter Epilepsy Lesion Detection (MELD)** resource.

---

## 4. Design, setting, and participants

- **Design:** Retrospective **multicenter diagnostic** study.
- **Data collection:** 2018–2022 from **23 international epilepsy surgery centers**; analysis in **2023**.
- **Cohort splits:**
  - **20 centers:** randomized **50:50** into **training** and **testing** (same split design as prior MELD MLP paper for direct comparison). **Every center** contributes patients to **both** training and test arms.
  - **3 additional centers:** held out as a **fully independent test** cohort (site-independent validation).
- **Participants:**
  - **1,185** participants collated initially.
  - **57 excluded** after quality control (**37** missing lesion masks, **13** outliers, **7** FreeSurfer failures).
  - **Final analyzed set:** **703 patients** with FCD-related epilepsy + **482 controls** (numbers stated in structured summary; flow details in supplement).
- **Ethics:** Local ethics at each site; retrospective anonymized clinical data; **no explicit consent** required per local approvals.
- **Inclusion — patients:** Radiological **or** histopathological diagnosis of **FCD**.
- **Inclusion — controls:** Scanned for research or headache; **no other neurological disease**; **normal MRI**.
- **Ground truth lesions:** **3D ROI masks** manually drawn on MRI; for **MRI-negative** cases, **postsurgical cavity** used to guide masking. Masks intersect cortical surfaces and are registered to a **bilaterally symmetric template** (see Methods).

---

## 5. Imaging and feature pipeline (Methods)

### 5.1 MRI modalities and processing

- **T1-weighted:** all participants.
- **FLAIR:** when available.
- **FreeSurfer** processing; **11 base feature maps** extracted, sampled at **6 intracortical and subcortical depths** (paper lists: cortical thickness, gray–white contrast, intrinsic curvature, sulcal depth, curvature, FLAIR intensity-related measures).

### 5.2 From raw features to model input

Surface features are turned into:

- Smoothed features  
- **Control-normalized** features  
- **Asymmetry** features  
- Plus **cortical thickness with curvature regressed out** (additional derived feature)

→ **34 input features per participant** at **163,842 cortical surface vertices** per hemisphere.

### 5.3 Scanner harmonization (domain shift)

- MRI features **vary by scanner**; hurts generalization.
- For **independent test cohort** data: **intersite harmonization** to training distribution via **distributed ComBat** (privacy-preserving harmonization).
- **Subsampling experiments:** minimum **~20 participants** on a scanner needed for **reliable** harmonization parameters (supplement).
- Performance on independent cohort reported **with and without** harmonization:
  - **Sensitivity** ~stable (**72% with** vs **70% without** harmonization).
  - **Specificity** drops sharply **without** harmonization (**56% → 39%**).
- For **new centers** that cannot provide ~20 scans: a **non-harmonized** model variant is provided with **documented** performance (supplement).

### 5.4 MELD Graph model architecture (conceptual)

- Prior MELD **MLP** used **small patches**; cannot use whole-brain context.
- **nnU-Net** is a strong **CNN** segmenter for **grid-like** 2D/3D images; cortex is not a regular grid.
- **MELD Graph:** **graph-based nnU-Net implementation** on the **cortical mesh**—processes **34 features × 163,842 vertices** per hemisphere, outputs **lesion segmentation** on the surface; **neighboring lesional vertices** grouped into **clusters** (candidate lesions).

**Baseline comparator:** prior multicenter model **MELD MLP** (Brain 2022 / “patch-based” MELD).

**Ablation / variant:** model trained **only** on **MRI-negative, histopathologically confirmed** FCD + controls → **PPV fell** from **72% to 58%** (supplement table)—argues **heterogeneous training** helps calibration/performance.

---

## 6. Evaluation metrics and definitions

- **Sensitivity, specificity, PPV** for **automatically identified lesions**.
- **Intersection over Union (IoU)** between predicted and manual mask (segmentation overlap metric; details in supplement).
- **Detection rule:** predicted cluster counts as detected if it **overlaps** the manual mask **or lies within 20 mm** of it.
- **False-positive clusters:** predictions **>2 cm** from any lesion mask (used to quantify spurious multi-foci).
- **Statistics:** bootstrapping CIs; **permutation** nulls; significance **P < .05** where noted.
- **Stratified analyses:** demographics, MRI-visible vs MRI-negative, histology subtype, seizure outcome, etc.
- **Interpretability:** **integrated gradients** saliency for feature importance; **confidence** scores; **expected calibration error (ECE)** summarized as **0.10** (0 = perfect calibration)—authors state scores are **reasonably well calibrated** (supplement figure).

---

## 7. Results (numbers to remember)

### 7.1 Main cohort performance — **test split** (20 centers; **n = 260 patients**, **193 controls** in test arm per table)

**MELD Graph vs MELD MLP** (median and 95% CI):

| Metric | MELD MLP | MELD Graph |
|--------|-----------|------------|
| Sensitivity (patients) | **67%** (61–73) | **70%** (64–75) |
| Specificity (controls) | **54%** (47–61) | **60%** (53–67) |
| **PPV** | **39%** (35–44) | **67%** (62–73) * |
| IoU (segmentation; n=160 / 78) | **0.23** | **0.30** * |

\* Statistically significant change vs MLP (**P < .05**).

**Structured abstract** also states for test dataset: **70% sensitivity, 60% specificity, 67% PPV** for MELD Graph vs **67% / 54% / 39%** for baseline—consistent with table.

### 7.2 **Independent** 3-center cohort (**n = 116 patients**, **101 controls**)

| Metric | MELD MLP | MELD Graph |
|--------|-----------|------------|
| Sensitivity | **77%** (69–84) | **72%** (61–78) |
| Specificity | **47%** (37–56) | **56%** (47–66) * |
| **PPV** | **46%** (40–53) | **76%** (61–79) * |
| IoU | **0.29** | **0.36** * |

### 7.3 False-positive burden (clinical usability)

On **test** data:

- **MELD Graph:** max **3** false-positive clusters in **patients** (median **0**; IQR 0–1); max **2** in **controls** (median 0).
- **MELD MLP:** max **12** in patients (median 1; IQR 0–2); max **8** in controls (median 0).

Same qualitative reduction on **independent** cohort (supplement table). This is the paper’s main story: **far fewer spurious foci → higher PPV → more actionable output**.

### 7.4 Clinically defined subgroups (test set; Table 2)

**Detection rates** (percent of lesions detected under study definition):

- **Age:** Adults **67.9%** (n=131) vs Pediatrics **71.3%** (n=129) — not flagged as significantly different in excerpt.
- **Sex:** Female **62.4%** vs Male **76.3%** — **male higher** (**P < .05**).
- **Ever reported MRI-negative:** **63.7%** (51/80) vs visible lesions **72.2%** (180) — Key Points round MRI-negative to **~64%** detection.
- **Postoperative seizure freedom:** **79.2%** if seizure-free vs **62.7%** if not (**P < .05**).
- **Histology:** FCD I **84.6%** (13 subjects); IIA **75.4%** (57); IIB **76.3%** (93); III **75.0%** (8); **Not available 56.2%** (89) (**P < .05** vs others—interpreted as mask / diagnosis uncertainty).
- **Histology-confirmed AND seizure-free:** **81.6%** (98) (**P < .05** highlight); **62.3%** when false (162).
- **Modality:** T1-only **67.3%** (150) vs T1+FLAIR **72.7%** (110) — FLAIR associated with higher detection in this breakdown.

**Lesion mask size:** MRI-negative lesions’ masks **median ~29% smaller** than MRI-visible (Mann-Whitney **P < .04**).

### 7.5 What features characterize detected FCD?

Qualitative / feature-analysis summary:

- Detected lesions often show **abnormally deep sulci**, **↑ intrinsic curvature**, **↑ cortical thickness**, **↓ gray–white contrast**, **↓ GM FLAIR**, **↑ WM FLAIR** (transmantle signal in **FCD IIB** emphasized).
- **IIA/IIB:** more pronounced folding + thickness abnormalities; **IIB** with distinctive **WM FLAIR** hyperintensity.
- **Type I / III:** subtler cortical abnormalities.
- **Missed lesions:** fewer / less pronounced abnormalities.
- **IoU vs confidence:** correlation **r = 0.55**, **P < .01** — higher confidence tends to align with better overlap.

### 7.6 Interpretable reports (clinical output)

End-to-end **pipeline**:

1. Accepts **preop T1** (+ optional **FLAIR**).  
2. Feature extraction + preprocessing.  
3. **MELD Graph** inference.  
4. Outputs: **NIfTI predictions in native T1 space** + **PDF report**.

**Report contents:**

- Lesion **location** on surface + native T1  
- **Cluster size** and **model confidence**  
- **Feature profiles** (e.g., z-scored mean feature values in most salient vertices)  
- **Saliency maps** (integrated gradients) — which features drove the prediction

**Worked examples in paper:**

- **Patient 1:** MRI-positive FCD, **93% confidence** — precuneus example; strong saliency for blurred GM–WM boundary, thick cortex, abnormal FLAIR in GM.  
- **Patients 2–4:** **MRI-negative** per **5 expert raters**; MELD Graph still flagged lesions with **7%–45% confidence** (low confidence as cue for subtle abnormality review).

---

## 8. Discussion (authors’ framing)

- **Whole-hemisphere context** vs patch models → **specificity**, **segmentation quality**, **better handling of subtle FCD type I** (highlighted), **calibrated confidence**.
- **Clinical translation:** fewer FP clusters means **less radiologist time** and more trust in AI adjuncts.
- **MRI-negative FCD** is common in surgical series; better localization may shorten pathways to surgery and improve developmental/cognitive outcomes (argument via cited epilepsy surgery literature—not a prospective outcome trial in this paper).
- **Harmonization** matters for **new scanners/sites**; requirement of **~20 scans** per site is a practical constraint; non-harmonized fallback documented.
- **Interpretability** is positioned as essential for radiology workflow integration; confidence thresholds can be tuned to user context (screening vs expert deep-dive).

---

## 9. Limitations (explicit in paper)

- **Hand-crafted surface features** limit discovery of wholly novel signal compared to raw-image end-to-end learning.
- **Future work:** multimodal integration (**PET, MEG, EEG**) may learn patterns not visible to neuroradiologists.
- **Not evaluated** in patients with **multiple FCDs**.

---

## 10. Conclusions (authors)

MELD Graph is presented as a **state-of-the-art**, **open**, **interpretable** tool for **FCD detection** with **large gains in PPV** vs the prior **MELD MLP**, backed by **multicenter + independent-site** validation, with outputs designed for **clinical workflows** (reports + confidence).

---

## 11. Code, models, and data sharing (as stated)

- **Code:** public GitHub — paper cites **MELDProject/meld_graph** (reference 23 in PDF).  
- **Template-space lesion masks:** **MELDProject/pool** (reference 24).  
- **Full surface FCD dataset:** available **by request** (not fully open).  
- **Data sharing statement:** **Supplement 2** of the journal article.

---

## 12. Funding and competing interests (brief)

- Multiple grants listed (NIH, Wellcome, Rosetrees, Epilepsy Research Institute, GOSH BRC, etc.) — **funders had no role** in study design, analysis, or publication decision.
- Several authors report grants/consulting/honoraria **outside** or **related** to the work; see paper’s **Conflict of Interest Disclosures** section for authoritative detail (updated in the **April 14, 2025** correction).

---

## 13. How this relates to your local PDF filename

The PDF in this directory is a **JAMA Neurology** reprint of the above article (filename suggests Oxford/JAMA download metadata). This `meld.md` is a **narrative extraction/summary** for study and teaching; for **exact wording, figures, and supplement tables**, use the **original PDF + journal HTML/PDF + Supplement 1–2**.

---

## 14. Figure index (what each main figure does)

- **Figure 1:** Study overview: **23-center** data; **MELD Graph** vs **MLP**; interpretable report schematic (input features → model → lesion cluster + confidence + salient features).  
- **Figure 2:** Side-by-side predictions + **PPV** comparison + **false-positive cluster counts** (patients and controls) — core evidence for PPV and FP reduction.  
- **Figure 3:** **Interpretable reports** for high-confidence vs low-confidence cases (surface + T1/FLAIR sections + feature bars with saliency coloring).

---

*Summary generated from the PDF text extraction; numeric values and claims follow the published paper and its correction notice.*
