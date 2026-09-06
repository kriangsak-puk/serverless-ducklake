#!/usr/bin/env bash
# Builds+pushes all 4 Lambda images (not Superset — that's a separate, later step per
# docs/architecture.md's build order), then runs terraform apply. Intended for iterating
# once the initial phased bring-up (see docs/architecture.md) is done.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="$(git rev-parse --short HEAD 2>/dev/null || echo latest)"

for fn in ingest transform maintain query; do
  "${REPO_ROOT}/scripts/build_and_push_image.sh" "${fn}" "${TAG}"
done

cd "${REPO_ROOT}/terraform"
terraform apply -var="image_tag=${TAG}" "$@"
