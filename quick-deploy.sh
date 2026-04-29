#!/bin/bash

echo "=== QUICK DEPLOY ALL SERVICES ==="

# Create directories
mkdir -p /opt/infrastructure/{gateway,app-a,app-b-backend,app-b-frontend}

# Gateway
echo "Creating gateway..."
cat > /opt/infrastructure/gateway/docker-compose.yml << 'EOF'
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: shared-gateway
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
    command:
      - "--api.insecure=false"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=admin@yourdomain.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - web-gateway

networks:
  web-gateway:
    external: true
EOF

# App A (using nginx for test)
echo "Creating App A..."
cat > /opt/infrastructure/app-a/docker-compose.yml << 'EOF'
version: '3.8'

services:
  app-a-web:
    image: nginx:alpine
    container_name: app-a-web
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-a.rule=Host(`app-a.yourdomain.com`)"
      - "traefik.http.routers.app-a.entrypoints=websecure"
      - "traefik.http.routers.app-a.tls.certresolver=myresolver"
      - "traefik.http.services.app-a.loadbalancer.server.port=80"
    networks:
      - web-gateway

networks:
  web-gateway:
    external: true
EOF

# App B Backend
echo "Creating App B Backend..."
cat > /opt/infrastructure/app-b-backend/docker-compose.yml << 'EOF'
version: '3.8'

services:
  app-b-api:
    image: nginx:alpine
    container_name: app-b-backend
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-b-api.rule=Host(`api.app-b.yourdomain.com`)"
      - "traefik.http.routers.app-b-api.entrypoints=websecure"
      - "traefik.http.routers.app-b-api.tls.certresolver=myresolver"
      - "traefik.http.services.app-b-api.loadbalancer.server.port=80"
    networks:
      - web-gateway

networks:
  web-gateway:
    external: true
EOF

# App B Frontend
echo "Creating App B Frontend..."
cat > /opt/infrastructure/app-b-frontend/docker-compose.yml << 'EOF'
version: '3.8'

services:
  app-b-ui:
    image: nginx:alpine
    container_name: app-b-frontend
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-b-ui.rule=Host(`app-b.yourdomain.com`)"
      - "traefik.http.routers.app-b-ui.entrypoints=websecure"
      - "traefik.http.routers.app-b-ui.tls.certresolver=myresolver"
      - "traefik.http.services.app-b-ui.loadbalancer.server.port=80"
    networks:
      - web-gateway

networks:
  web-gateway:
    external: true
EOF

echo "=== DEPLOYING ALL ==="

# Deploy all
cd /opt/infrastructure/gateway && docker-compose up -d
cd /opt/infrastructure/app-a && docker-compose up -d
cd /opt/infrastructure/app-b-backend && docker-compose up -d
cd /opt/infrastructure/app-b-frontend && docker-compose up -d

echo "=== DONE ==="
docker ps
