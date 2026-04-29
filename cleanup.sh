#!/bin/bash

echo "=== CLEANING UP EVERYTHING ==="

# Stop all containers
echo "Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null

# Remove all containers
echo "Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null

# Remove networks
echo "Removing networks..."
docker network prune -f

# Clean up system
echo "Cleaning system..."
docker system prune -af

# Remove infrastructure
echo "Removing infrastructure directory..."
rm -rf /opt/infrastructure

echo "=== CLEANUP COMPLETE ==="
echo "Remaining containers:"
docker ps
echo "Remaining networks:"
docker network ls
