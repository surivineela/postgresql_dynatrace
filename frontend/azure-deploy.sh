#!/bin/bash
set -e

echo "Building and pushing frontend Docker image..."

# Get environment variables from azd
AZURE_CONTAINER_REGISTRY_ENDPOINT=$(azd env get-values --output json | jq -r '.AZURE_CONTAINER_REGISTRY_ENDPOINT')
AZURE_CONTAINER_REGISTRY_NAME=$(azd env get-values --output json | jq -r '.AZURE_CONTAINER_REGISTRY_NAME')
ENABLE_DYNATRACE=$(azd env get-values --output json | jq -r '.ENABLE_DYNATRACE // "false"')
DYNATRACE_ENVIRONMENT_ID=$(azd env get-values --output json | jq -r '.DYNATRACE_ENVIRONMENT_ID // ""')
DYNATRACE_APP_ID=$(azd env get-values --output json | jq -r '.DYNATRACE_APP_ID // "OCTOPETS_FRONTEND"')

# Login to ACR
az acr login --name "$AZURE_CONTAINER_REGISTRY_NAME"

# Build and push frontend image with Dynatrace RUM configuration
cd frontend
docker build \
  --build-arg REACT_APP_DYNATRACE_ENABLED="$ENABLE_DYNATRACE" \
  --build-arg REACT_APP_DYNATRACE_ENV_ID="$DYNATRACE_ENVIRONMENT_ID" \
  --build-arg REACT_APP_DYNATRACE_APP_ID="$DYNATRACE_APP_ID" \
  --build-arg REACT_APP_DYNATRACE_RUM_SCRIPT="https://${DYNATRACE_ENVIRONMENT_ID}/api/v2/rum/scriptTag" \
  -t "$AZURE_CONTAINER_REGISTRY_ENDPOINT/octopets-frontend:latest" \
  -f Dockerfile .
docker push "$AZURE_CONTAINER_REGISTRY_ENDPOINT/octopets-frontend:latest"

echo "Frontend image built and pushed successfully!"
