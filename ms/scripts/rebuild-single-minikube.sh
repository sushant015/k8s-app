#!/bin/bash

# ============================================================================
# Single Service Rebuild & Deploy Script for Minikube
# ============================================================================
# This script is for quickly iterating on a single microservice.
# It takes one argument: the name of the service to rebuild.
#
# Usage: ./ms/scripts/rebuild-single-minikube.sh <service-name>
# Example: ./ms/scripts/rebuild-single-minikube.sh poll-service
#
# This script:
# 1. Validates the service name and local environment.
# 2. Rebuilds the Docker image for the specified service.
# 3. Loads the new image into the Minikube cluster.
# 4. Temporarily updates the service's Kubernetes manifest with the new tag.
# 5. Applies the manifest to trigger a rolling update for that service.
# 6. Restores the original manifest.
# ============================================================================

set -e

# Go to project root
cd "$(dirname "$0")/../.."

# ============================================================================
# CONFIGURATION & ARGUMENT PARSING
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for service name argument
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <service-name>${NC}"
    echo "Example: $0 poll-service"
    exit 1
fi

SERVICE_NAME=$1

# Configuration
NAMESPACE="vote-poll"
TIMESTAMP_TAG=$(date +%Y%m%d-%H%M%S)
MINIKUBE_PROFILE="minikube"

# Find the manifest file for the service
MANIFEST_FILE=$(find ms/k8s-minikube -type f -name "*-${SERVICE_NAME}.yaml")

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo "╔═════════════════════════════════════════════════════════════════════════════╗"
    echo "║  $1"
    echo "╚═════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_service_exists() {
    local service_path="ms/services/$SERVICE_NAME"
    if [ ! -d "./$service_path" ]; then
        print_error "Service directory not found: ./$service_path"
        return 1
    fi
    return 0
}

check_dockerfile_exists() {
    local service_path="ms/services/$SERVICE_NAME"
    if [ ! -f "./$service_path/Dockerfile" ]; then
        print_error "Dockerfile not found: ./$service_path/Dockerfile"
        return 1
    fi
    return 0
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "Minikube Single Service Rebuild: ${SERVICE_NAME}"

# ============================================================================
# PHASE 1: VALIDATION
# ============================================================================

print_header "PHASE 1: Validation"

print_step "Checking if Minikube is running..."
if ! minikube status &> /dev/null; then
    print_error "Minikube is not running!"
    exit 1
fi
print_success "Minikube is running"

print_step "Validating service: ${SERVICE_NAME}..."
if ! check_service_exists || ! check_dockerfile_exists; then
    exit 1
fi
print_success "Service directory and Dockerfile found."

print_step "Finding manifest for ${SERVICE_NAME}..."
if [ -z "$MANIFEST_FILE" ] || [ ! -f "$MANIFEST_FILE" ]; then
    print_error "Could not find a manifest file for service '${SERVICE_NAME}' in ms/k8s-minikube/"
    exit 1
fi
print_success "Found manifest: ${MANIFEST_FILE}"

# ============================================================================
# PHASE 2: BUILD DOCKER IMAGE
# ============================================================================

print_header "PHASE 2: Build Docker Image"

print_info "Building Docker image for ${SERVICE_NAME} with tag: ${TIMESTAMP_TAG}"
service_path="ms/services/$SERVICE_NAME"
build_dir="./$service_path"

if docker build -t "${SERVICE_NAME}:${TIMESTAMP_TAG}" "$build_dir" > /tmp/docker_build_${SERVICE_NAME}.log 2>&1; then
    print_success "${SERVICE_NAME} built successfully"
else
    print_error "Failed to build ${SERVICE_NAME}"
    echo "Build log:"
    tail -20 /tmp/docker_build_${SERVICE_NAME}.log
    exit 1
fi

# ============================================================================
# PHASE 3: LOAD IMAGE INTO MINIKUBE
# ============================================================================

print_header "PHASE 3: Load Image into Minikube"

image_name="${SERVICE_NAME}:${TIMESTAMP_TAG}"
print_step "Loading: $image_name"

if minikube image load "$image_name" > /tmp/minikube_load_${SERVICE_NAME}.log 2>&1; then
    print_success "${SERVICE_NAME} loaded into Minikube"
else
    print_error "Failed to load ${SERVICE_NAME} into Minikube"
    echo "See log for details: /tmp/minikube_load_${SERVICE_NAME}.log"
    exit 1
fi

# ============================================================================
# PHASE 4: UPDATE KUBERNETES MANIFEST
# ============================================================================

print_header "PHASE 4: Update Kubernetes Manifest"

print_info "Updating YAML file ${MANIFEST_FILE} with new image tag: ${TIMESTAMP_TAG}"

cp "$MANIFEST_FILE" "${MANIFEST_FILE}.bak"

sed -i.tmp "s|image: ${SERVICE_NAME}:.*|image: ${SERVICE_NAME}:${TIMESTAMP_TAG}|g" "$MANIFEST_FILE"
sed -i.tmp "s|version: latest|version: \"${TIMESTAMP_TAG}\"|g" "$MANIFEST_FILE"
rm "${MANIFEST_FILE}.tmp"

print_success "Updated ${MANIFEST_FILE}"

cleanup() {
    print_info "Restoring original manifest: ${MANIFEST_FILE}"
    if [ -f "${MANIFEST_FILE}.bak" ]; then
        mv "${MANIFEST_FILE}.bak" "$MANIFEST_FILE"
    fi
    print_success "Manifest restored."
}
trap cleanup EXIT

# ============================================================================
# PHASE 5: DEPLOY TO KUBERNETES
# ============================================================================

print_header "PHASE 5: Deploy to Kubernetes"

print_step "Applying manifest: ${MANIFEST_FILE}..."
kubectl apply -f "$MANIFEST_FILE"
print_success "Manifest applied, triggering rolling update for ${SERVICE_NAME}."

print_step "Waiting for deployment '${SERVICE_NAME}' to complete its rollout..."
if ! kubectl rollout status deployment/"${SERVICE_NAME}" -n $NAMESPACE --timeout=300s; then
    print_error "Deployment rollout failed for ${SERVICE_NAME}."
    echo "Check pod status with: kubectl get pods -n $NAMESPACE -l app=${SERVICE_NAME}"
    echo "Check pod logs with: kubectl logs -n $NAMESPACE -l app=${SERVICE_NAME}"
    exit 1
fi
print_success "Deployment for ${SERVICE_NAME} completed successfully!"

print_header "✅ Deployment Complete!"
print_info "Service ${SERVICE_NAME} has been updated in Minikube."
echo ""
print_info "Next steps:"
echo "  - To view the new pod, run: 'kubectl get pods -n $NAMESPACE -l app=${SERVICE_NAME}'"
echo "  - To follow logs, run: 'kubectl logs -n $NAMESPACE -l app=${SERVICE_NAME} -f'"