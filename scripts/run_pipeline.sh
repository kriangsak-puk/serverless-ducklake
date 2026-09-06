#!/usr/bin/env bash
# Manually triggers the Ingest->Transform Step Functions pipeline (the same one
# EventBridge triggers on a schedule) — useful for testing without waiting for the cron.

set -euo pipefail

NAME_PREFIX="${NAME_PREFIX:-ducklake}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

STATE_MACHINE_ARN="${STATE_MACHINE_ARN:-}"
if [ -z "${STATE_MACHINE_ARN}" ]; then
  STATE_MACHINE_ARN="$(cd "${REPO_ROOT}/terraform" && terraform output -raw state_machine_arn)"
fi

EXECUTION_NAME="manual-$(date +%Y%m%dT%H%M%S)"

aws stepfunctions start-execution \
  --state-machine-arn "${STATE_MACHINE_ARN}" \
  --name "${EXECUTION_NAME}" \
  --input '{}'

echo "Started execution ${EXECUTION_NAME}. Check status with:"
echo "  aws stepfunctions describe-execution --execution-arn <arn-from-above>"
