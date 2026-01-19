#!/bin/bash
set -e

IMAGE_TAR=$1

if [ -z "$IMAGE_TAR" ]; then
    echo "Error: Image tarball path not provided"
    echo "Usage: bazel run //:push"
    exit 1
fi

echo "Loading Docker image from $IMAGE_TAR..."
docker load -i "$IMAGE_TAR"

echo "Pushing image ironninja33/comfyui-browser:latest..."
docker push ironninja33/comfyui-browser:latest
