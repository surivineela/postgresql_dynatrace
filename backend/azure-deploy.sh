#!/bin/bash
set -e

echo "Building and pushing backend Docker image..."

# Get environment variables from azd
AZURE_CONTAINER_REGISTRY_ENDPOINT=$(azd env get-values --output json | jq -r '.AZURE_CONTAINER_REGISTRY_ENDPOINT')
AZURE_CONTAINER_REGISTRY_NAME=$(azd env get-values --output json | jq -r '.AZURE_CONTAINER_REGISTRY_NAME')

# Login to ACR
az acr login --name "$AZURE_CONTAINER_REGISTRY_NAME"

# Build and push backend image
cd backend
docker build -t "$AZURE_CONTAINER_REGISTRY_ENDPOINT/octopets-backend:latest" -f Dockerfile ..
docker push "$AZURE_CONTAINER_REGISTRY_ENDPOINT/octopets-backend:latest"

echo "Backend image built and pushed successfully!"
