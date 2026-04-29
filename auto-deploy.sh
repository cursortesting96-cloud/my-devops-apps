#!/bin/bash
echo "=== Starting Auto Build and Push to Docker Hub ==="

# 1. App A
echo "Building App A..."
docker build -t talhafayyaz/app-a:latest ./app-a
echo "Pushing App A..."
docker push talhafayyaz/app-a:latest

# 2. App B Backend
echo "Building App B Backend..."
docker build -t talhafayyaz/app-b-backend:latest ./app-b-backend
echo "Pushing App B Backend..."
docker push talhafayyaz/app-b-backend:latest

# 3. App B Frontend
echo "Building App B Frontend..."
docker build -t talhafayyaz/app-b-frontend:latest ./app-b-frontend
echo "Pushing App B Frontend..."
docker push talhafayyaz/app-b-frontend:latest

# 4. Terraform Apply
echo "=== Deploying with Terraform ==="
cd terraform
terraform init
terraform apply -auto-approve

echo "=== ALL DONE! ==="
