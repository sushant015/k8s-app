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
DOCKER_REGISTRY=""  # Empty for local development
IMAGE_TAG="latest"
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

print_step "Removing old Docker images from local machine..."
for service in "${SERVICES[@]}"; do
    local_image="${service}:${IMAGE_TAG}"
    if docker image inspect "$local_image" &> /dev/null; then
        print_info "Removing: $local_image"
        docker rmi "$local_image" -f > /dev/null 2>&1 || true
    fi
done
print_success "Local images cleaned"

print_step "Removing old images from Minikube..."
eval $(minikube docker-env)
for service in "${SERVICES[@]}"; do
    minikube_image="${service}:${IMAGE_TAG}"
    if docker image inspect "$minikube_image" &> /dev/null; then
        print_info "Removing: $minikube_image (from Minikube)"
        docker rmi "$minikube_image" -f > /dev/null 2>&1 || true
    fi
done
eval $(minikube docker-env --unset)
print_success "Minikube images cleaned"

# ============================================================================
# PHASE 3: BUILD DOCKER IMAGES
# ============================================================================

print_header "PHASE 3: Build Docker Images"

print_info "Building $(echo ${#SERVICES[@]}) Docker images..."
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
    if docker build -t "${service}:${IMAGE_TAG}" "$build_dir" > /tmp/docker_build_${service}.log 2>&1; then
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
    image_name="${service}:${IMAGE_TAG}"
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
    image_name="${service}:${IMAGE_TAG}"
    # Use minikube image ls and grep to verify
    if minikube image ls | grep -q "${service}.*${IMAGE_TAG}"; then
        # Getting exact size is less straightforward without docker-env, so we'll just confirm existence
        print_success "$image_name"
    else
        print_error "$service not found in Minikube"
        exit 1
    fi
done

echo ""
print_success "All images verified in Minikube"