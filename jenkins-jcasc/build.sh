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
echo "To push this image to a registry, run: docker push ${FULL_IMAGE_NAME}"
echo "You can also tag it as 'latest': docker tag ${FULL_IMAGE_NAME} ${IMAGE_NAME}:latest"