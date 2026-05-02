# Data privacy and what not to commit to Git (including GitHub)

Keep **code and documentation** in this repository. Treat anything that can identify a **person** (patient, staff) or expose **local IT layout** as sensitive and keep it out of `git` remotes.

## Never commit

- **PHI:** DICOM, NIfTIs with real subjects, PDF reports tied to real identities, MRNs, accessions, DOB, facial reconstructions.
- **Secrets:** FreeSurfer `license.txt`, MELD `meld_license.txt`, API tokens, passwords, private keys.
- **Site-specific paths:** Real home paths or NFS roots in committed configs (use `.example` templates; real `meld_config.ini` stays local — see root `.gitignore`).
- **Audit or Cursor artifacts** that may list usernames, hosts, or subject-linked IDs — patterns like `meld_run_audit_registry.csv` and `cursor.md` are ignored at repo root.

## Placeholders in docs

- Example subjects: `sub-001`, not site-specific BIDS IDs.
- Clone URLs: use a placeholder repo path or the public upstream `MELDProject/meld_graph` when documenting upstream-only workflows.

## Already ignored (check `.gitignore`)

- `meld_graph/meld_data/`, `docker_version/meld_data/`, large `*.sif`
- `meld_graph/meld_config.ini`, `production.env` (not `*.example`)
- Pipeline logs `*.log`, `*.out`
- License file paths under `freesurfer_license/` and docker bundle copies

## Before every push

1. Run `git status` and scan for unexpected files.
2. Run `git diff` for accidental emails or absolute paths.
3. Do not use real patient folders under tracked paths.

## If sensitive data was pushed

Rotate exposed credentials; remove from history (`git filter-repo` or provider purge). A follow-up commit deleting the file does **not** remove secrets from clone history.

## References

- GitHub: [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- Public MELD Graph: [github.com/MELDProject/meld_graph](https://github.com/MELDProject/meld_graph)
