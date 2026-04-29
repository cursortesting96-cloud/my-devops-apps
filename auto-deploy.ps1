# Auto Deploy Script for talhafayyaz
Write-Host "=== Starting Auto Build and Push to Docker Hub ===" -ForegroundColor Cyan

# 1. App A
Write-Host "Building App A..."
docker build -t talhafayyaz/app-a:latest ./app-a
Write-Host "Pushing App A..."
docker push talhafayyaz/app-a:latest

# 2. App B Backend
Write-Host "Building App B Backend..."
docker build -t talhafayyaz/app-b-backend:latest ./app-b-backend
Write-Host "Pushing App B Backend..."
docker push talhafayyaz/app-b-backend:latest

# 3. App B Frontend
Write-Host "Building App B Frontend..."
docker build -t talhafayyaz/app-b-frontend:latest ./app-b-frontend
Write-Host "Pushing App B Frontend..."
docker push talhafayyaz/app-b-frontend:latest

# 4. Terraform Apply
Write-Host "=== Deploying with Terraform ===" -ForegroundColor Green
cd terraform
terraform init
terraform apply -auto-approve

Write-Host "=== ALL DONE! ===" -ForegroundColor Green
