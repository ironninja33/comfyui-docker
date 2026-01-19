#!/bin/bash
set -e

# Configuration
KANIKO_VERSION="v1.23.2"
REGCTL_URL="https://github.com/regclient/regclient/releases/latest/download/regctl-linux-amd64"

# Check arguments
IMAGE_NAME=$1
if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: ./build.sh <image_name>"
    echo "Example: ./build.sh myuser/myimage:latest"
    exit 1
fi

# Check requirements
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required but not found."
    exit 1
fi

# 1. Setup Kaniko (if not present)
if [ ! -f "./kaniko-executor" ]; then
    echo "Kaniko executor not found. Downloading..."
    
    # Download regctl (registry client) to fetch Kaniko image
    echo "Downloading regctl..."
    curl -L "${REGCTL_URL}" -o regctl
    chmod +x regctl
    
    # Download Kaniko image as tar
    echo "Downloading Kaniko executor image (version ${KANIKO_VERSION})..."
    ./regctl image export "gcr.io/kaniko-project/executor:${KANIKO_VERSION}" kaniko.tar
    
    # Extract executor binary
    echo "Extracting Kaniko binary..."
    mkdir -p temp_kaniko
    tar -xf kaniko.tar -C temp_kaniko
    
    # Debug: List contents to help diagnose if missing
    # ls -R temp_kaniko

    # Locate the executor binary
    # It usually resides at /kaniko/executor
    FOUND_BIN=$(find temp_kaniko -name executor -type f | head -n 1)
    
    if [ -n "$FOUND_BIN" ]; then
        echo "Found Kaniko binary at: $FOUND_BIN"
        mv "$FOUND_BIN" ./kaniko-executor
    else
        echo "Error: Could not find 'executor' binary in extracted image."
        echo "Contents of temp_kaniko:"
        ls -R temp_kaniko
        exit 1
    fi
    
    # Cleanup
    rm regctl kaniko.tar
    rm -rf temp_kaniko
    
    if [ ! -f "./kaniko-executor" ]; then
        echo "Error: Failed to move kaniko-executor to current directory."
        exit 1
    fi

    chmod +x kaniko-executor
    echo "Kaniko setup complete."
else
    echo "Kaniko executor found."
fi

# 2. Setup Credentials
echo "Setting up credentials..."
if [ -z "$DOCKER_USERNAME" ]; then
    read -p "Docker Hub Username: " DOCKER_USERNAME
fi

if [ -z "$DOCKER_PASSWORD" ]; then
    read -s -p "Docker Hub Password: " DOCKER_PASSWORD
    echo "" # Newline after silent input
fi

if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
    echo "Error: Credentials are required."
    exit 1
fi

AUTH=$(echo -n "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" | base64)
CONFIG_DIR="./.docker"
mkdir -p "${CONFIG_DIR}"

cat > "${CONFIG_DIR}/config.json" <<EOF
{
    "auths": {
        "https://index.docker.io/v1/": {
            "auth": "${AUTH}"
        }
    }
}
EOF

# 3. Build and Push
echo "Starting build for ${IMAGE_NAME}..."
./kaniko-executor \
    --context dir://$(pwd) \
    --dockerfile Dockerfile \
    --destination "${IMAGE_NAME}" \
    --docker-config "${CONFIG_DIR}/config.json" \
    --cache=true

echo "Build and push completed successfully!"

# Cleanup config
rm -rf "${CONFIG_DIR}"
