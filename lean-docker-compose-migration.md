# Lean Migration Plan: Docker + Jenkins (Zero Downtime)

Based on your actual requirements, this is the practical, cost-effective, and highly maintainable architecture. It relies on **Docker Compose** and **Jenkins**, separating the monolithic structure into **four independent deployment pipelines** with a shared reverse proxy. 

---

## 🏗️ 1. Target Architecture

```text
                        Internet (Ports 80/443)
                               |
                +------------------------------+
                |   Shared Gateway Service     |
                |   (Traefik + LetsEncrypt)    |
                +------------------------------+
                   /                       \
        (app-a.domain.com)          (app-b.domain.com / api.app-b.domain.com)
               /                             \
+-------------------------+      +-------------------------+
| Pipeline 1: App A       |      | Pipeline 3: App B Front |
| (Django + Bootstrap)    |      | (Next.js)               |
+-------------------------+      +-------------------------+
                                             |
                                 +-------------------------+
                                 | Pipeline 4: App B Back  |
                                 | (Django API)            |
                                 +-------------------------+
```

---

## 📂 2. Independent Docker Compose Configurations

You will create four separate directories (or repositories), each with its own `docker-compose.yml`. They will communicate via a shared external Docker network.

### Step 0: Create the Shared Network
First, run this directly on the server to create the network that Traefik and all apps will share:
```bash
docker network create web-gateway
```

### 1️⃣ Shared Gateway Service (Pipeline 1)
Extract Traefik into its own independent service. It only routes traffic dynamically based on Docker labels.

**`gateway/docker-compose.yml`**
```yaml
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
      - "--certificatesresolvers.myresolver.acme.email=your-email@domain.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - web-gateway

networks:
  web-gateway:
    external: true
```

### 2️⃣ Application A (Pipeline 2)
App A continues to exist exactly as it is, but we attach it to the `web-gateway` network.

**`app-a/docker-compose.yml`**
```yaml
version: '3.8'

services:
  app-a-web:
    image: your-registry/app-a:latest
    container_name: app-a-web
    restart: always
    env_file: .env
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-a.rule=Host(`app-a.yourdomain.com`)"
      - "traefik.http.routers.app-a.entrypoints=websecure"
      - "traefik.http.routers.app-a.tls.certresolver=myresolver"
      - "traefik.http.services.app-a.loadbalancer.server.port=8000"
    networks:
      - web-gateway
      - app-a-internal

  app-a-db:
    image: postgres:15
    container_name: app-a-db
    restart: always
    volumes:
      - app-a-db-data:/var/lib/postgresql/data
    networks:
      - app-a-internal

volumes:
  app-a-db-data:

networks:
  web-gateway:
    external: true
  app-a-internal:
    driver: bridge
```

### 3️⃣ Application B - Backend (Pipeline 3)
Independent Django API.

**`app-b-backend/docker-compose.yml`**
```yaml
version: '3.8'

services:
  app-b-api:
    image: your-registry/app-b-backend:latest
    container_name: app-b-backend
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-b-api.rule=Host(`api.app-b.yourdomain.com`)"
      - "traefik.http.routers.app-b-api.entrypoints=websecure"
      - "traefik.http.routers.app-b-api.tls.certresolver=myresolver"
      - "traefik.http.services.app-b-api.loadbalancer.server.port=8000"
    networks:
      - web-gateway
      - app-b-internal

  app-b-db:
    image: postgres:15
    container_name: app-b-db
    restart: always
    volumes:
      - app-b-db-data:/var/lib/postgresql/data
    networks:
      - app-b-internal

volumes:
  app-b-db-data:

networks:
  web-gateway:
    external: true
  app-b-internal:
    driver: bridge
```

### 4️⃣ Application B - Frontend (Pipeline 4)
Independent Next.js UI using its own container.

**`app-b-frontend/docker-compose.yml`**
```yaml
version: '3.8'

services:
  app-b-ui:
    image: your-registry/app-b-frontend:latest
    container_name: app-b-frontend
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-b-ui.rule=Host(`app-b.yourdomain.com`)"
      - "traefik.http.routers.app-b-ui.entrypoints=websecure"
      - "traefik.http.routers.app-b-ui.tls.certresolver=myresolver"
      - "traefik.http.services.app-b-ui.loadbalancer.server.port=3000"
    networks:
      - web-gateway

networks:
  web-gateway:
    external: true
```

---

## 🚀 3. Jenkins Pipeline Blueprint

Every application gets its own independent `Jenkinsfile` for CI/CD. Deploying App B Front will never restart App A.

**Standard `Jenkinsfile` for each app (example for App B Backend):**
```groovy
pipeline {
    agent any
    environment {
        IMAGE_NAME = "your-registry/app-b-backend:${env.BUILD_ID}"
        COMPOSE_DIR = "/opt/infrastructure/app-b-backend" // Location on Server
    }
    stages {
        stage('Build') {
            steps {
                sh "docker build -t ${IMAGE_NAME} ."
            }
        }
        stage('Deploy') {
            steps {
                // Update the docker-compose file image version on remote server
                sh "sed -i 's|image: your-registry/app-b-backend:.*|image: ${IMAGE_NAME}|g' ${COMPOSE_DIR}/docker-compose.yml"
                
                // Pull and recreate ONLY this specific service with zero downtime (if using Traefik)
                sh "cd ${COMPOSE_DIR} && docker-compose up -d --build"
            }
        }
        stage('Clean') {
            steps {
                sh "docker system prune -f"
            }
        }
    }
}
```

---

## 🔀 4. Zero Downtime Migration Strategy

How to migrate without destroying production (App A):

1. **Setup Shared Network**: Run `docker network create web-gateway` on the server.
2. **Deploy Standalone Traefik**: Spin up `Shared Gateway Service` on a temporary sub-domain or port (e.g., ports 8080/8443) just to test it.
3. **Connect App A**: Modify App A's current docker-compose to connect to `web-gateway` and apply Traefik labels.
4. **The Switch**: 
    - Shut down the old Traefik inside App A.
    - Change the new standalone Traefik to port 80/443. 
    - App A is now safely decoupled and running behind the new gateway.
5. **Deploy App B Components**: Run pipelines for App B Backend and App B Frontend independently. Traefik will automatically route to them.
