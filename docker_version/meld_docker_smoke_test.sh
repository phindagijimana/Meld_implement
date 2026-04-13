#!/usr/bin/env bash
# Quick sanity checks for meld-docker + meld_production (cohort entry points).
# Run from this directory: bash ./meld_docker_smoke_test.sh

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "== 1. Syntax: bash -n meld-docker meld_production.sh =="
bash -n meld-docker
bash -n meld_production.sh
echo "OK"
echo ""

echo "== 2. ./meld-docker check =="
bash ./meld-docker check
echo ""

echo "== 3. ./meld-docker cohort (no args) — cohort usage =="
bash ./meld-docker cohort
echo ""

echo "== 4. ./meld-docker cohort sync =="
bash ./meld-docker cohort sync
echo "OK (smoke test done)"
