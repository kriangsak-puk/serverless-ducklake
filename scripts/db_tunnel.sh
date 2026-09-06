#!/usr/bin/env bash
# Optional ad-hoc debugging: opens a `psql` shell against the private RDS catalog DB by
# execing into the already-running Superset Fargate task (via ECS Exec / SSM), so this
# repo doesn't need a dedicated bastion host just for occasional manual queries.
#
# Requires the superset module to be deployed and its ECS service running (desired_count
# >= 1 — if Superset is currently scaled to 0 for business hours, scale it up first).

set -euo pipefail

NAME_PREFIX="${NAME_PREFIX:-ducklake}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLUSTER="${NAME_PREFIX}-superset"
SERVICE="${NAME_PREFIX}-superset"

TASK_ARN="$(aws ecs list-tasks --cluster "${CLUSTER}" --service-name "${SERVICE}" --query 'taskArns[0]' --output text)"
if [ "${TASK_ARN}" = "None" ] || [ -z "${TASK_ARN}" ]; then
  echo "No running Superset task found — scale the service up first:" >&2
  echo "  aws ecs update-service --cluster ${CLUSTER} --service ${SERVICE} --desired-count 1" >&2
  exit 1
fi

DB_HOST="$(cd "${REPO_ROOT}/terraform" && terraform output -raw db_host)"

echo "Opening psql to ${DB_HOST} via ECS Exec on ${TASK_ARN}..."
aws ecs execute-command \
  --cluster "${CLUSTER}" \
  --task "${TASK_ARN}" \
  --container superset \
  --interactive \
  --command "psql -h ${DB_HOST} -U \${SUPERSET_DB_USER} -d \${SUPERSET_DB_NAME}"
