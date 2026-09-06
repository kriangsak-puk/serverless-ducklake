#!/usr/bin/env bash
# Builds the shared base image (if needed) plus one function's image, tags it by git sha,
# and pushes to that function's ECR repo.
#
# Usage: scripts/build_and_push_image.sh <ingest|transform|maintain|query|superset> [tag]

set -euo pipefail

FUNCTION="${1:?usage: build_and_push_image.sh <ingest|transform|maintain|query|superset> [tag]}"
TAG="${2:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME_PREFIX="${NAME_PREFIX:-ducklake}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# arm64 everywhere — matches `architectures = ["arm64"]` on the Lambda functions and
# `runtime_platform.cpu_architecture = "ARM64"` on the Superset ECS task (both cheaper
# than x86_64/X86_64). Pinning --platform explicitly means the built image's architecture
# doesn't silently depend on the architecture of whatever machine runs this script.
PLATFORM="${PLATFORM:-linux/arm64}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO_NAME="${NAME_PREFIX}-${FUNCTION}"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:${TAG}"

echo "==> building shared base image (ducklake-base:latest, ${PLATFORM})"
docker build --platform "${PLATFORM}" --provenance=false --sbom=false -f "${REPO_ROOT}/lambdas/base/Dockerfile.base" -t ducklake-base:latest "${REPO_ROOT}"

if [ "${FUNCTION}" = "superset" ]; then
  DOCKERFILE="${REPO_ROOT}/superset/Dockerfile"
else
  DOCKERFILE="${REPO_ROOT}/lambdas/${FUNCTION}/Dockerfile"
fi

echo "==> building ${FUNCTION} image (${PLATFORM})"
# --provenance=false --sbom=false: recent BuildKit attaches provenance/SBOM attestations
# by default, which turns the pushed image into a multi-manifest index — Lambda's
# CreateFunction rejects that ("image manifest ... is not supported"), so it must be a
# plain single-platform manifest.
docker build --platform "${PLATFORM}" --provenance=false --sbom=false -f "${DOCKERFILE}" -t "${IMAGE_URI}" "${REPO_ROOT}"

echo "==> logging in to ECR (${ECR_REGISTRY})"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "==> pushing ${IMAGE_URI}"
docker push "${IMAGE_URI}"

echo "==> done. image_tag=${TAG}"
echo "Set image_tag = \"${TAG}\" (or superset_image for the superset function) in terraform.tfvars before applying."
