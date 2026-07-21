#!/bin/bash

# ============================================================================
# Build, Load, and Deploy Script for Minikube
# ============================================================================
# This script:
# 1. Removes old Docker images from local machine
# 2. Removes images from Minikube
# 3. Rebuilds Docker images from source
# 4. Loads images into Minikube
# 5. Deploys to Kubernetes via kubectl apply
# ============================================================================

set -e

# Go to project root
cd "$(dirname "$0")/../.."

# ============================================================================
# CONFIGURATION
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="vote-poll"
DOCKER_REGISTRY="" # Empty for local development
TIMESTAMP_TAG=$(date +%Y%m%d-%H%M%S)
MINIKUBE_PROFILE="minikube"

# List of microservices to build
SERVICES=(
    "auth-service"
    "user-service"
    "poll-service"
    "vote-service"
    "result-service"
    "api-gateway"
    "frontend"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║  $1"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
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

# Check if service directory exists
check_service_exists() {
    local service=$1
    local service_path="ms/services/$service"
    if [ ! -d "./$service_path" ]; then
        print_error "Service directory not found: ./$service_path"
        return 1
    fi
    return 0
}

# Check if Dockerfile exists
check_dockerfile_exists() {
    local service=$1
    local service_path="ms/services/$service"
    if [ ! -f "./$service_path/Dockerfile" ]; then
        print_error "Dockerfile not found: ./$service_path/Dockerfile"
        return 1
    fi
    return 0
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "Minikube Build, Load & Deploy Script"

# ============================================================================
# PHASE 1: VALIDATION
# ============================================================================

print_header "PHASE 1: Validation"

print_step "Checking if Minikube is running..."
if ! minikube status &> /dev/null; then
    print_error "Minikube is not running!"
    echo "Start Minikube with: minikube start --cpus=4 --memory=4096"
    exit 1
fi
print_success "Minikube is running"

print_step "Checking if Kubernetes is accessible..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Kubernetes cluster not accessible!"
    exit 1
fi
print_success "Kubernetes is accessible"

print_step "Checking if namespace '$NAMESPACE' exists..."
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    print_info "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
    print_success "Namespace created"
else
    print_success "Namespace exists"
fi

print_step "Validating all services..."
for service in "${SERVICES[@]}"; do
    if check_service_exists "$service"; then
        if check_dockerfile_exists "$service"; then
            print_success "$service"
        else
            print_error "$service has no Dockerfile"
            exit 1
        fi
    else
        print_error "$service directory not found"
        exit 1
    fi
done

# ============================================================================
# PHASE 2: REMOVE OLD IMAGES
# ============================================================================

print_header "PHASE 2: Remove Old Images"

print_step "Pruning unused Docker images from local machine..."
# This removes all dangling images and images not associated with a container.
docker image prune -a -f
print_success "Local image cleanup complete."

print_step "Pruning unused Docker images from Minikube..."
# Switch to Minikube's Docker daemon to run the prune command there.
eval $(minikube docker-env)
docker image prune -a -f
# Unset the environment variables to return to the local Docker daemon.
eval $(minikube docker-env --unset)
print_success "Minikube image cleanup complete."

# ============================================================================
# PHASE 3: BUILD DOCKER IMAGES
# ============================================================================

print_header "PHASE 3: Build Docker Images"

print_info "Building $(echo ${#SERVICES[@]}) Docker images with tag: ${TIMESTAMP_TAG}"
echo ""

for service in "${SERVICES[@]}"; do
    print_step "Building: $service"
    
    service_path="ms/services/$service"
    # Check if service directory has nested services (e.g., auth-service/auth-service)
    build_dir="./$service_path"
    if [ -d "./$service_path/$service" ]; then
        build_dir="./$service_path"
    fi
    
    # Build the Docker image
    if docker build -t "${service}:${TIMESTAMP_TAG}" "$build_dir" > /tmp/docker_build_${service}.log 2>&1; then
        print_success "$service built successfully"
    else
        print_error "Failed to build $service"
        echo "Build log:"
        tail -20 /tmp/docker_build_${service}.log
        exit 1
    fi
done

echo ""
print_success "All Docker images built successfully"

# ============================================================================
# PHASE 4: LOAD IMAGES INTO MINIKUBE
# ============================================================================

print_header "PHASE 4: Load Images into Minikube"

print_step "Loading images into Minikube ($(echo ${#SERVICES[@]}) images)..."
echo ""

for service in "${SERVICES[@]}"; do
    image_name="${service}:${TIMESTAMP_TAG}"
    print_step "Loading: $image_name"
    
    if minikube image load "$image_name" > /tmp/minikube_load_${service}.log 2>&1; then
        print_success "$service loaded into Minikube"
    else
        print_error "Failed to load $service into Minikube"
        echo "See log for details: /tmp/minikube_load_${service}.log"
        exit 1
    fi
done

echo ""
print_success "All images loaded into Minikube"

# ============================================================================
# PHASE 5: VERIFY IMAGES
# ============================================================================

print_header "PHASE 5: Verify Images in Minikube"

print_step "Verifying images exist in Minikube..."
echo ""

for service in "${SERVICES[@]}"; do
    image_name="${service}:${TIMESTAMP_TAG}"
    # Use minikube image ls and grep to verify
    if minikube image ls | grep -q "${service}.*${TIMESTAMP_TAG}"; then
        # Getting exact size is less straightforward without docker-env, so we'll just confirm existence
        print_success "$image_name"
    else
        print_error "$service not found in Minikube"
        exit 1
    fi
done

echo ""
print_success "All images verified in Minikube"

# ============================================================================
# PHASE 5.5: UPDATE KUBERNETES MANIFESTS WITH NEW IMAGE TAG
# ============================================================================

print_header "PHASE 5.5: Update Kubernetes Manifests"

print_info "Updating YAML files with new image tag: ${TIMESTAMP_TAG}"

# Define the list of manifest files to update
MANIFESTS=(
    "ms/k8s-minikube/10-api-gateway.yaml"
    "ms/k8s-minikube/11-auth-service.yaml"
    "ms/k8s-minikube/12-user-service.yaml"
    "ms/k8s-minikube/13-poll-service.yaml"
    "ms/k8s-minikube/14-vote-service.yaml"
    "ms/k8s-minikube/15-result-service.yaml"
    "ms/k8s-minikube/16-frontend-service.yaml"
)

# Create backups and update files
for manifest in "${MANIFESTS[@]}"; do
    if [ -f "$manifest" ]; then
        # Create a backup of the original file
        cp "$manifest" "${manifest}.bak"
        
        # 1. Use sed to replace the image tag. This is compatible with both GNU and BSD (macOS) sed.
        sed -i.tmp "s|image: \(.*\):latest|image: \1:${TIMESTAMP_TAG}|g" "$manifest"
        
        # 2. Replace the version label placeholder with the current timestamp tag.
        sed -i.tmp "s|version: latest|version: \"${TIMESTAMP_TAG}\"|g" "$manifest"

        rm "${manifest}.tmp" # Clean up sed's temp file

        print_success "Updated $manifest"
    else
        print_error "Manifest file not found: $manifest"
    fi
done

# Function to restore backups on exit
cleanup() {
    print_info "Restoring original Kubernetes manifests..."
    for manifest in "${MANIFESTS[@]}"; do
        if [ -f "${manifest}.bak" ]; then
            mv "${manifest}.bak" "$manifest"
        fi
    done
    print_success "Manifests restored."
}
trap cleanup EXIT # Register the cleanup function to run when the script exits

# ============================================================================
# PHASE 6: DEPLOY KUBERNETES MANIFESTS & UPDATE IMAGES
# ============================================================================

print_header "PHASE 6: Deploy & Update Services"

print_step "Applying base Kubernetes manifests (Services, ConfigMaps, etc.)..."
# Apply all manifests. This creates or updates services, ingress, etc.
# The changes to the image tags will trigger rolling updates for the deployments.
kubectl apply -f ms/k8s-minikube/
print_success "All manifests applied, triggering rolling updates."

print_step "Waiting for PostgreSQL to be ready (if not already)..."
kubectl wait --for=condition=ready pod -l app=postgres-db -n $NAMESPACE --timeout=300s
print_success "PostgreSQL is ready."