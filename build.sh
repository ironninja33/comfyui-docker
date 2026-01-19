#!/bin/bash
set -e
IMAGE=$1
[ -z "$IMAGE" ] && echo "Usage: $0 <image>" && exit 1

# Install Kaniko
if [ ! -f /usr/local/bin/kaniko ]; then
    echo "Installing Kaniko..."
    curl -L https://github.com/GoogleContainerTools/kaniko/releases/download/v1.23.2/executor_linux_amd64 -o /usr/local/bin/kaniko
    chmod +x /usr/local/bin/kaniko
fi

# Credentials
[ -z "$DOCKER_USERNAME" ] && read -p "Docker User: " DOCKER_USERNAME
[ -z "$DOCKER_PASSWORD" ] && read -s -p "Docker Pass: " DOCKER_PASSWORD && echo ""

# Config
AUTH=$(echo -n "$DOCKER_USERNAME:$DOCKER_PASSWORD" | base64)
mkdir -p ~/.docker
echo "{\"auths\":{\"https://index.docker.io/v1/\":{\"auth\":\"$AUTH\"}}}" > ~/.docker/config.json

# Build & Push
echo "Building $IMAGE..."
/usr/local/bin/kaniko --context "dir://$(pwd)" --dockerfile Dockerfile --destination "$IMAGE" --cache=true
