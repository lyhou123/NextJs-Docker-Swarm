#!/bin/bash

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Initialize Docker Swarm (only if not already initialized)
if ! docker info | grep -q "Swarm: active"; then
  echo -e "${YELLOW}Initializing Docker Swarm...${NC}"
  docker swarm init || { echo -e "${RED}Failed to initialize Docker Swarm.${NC}"; exit 1; }
else
  echo -e "${GREEN}Docker Swarm is already initialized.${NC}"
fi

# Create the secret only if it doesn't already exist
if ! docker secret ls | grep -q "db_password"; then
  echo -e "${YELLOW}Creating Docker secret: db_password...${NC}"
  echo "SuperSecurePassword123" | docker secret create db_password || { echo -e "${RED}Failed to create Docker secret.${NC}"; exit 1; }
else
  echo -e "${GREEN}Docker secret 'db_password' already exists.${NC}"
fi

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker compose build || { echo -e "${RED}Failed to build Docker image.${NC}"; exit 1; }

# Ensure the image is tagged properly (use the same image name as in docker-compose.yml)
IMAGE_NAME="nextjs_stack_nextjs-app:latest"

# Inspect the new image ID
NEW_IMAGE_ID=$(docker image inspect $IMAGE_NAME --format '{{.Id}}')

# Get the current image ID used by the service in Docker Swarm
SERVICE_IMAGE_ID=$(docker service inspect nextjs_stack_nextjs-app:latest --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' | cut -d@ -f2)

if [ "$NEW_IMAGE_ID" != "$SERVICE_IMAGE_ID" ]; then
  echo -e "${YELLOW}New image detected. Updating service...${NC}"

  # Deploy the stack to update the service with the new image
  docker stack deploy -c docker-compose.yml nextjs_stack

  # Force update the service to use the new image
  docker service update --no-resolve-image --image $IMAGE_NAME --force nextjs_stack_nextjs-app || { echo -e "${RED}Failed to update the service.${NC}"; exit 1; }

  echo -e "${GREEN}Deployment and service update completed successfully.${NC}"

  # Clean up unused build cache
  docker builder prune -f
else
  echo -e "${GREEN}Image has not changed. Skipping update.${NC}"
fi
