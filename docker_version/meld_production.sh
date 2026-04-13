#!/usr/bin/env bash
#
# Wrapper for ./meld-docker — same directory, same production.env / MELD_DEPLOY_ROOT.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ge 1 ]]; then
    case "$1" in
        sync)          set -- cohort sync "${@:2}" ;;
        run-cohort)    set -- cohort run-all "${@:2}" ;;
        slurm-cohort)  set -- cohort slurm-all "${@:2}" ;;
    esac
fi

exec bash "${ROOT}/meld-docker" "$@"
