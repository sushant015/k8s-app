#!/bin/bash

# ============================================================================
# Deploy All Manifests to Minikube
# ============================================================================
# This script applies all Kubernetes manifests for the Minikube environment.
# It assumes that Docker images have already been built and loaded.
# ============================================================================

set -e

# Go to project root
cd "$(dirname "$0")/../.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================

NAMESPACE="vote-poll"

print_step "Deploying all Kubernetes manifests to namespace: $NAMESPACE"
kubectl apply -f ms/k8s-minikube/
print_success "All manifests applied."
echo ""

print_step "Waiting for PostgreSQL to be ready (up to 5 minutes)..."
kubectl wait --for=condition=ready pod -l app=postgres-db \
  -n $NAMESPACE --timeout=300s
print_success "PostgreSQL is ready."
echo ""

print_step "Verifying all pods..."
kubectl get pods -n $NAMESPACE
echo ""
print_success "Deployment verification complete."
print_info "Run 'kubectl get pods -n $NAMESPACE -w' to watch all pods become ready."