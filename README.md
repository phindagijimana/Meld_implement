# MELD Graph Pipeline

FCD lesion detection with the MELD Graph container ([MELDProject/meld_graph](https://github.com/MELDProject/meld_graph) v2.2.4). Citation: Ripart et al., JAMA Neurology, 2025. doi:10.1001/jamaneurol.2024.5406.

What is pinned, and what a matching run does and does not guarantee: [REPRODUCIBILITY.md](REPRODUCIBILITY.md).

## Quick start

Apptainer or Singularity, about 20 GB of disk, 32 GB of RAM. SLURM is only required for `slurm`.

```bash
git clone https://github.com/<ORG_OR_USER>/<REPO>.git
cd <REPO>/docker_version

# FreeSurfer: https://surfer.nmr.mgh.harvard.edu/registration.html
# MELD registration: https://meld.org.uk/get-started/
cp /path/to/license.txt freesurfer_license.txt
cp /path/to/meld_license.txt meld_license.txt

./meld-docker setup
./meld-docker run sub-test001 --fastsurfer
```

`setup` pulls `docker://meldproject/meld_graph:v2.2.4` and downloads the weights, `meld_params`, and the public test subject. The report is `meld_data/output/predictions_reports/sub-test001/reports/`. The image, licenses, and weights stay on disk. They are not in the clone.

Your own scan needs a PyBIDS-safe id (letters and digits only after `sub-`):

```text
meld_data/<Cohort>/sub-001/anat/sub-001_T1w.nii.gz
```

```bash
./meld-docker validate sub-001
./meld-docker run sub-001 --fastsurfer          # this machine
./meld-docker slurm sub-001 --fastsurfer       # cluster
```

DICOM through BIDS is [docs/NEW_PATIENT_MELD_PROTOCOL.md](docs/NEW_PATIENT_MELD_PROTOCOL.md). Do not commit patient data or licenses ([docs/DATA_PRIVACY.md](docs/DATA_PRIVACY.md)).

## Commands

Run these from `docker_version/`.

```bash
./meld-docker setup                     # image, weights, public test subject
./meld-docker setup --skip-test-data    # weights and parameters only
./meld-docker check
./meld-docker run <subject> [--fastsurfer]
./meld-docker batch <sub1> <sub2>
./meld-docker slurm <subject> [--fastsurfer]
./meld-docker validate <subject>
./meld-docker status [subject]
./meld-docker logs <subject>
./meld-docker results <subject>
./meld-docker shell
./meld-docker help
```

`./meld` at the repo root is a separate SLURM and conda wrapper. It does not download the weights. Use `./meld-docker setup` for a clone.

## Output

`docker_version/meld_data/output/predictions_reports/<subject>/`

- `reports/MELD_report_<subject>.pdf`
- `reports/info_clusters_<subject>.csv`
- `predictions/prediction.nii.gz`

## If a run fails

```bash
./meld-docker logs <subject>
```

Logs are under `meld_data/logs/`. FreeSurfer needs a 3D T1 and about 32 GB of RAM. A FastSurfer run is typically 1–2 hours. FreeSurfer is typically 4–5 hours. HDF5 lock messages during parallel jobs retry on their own.

See [TECHNICAL_REFERENCE.md](TECHNICAL_REFERENCE.md) for the model and the pipeline stages.
