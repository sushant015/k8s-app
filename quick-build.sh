#!/bin/bash

# ============================================================================
# Quick Build for Single Service
# ============================================================================
# Usage: ./scripts/quick-build.sh <service-name> [image-tag]
# Example: ./scripts/quick-build.sh poll-service latest
# ============================================================================

set -e

# Go to project root
cd "$(dirname "$0")/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

# ============================================================================

if [ -z "$1" ]; then
    print_error "Service name is required"
    echo "Usage: ./scripts/quick-build.sh <service-name> [image-tag]"
    echo "Example: ./scripts/quick-build.sh poll-service latest"
    exit 1
fi

SERVICE=$1
TIMESTAMP_TAG=$(date +%Y%m%d-%H%M%S)
NAMESPACE="vote-poll"

print_step "Quick Build: $SERVICE:$TIMESTAMP_TAG"
echo ""

# Check if service exists
if [ ! -d "./$SERVICE" ]; then
    print_error "Service directory not found: ./$SERVICE"
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "./$SERVICE/Dockerfile" ]; then
    print_error "Dockerfile not found: ./$SERVICE/Dockerfile"
    exit 1
fi

# Remove old local image
print_step "Removing old local image..."
docker rmi "${SERVICE}:latest" -f > /dev/null 2>&1 || true
print_success "Old local image removed"

# Build new image
print_step "Building Docker image: $SERVICE:$TIMESTAMP_TAG"
if docker build -t "${SERVICE}:${TIMESTAMP_TAG}" "./$SERVICE"; then
    print_success "Image built successfully"
else
    print_error "Failed to build image"
    exit 1
fi

# Update deployment to use the new image tag, triggering a rolling update
print_step "Updating deployment image for $SERVICE..."
if kubectl set image deployment/"$SERVICE" "$SERVICE"="${SERVICE}:${TIMESTAMP_TAG}" -n $NAMESPACE; then
    print_success "Deployment update triggered."
else
    print_error "Failed to update deployment image."
    exit 1
fi

# Wait for pod to be ready
print_step "Waiting for pod to be ready..."
if kubectl wait --for=condition=ready pod -l app=$SERVICE -n $NAMESPACE --timeout=120s; then
    print_success "Pod is ready!"
else
    print_error "Pod failed to start. Check logs with: kubectl logs -n $NAMESPACE -l app=$SERVICE"
    exit 1
fi

echo ""
print_success "Build and deployment completed for $SERVICE"
echo ""
echo "View logs:"
echo "  kubectl logs -n $NAMESPACE -l app=$SERVICE -f"