# Reproducing a run

Commands are in the [README](README.md). This file is what a second machine must match, and what will still differ.

A clone does not contain the image, licenses, weights, or MRI. `./meld-docker setup` fetches the image and the weights. You supply the two licenses and, for a real subject, the T1w NIfTI.

## Pinned

| Piece | Record |
| --- | --- |
| Container | `docker://meldproject/meld_graph:v2.2.4` in `docker_version/IMAGE.lock` |
| Digest | `Digest:` in that file, written when `setup` can inspect the local image |
| Weights | Figshare file `46176927`, via `prepare_classifier.py` in the container |
| Parameters | Figshare file `46176921` |
| Public test subject | Figshare file `53523443`, unpacked to `meld_data/input/sub-test001` |
| BIDS lookup | `docker_version/templates/`, copied into `meld_data/input/` by `setup` |
| Predict command | `new_pt_pipeline.py -id <subject>` |

`setup` runs that download with `KEEP_DATA_PATH=1` and `--skip-config`, so it does not prompt for a data path. `--skip-test-data` skips the public subject only.

The same container tag, the same weights, and the same command are the target. FreeSurfer surfaces are not bit-identical across machines. Cluster coordinates can differ between FreeSurfer and FastSurfer, and between hosts.

## Subject names

One id per visit. After `sub-`, use letters and digits only. An underscore or a hyphen inside the label makes PyBIDS read a shorter subject id, and the run fails even when `validate` passes. FLAIR is optional: `sub-001_FLAIR.nii.gz` next to the T1w. `./meld-docker slurm` links `meld_data/<Cohort>/sub-001` into `meld_data/input/`.

## Not in git

The `.sif`, both license files, `meld_graph/license.txt`, model files, and everything under `meld_data/` except `.gitkeep`. `research/` is site planning. It is not required to run the pipeline. Review it before a public push.
