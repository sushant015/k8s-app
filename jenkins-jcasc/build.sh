#!/bin/bash
#
# Builds the Jenkins Docker image with a timestamp tag.
#

set -e
set -o pipefail

# Go to the script's directory
cd "$(dirname "$0")"

# --- Configuration ---
# The name of the Docker image to build.
IMAGE_NAME="jenkins-jcasc"
# You can prefix this with a Docker Hub username or a private registry URL
# e.g., "your-dockerhub-username/jenkins-jcasc"
# e.g., "gcr.io/your-project/jenkins-jcasc"

# --- Script ---
TIMESTAMP_TAG=$(date +%Y%m%d-%H%M%S)
FULL_IMAGE_NAME="${IMAGE_NAME}:${TIMESTAMP_TAG}"

echo "##################################################"
echo "Building Docker image: ${FULL_IMAGE_NAME}"
echo "##################################################"

if ! docker build -t "${FULL_IMAGE_NAME}" . ; then
    echo "ERROR: Docker build failed."
    exit 1
fi

echo ""
echo "✅ Successfully built image: ${FULL_IMAGE_NAME}"

echo ""
echo "##################################################"
echo "Loading image into Minikube..."
echo "##################################################"

if ! minikube status &> /dev/null; then
    echo "ERROR: Minikube is not running. Please start it with 'minikube start'."
    exit 1
fi

if ! minikube image load "${FULL_IMAGE_NAME}"; then
    echo "ERROR: Failed to load image into Minikube."
    exit 1
fi

echo "✅ Successfully loaded image '${FULL_IMAGE_NAME}' into Minikube."
echo ""
echo "To push this image to a registry, run: docker push ${FULL_IMAGE_NAME}"
echo "You can also tag it as 'latest': docker tag ${FULL_IMAGE_NAME} ${IMAGE_NAME}:latest"