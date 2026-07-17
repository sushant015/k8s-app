#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-us-central1}"
AR_REPO="${AR_REPO:-vote-poll-images}"
REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}"

SERVICES=(
  api-gateway
  auth-service
  user-service
  poll-service
  vote-service
  result-service
  frontend
)

for svc in "${SERVICES[@]}"; do
  echo "Building ${svc}..."
  docker build -t "${REGISTRY}/${svc}:latest" "ms/services/${svc}"
  docker push "${REGISTRY}/${svc}:latest"
done

echo "All images pushed to ${REGISTRY}"
