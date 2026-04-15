# MELD Graph — technical theory and model details

This note complements `meld.md` (clinical / paper summary). It explains **why** the method is formulated as it is, the **signal processing and geometry**, and how the **graph U-Net** in the public codebase realizes the **MELD Graph** algorithm described in Ripart et al., *JAMA Neurology* 2025.

---

## 1. Problem formulation

### 1.1 What is being predicted?

MELD Graph solves a **vertex-wise binary segmentation** problem on the **cerebral cortical surface**:

- **Input:** For each **hemisphere**, a vector of **F** features at each of **V** surface vertices (production pipeline: **F = 34**, **V = 163 842** at full resolution — consistent with an **ico‑7** spherical sampling used for graph convolutions).
- **Output:** For each vertex, a **lesion vs non-lesion** score (implemented as **log-softmax** over two classes; **exp** gives probabilities).
- **Clinical object:** Spatially contiguous sets of predicted lesion vertices are **grouped into clusters** (connected components on the mesh). Each cluster is a **candidate FCD** with **size**, **location labels**, and **confidence** derived from the model scores.

So the core task is **semantic segmentation on a 2D manifold** (the cortical sheet), not dense 3D voxel segmentation — though outputs are later **projected** into native volumetric space for NIfTI reports.

### 1.2 Why not a standard 3D CNN (e.g. nnU-Net on T1/FLAIR volumes)?

- The **cortex** is a **highly folded 2D sheet** embedded in 3D. A 3D convolution sees **mixed tissue types** in a single receptive field (CSF, WM, GM) and must learn folding invariances that surface methods **factor out** by construction.
- The MELD project invested in **surface-based morphometric features** (thickness, curvature, FLAIR sampled at controlled depths) that align with **histopathology-visible cortical architecture** and prior FCD radiology literature.
- The **JAMA** paper frames MELD Graph as a **graph-based analogue of nnU-Net**: same **encoder–decoder + multi-scale pooling** *design philosophy*, but **convolutions are graph convolutions** on a **mesh**, because the domain is **irregular** (non-grid) like other **geometric deep learning** applications.

### 1.3 Limitation of the earlier MELD MLP (patch classifier)

The **Brain 2022** MELD surface model scored **small cortical patches** (~1 cm³) **independently**. That:

- **Throws away long-range context** (the rest of the hemisphere cannot modulate the score).
- Encourages **many scattered high scores** (each patch is myopic), which clinically appears as **many false-positive foci** → **low PPV**.
- Cannot enforce **spatial coherence** as naturally as a **structured segmentation model** with **neighbor coupling**.

MELD Graph **couples vertices through graph convolution** and **multi-scale pooling**, so the model can **suppress** incoherent activations and **propagate** evidence along the surface — the paper’s main mechanistic story for **PPV improvement**.

---

## 2. Imaging features (what the network actually sees)

Features are **not** raw T1/FLAIR intensities at input to the graph. They are **derived, vertex-wise maps** after a substantial pipeline:

1. **Volume processing:** **FreeSurfer** (and related MELD preprocessing) reconstructs surfaces and samples MRI-derived quantities.
2. **Base quantities** (paper): **11** feature *types*, including cortical **thickness**, **gray–white contrast**, **intrinsic curvature**, **sulcal depth**, **curvature**, and **FLAIR**-related gray/white matter intensities, evaluated at **six** depths (intra/sub-cortical sampling scheme in supplement).
3. **Derived stacks** → **34 channels** per vertex:
   - **Smoothed** maps  
   - **Control-normalized** maps (z-like alignment to normative controls)  
   - **Asymmetry** maps (left–right or hemisphere-specific contrasts)  
   - **Residual thickness** (thickness with curvature regressed out — reduces confounded thickness–curvature coupling)

4. **Template space:** Features and manual lesion masks are resampled to a **bilaterally symmetric cortical template** (`fsaverage_sym` family in FreeSurfer ecosystem) so **vertices are comparable across subjects**.

5. **Harmonization (inference on new scanners):** Surface features suffer **site/scanner shifts**. For deployment, **distributed ComBat** (see §7) aligns statistics of new sites to training statistics **without** centralizing raw images.

**Theoretical point:** The network operates in a **hand-crafted feature basis** chosen for **interpretability** and **stability**. That trades off the ability to discover wholly novel raw-intensity patterns (noted as a limitation in the paper) for **data efficiency**, **cross-site normalization**, and **feature-level saliency** that radiologists can relate to.

---

## 3. Graph construction and icospheres

### 3.1 Graph = cortical surface mesh

Each hemisphere is a **graph** **G = (V, E)**:

- **Vertices** **V** are template-registered cortical locations.
- **Edges** **E** connect **geometric neighbors** on the mesh (typically **mesh adjacency** — each vertex connected to nearby vertices on the triangulated surface).

**Node features:** matrix **X ∈ ℝ^{V×F}** (here **F = 34**).

**Labels (training):** binary mask on vertices from intersection of **3D expert lesion ROI** with the surface.

### 3.2 IcoSpheres and multi-resolution hierarchy

The implementation (`meld_graph/icospheres.py`) builds a **fixed hierarchy** of **icosphere meshes** at **levels 1…7** (stored as `.surf.gii`). **Level 7** is the **finest** resolution used for full-resolution convolutions.

**Why icospheres?** They provide:

- A **known, regular refinement scheme** (subdivision surface) for **pooling/unpooling** operators.
- Precomputed **downsample / upsample** index maps (**HexPool** / **HexUnpool**) that map fine vertices to coarse vertices and back.

**Important nuance:** Patient **features** live on the **cortical** template grid used by MELD; **graph topology** for convolutions is driven by these **precomputed spherical meshes** and their adjacency/spirals. The model assumes **consistent vertex ordering** between data tensors and the **IcoSpheres** connectivity (enforced by the preprocessing stack).

### 3.3 Edge attributes and geodesic structure

For **MoNet-style** convolutions, neighbor relations are not enough; one uses **relative geometric descriptors** on edges (e.g. **pseudo‑polar** coordinates or **exact** edge length + angle features), so filters can be **anisotropic** and **direction-aware** on the manifold. The codebase supports:

- `distance_type='pseudo'` vs `'exact'` for how edge vectors are defined.
- These edge attributes feed **GMMConv** (Gaussian mixture over relative coordinates).

---

## 4. Graph convolution layers (core “theory”)

MELD Graph implements **geometric deep learning**: convolution-like operators that **aggregate neighbor features** with **learned weights** that depend on **local geometry**.

### 4.1 Message passing viewpoint

A generic graph convolution layer computes, at vertex **i**,

\[
h_i^{(l+1)} = \sigma\Big( \mathrm{AGG}_{j \in \mathcal{N}(i)} \, f^{(l)}\big(h_i^{(l)}, h_j^{(l)}, e_{ij}\big) \Big)
\]

where **𝒩(i)** are neighbors of **i**, **e_{ij}** are edge features, **f** is a learned message, **AGG** is sum/mean/max, and **σ** is a nonlinearity.

**Classical CNNs** are the special case where the graph is a **regular grid** and **e_{ij}** are translations.

### 4.2 GMMConv (Gaussian mixture graph convolution)

`GMMConv` (PyTorch Geometric) implements a **Monti et al.–style** operator: neighbor contributions are weighted by **learned Gaussian kernels** in a **low-dimensional coordinate system** of **pseudo-coordinates** or **edge vectors** (here 2D or 3D, parameter `dim`).

**Interpretation:** Each filter acts as a **localized kernel** on the manifold: vertices aggregate information from neighbors **with distance-dependent weights**, analogous to **position-dependent filters** in CNNs, but valid on **irregular** neighborhoods.

**`kernel_size`:** number of Gaussian mixture components — more components → richer angular/radial selectivity.

### 4.3 SpiralConv (SpiralNet++ family)

`SpiralConv` orders neighbors along a **fixed spiral stencil** on the mesh and applies a **1D-style** convolution across the spiral sequence.

**Interpretation:** Impose a **canonical local ordering** around each vertex so **weight sharing** resembles **standard convolution** on a **1D ring of neighbors**, which can be efficient and stable on meshes.

The codebase chooses between **`GMMConv`** and **`SpiralConv`** via `conv_type`; production configs often use **SpiralConv** (see `MoNetUnet` defaults in `models.py`).

### 4.4 Instance normalization

Optional **`InstanceNorm`** on feature channels stabilizes training across **different intensity statistics** across vertices and subjects, analogous to normalization in image CNNs but **per sample / per channel statistics** on the vertex graph.

---

## 5. MoNetUnet: U-Net on the cortical graph

The class **`MoNetUnet`** (`meld_graph/models.py`) is the **workhorse segmentation architecture**.

### 5.1 Encoder (contracting path)

- Starts at **level = 7** (full resolution, **V** vertices).
- Repeated **blocks** of **graph conv layers** (same resolution), each block ending with:
  - **HexPool**: **max-pooling** over **patches of neighboring vertices** defined by `get_downsample` — reduces vertex count to the next coarser icosphere level (**level 7 → 6 → …**).
- **Skip connections** store feature maps at each resolution before pooling (U-Net hallmark).

**Effect:** Receptive field **grows** with depth — deeper layers **see** larger **geodesic contexts** on the cortex, analogous to CNNs seeing larger image context.

### 5.2 Bottleneck

The **lowest resolution** representation encodes **global hemisphere context** while preserving **channel depth** built by the encoder.

Optional auxiliary heads (often **off** in pure segmentation deployment):

- **`classification_head`**: hemisphere-level logits after extreme spatial squeezing.
- **`object_detection_head`**: low-dimensional **spatial summary** (experimental).
- **`distance_head`**: auxiliary regression on distance-to-lesion (when enabled).

### 5.3 Decoder (expanding path)

- **HexUnpool**: **mean upsampling** from coarse to fine using fixed upsample indices (inverse of pooling topology).
- **Concatenation** with **skip** features (channel-wise), then conv blocks at the finer resolution.
- **Deep supervision** (optional): auxiliary **vertex classifiers** at intermediate resolutions (`deep_supervision` levels) weighted in the loss — improves gradient flow and boundary precision, as in nnU-Net.

### 5.4 Output heads

- Final **`fc`**: linear map per vertex to **2** logits → **`LogSoftmax`** → per-vertex **log p(lesion)**, **log p(non-lesion)**.
- **`log_sumexp`**: hemisphere-level aggregation derived from vertex logits (used for certain **summary scores** / calibration workflows in evaluation code).

**Training metrics** (per `code_structure.md` / `training.py`): **Dice** on lesion / non-lesion, etc., in addition to cross-entropy implied by log-softmax outputs.

---

## 6. Training semantics (implementation detail)

- Each **hemisphere** is one **graph sample**. Batching is implemented by **stacking vertices** along the batch dimension internally so **conv operators** see the expected layout (`forward` reshapes `(batch * V, F)` ↔ `(batch, V, F)` logic via per-graph loops and stacking).
- **Data augmentation** (`augmentation.py`): intensity noise, mesh jitter, lesion morphological perturbations — improves robustness to **residual misregistration** and **feature noise**.

---

## 7. Harmonization theory: distributed ComBat

**Problem:** MRI-derived surface features shift with **scanner, sequence, coil, and preprocessing site** (“batch effects”). A classifier trained on multi-site data can **overfit site idiosyncrasies** or **fail on a new site** (domain shift).

**ComBat** (originally for genomics) is an **empirical Bayes** harmonization model: for each feature, adjust **mean and variance** per site toward a **reference distribution**, shrinking extreme adjustments when sample sizes are small.

**Distributed ComBat** (Chen et al., cited in the paper) enables **privacy-preserving** estimation: sites contribute **sufficient statistics** without sharing patient-level raw features centrally — important for **multicenter** medical AI.

**Paper-relevant empirical facts:**

- On the **independent 3-center** cohort, **harmonization strongly affects specificity** (56% vs 39% without) while **sensitivity** remains similar — harmonization primarily **reduces false positives** induced by feature distribution shift.
- **~20 scans** from a new scanner recommended to fit **stable** harmonization parameters.

---

## 8. Inference, clustering, and clinical outputs

### 8.1 Vertex probabilities → lesion clusters

1. Apply model → **p(lesion)** per vertex (from log-softmax).
2. Threshold / argmax to **lesion mask** on surface (implementation details in pipeline scripts).
3. **Connected components** on the mesh graph → **clusters** (candidate lesions).
4. **Cluster statistics:** surface area / volume proxy, **max** or **aggregated** probability → **confidence** (paper uses **maximum prediction score** calibration; ECE ≈ **0.10** reported).

### 8.2 Overlap rules for evaluation (paper)

For **detection** metrics, a cluster counts as a **true detection** if it **overlaps** the manual mask **or lies within 20 mm** of it — tolerating **registration / mask uncertainty**. **False positives** are clusters **>20 mm** from truth.

### 8.3 Native space outputs

The pipeline **warps** surface predictions back to **native T1** space and writes **NIfTI** volumes; **PDF reports** combine **inflated surface views**, **T1/FLAIR slices**, and tables.

---

## 9. Interpretability: Integrated Gradients

The paper uses **integrated gradients** (Sundararajan et al.) — implemented via **Captum** (`IntegratedGradients` in `evaluation.py`).

**Mathematical idea:** For model **f**, baseline **x'** (e.g. zero / mean input), input **x**, integrated gradients attribute importance of feature dimension **k** at vertex **v** via:

\[
\mathrm{IG}_k(x) = (x_k - x'_k) \times \int_{\alpha=0}^{1} \frac{\partial f}{\partial x_k}\big(x' + \alpha(x - x')\big) \, d\alpha
\]

**Discretized** along the straight-line path (Riemann sum).

**Properties (axiomatic):** **Sensitivity** and **implementation invariance** under sensible conditions — more faithful than raw gradients for deep networks.

**MELD usage:** Saliency is computed **per cluster**; for vertices in a predicted cluster, integrate gradients with respect to **input features** to obtain **which morphometric channels** drove the lesion hypothesis — displayed in reports as **feature saliency bars** and **highlighted vertices** (top 20% salient vertices in the paper’s figures).

---

## 10. Ensemble model (“fold_all”)

The shipped classifier checkpoint (e.g. **`23-10-30_LVHZ_dcp` / `fold_all`**) reflects **ensembling** across training folds (standard in nnU-Net-style pipelines): multiple models trained with different splits are **averaged or voted** to **reduce variance** and **improve calibration**, at the cost of heavier compute.

---

## 11. Conceptual map: old vs new MELD

| Aspect | MELD MLP (patch) | MELD Graph |
|--------|------------------|------------|
| **Input locality** | Small patch only | Whole hemisphere multi-scale |
| **Inductive bias** | Independent patches | Spatial coupling via graph conv + U-Net |
| **Typical failure mode** | Many FP clusters | Fewer FP clusters, higher PPV |
| **Architecture** | Shallow MLP on patch feature vector | Deep **MoNetUnet** (graph U-Net) |
| **Interpretability** | Patch-level feature weights | Vertex saliency + surface visualization |

---

## 12. Further reading (architecture & geometry ML)

- **MoNet** (Monti et al.): learnable kernels on graphs manifolds.  
- **SpiralNet++**: spiral operators on meshes.  
- **nnU-Net** (Isensee et al.): self-configuring U-Net for biomedical segmentation — **design inspiration** for scheduling depths, deep supervision, and training protocol.  
- **MICCAI 2023** MELD graph paper (Spitzer et al.) — technical precursor on **robust graph segmentation** for subtle lesions.  
- **Integrated gradients** (Sundararajan et al., ICML 2017) — attribution theory.

---

## 13. Code pointers (this repository)

| Topic | Location |
|--------|----------|
| **MoNet / MoNetUnet, HexPool** | `meld_graph/meld_graph/models.py` |
| **IcoSpheres, edges, spirals** | `meld_graph/meld_graph/icospheres.py` |
| **Spiral convolution** | `meld_graph/meld_graph/spiralconv.py` |
| **Dataset / preprocessing** | `meld_graph/meld_graph/dataset.py`, `data_preprocessing.py` |
| **Training loop & metrics** | `meld_graph/meld_graph/training.py` |
| **Integrated gradients** | `meld_graph/meld_graph/evaluation.py` (`Captum`) |
| **High-level structure** | `meld_graph/docs/code_structure.md` |

---

*This document synthesizes the public MELD Graph implementation with the Ripart et al. 2025 *JAMA Neurology* description. For exact hyperparameters of the released container model, see the bundled experiment config and checkpoint metadata in the deployed `models/` and `meld_params/` directories.*
