#!/usr/bin/env bash
# One-time (idempotent) DuckLake catalog + Superset metastore bootstrap. Run after
# `catalog_db` + `lambda_functions` (at least `maintain`) are deployed, before the first
# Transform run. See lambdas/maintain/init_catalog.py.

set -euo pipefail

NAME_PREFIX="${NAME_PREFIX:-ducklake}"
FUNCTION_NAME="${MAINTAIN_FUNCTION_NAME:-${NAME_PREFIX}-maintain}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="${REPO_ROOT}/response.json"

aws lambda invoke \
  --function-name "${FUNCTION_NAME}" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"init_catalog"}' \
  "${OUT_FILE}"

cat "${OUT_FILE}"
