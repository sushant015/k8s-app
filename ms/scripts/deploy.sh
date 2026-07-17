#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-${PROJECT_ID:-}}"
if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: ./ms/scripts/deploy.sh PROJECT_ID"
  exit 1
fi

find ms/k8s -name '*.yaml' -exec sed -i.bak "s/PROJECT_ID/${PROJECT_ID}/g" {} +
rm -f ms/k8s/*.bak

kubectl apply -k ms/k8s/
echo "Deployed to GKE. Check internal LB:"
kubectl get svc -n vote-poll frontend-service
