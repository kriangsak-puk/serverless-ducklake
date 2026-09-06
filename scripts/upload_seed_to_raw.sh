#!/usr/bin/env bash
# Copies the mock e-commerce CSVs into the raw bucket's source-drop/ prefix — this is the
# "external source" that the Ingest Lambda pulls from (see lambdas/ingest/sources/ecommerce_db.py).
# Run once before the first Ingest invocation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RAW_BUCKET="${RAW_BUCKET_NAME:-}"
if [ -z "${RAW_BUCKET}" ]; then
  RAW_BUCKET="$(cd "${REPO_ROOT}/terraform" && terraform output -raw raw_bucket_name)"
fi

aws s3 cp "${REPO_ROOT}/data/seed/" "s3://${RAW_BUCKET}/source-drop/" --recursive --exclude "*" --include "*.csv"

echo "Uploaded seed CSVs to s3://${RAW_BUCKET}/source-drop/"
