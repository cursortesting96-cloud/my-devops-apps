provider "aws" {
  region = var.aws_region
}

# 1. Security Group
resource "aws_security_group" "devops_sg" {
  name        = "devops-gateway-sg"
  description = "Allow HTTP, HTTPS and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # HTTP
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # HTTPS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. EC2 Instance
resource "aws_instance" "devops_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  tags = {
    Name = "DevOps-Gateway-Server"
  }

  # Auto-install Docker & Deploy All Services
  user_data = <<-EOF
              #!/bin/bash
              # 1. Install Docker and Docker Compose
              curl -fsSL https://get.docker.com -o get-docker.sh
              sudo sh get-docker.sh
              sudo usermod -aG docker ubuntu
              
              sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose
              
              # 2. Setup Infrastructure
              sudo docker network create web-gateway || true
              sudo mkdir -p /opt/infrastructure/{gateway,app-a,app-b-backend,app-b-frontend}

              # 3. Create Gateway Config (Traefik)
              cat << 'INNEREOF' | sudo tee /opt/infrastructure/gateway/docker-compose.yml
              version: '3.8'
              services:
                traefik:
                  image: traefik:latest
                  container_name: shared-gateway
                  restart: unless-stopped
                  environment:
                    DOCKER_API_VERSION: "1.41"
                  ports:
                    - "80:80"
                    - "443:443"
                  command:
                    - "--api.insecure=true"
                    - "--providers.docker=true"
                    - "--providers.docker.exposedbydefault=false"
                    - "--entrypoints.web.address=:80"
                  volumes:
                    - "/var/run/docker.sock:/var/run/docker.sock:ro"
                  networks:
                    - web-gateway
              networks:
                web-gateway:
                  external: true
              INNEREOF

              # 4. Create App A
              echo "<h1>App A - Legacy Service</h1>" | sudo tee /opt/infrastructure/app-a/index.html
              cat << 'INNEREOF' | sudo tee /opt/infrastructure/app-a/docker-compose.yml
              version: '3.8'
              services:
                app-a-web:
                  image: nginx:alpine
                  container_name: app-a-web
                  volumes:
                    - ./index.html:/usr/share/nginx/html/index.html:ro
                  labels:
                    - "traefik.enable=true"
                    - "traefik.http.routers.app-a.rule=Host(`app-a.test`)"
                    - "traefik.http.routers.app-a.entrypoints=web"
                    - "traefik.http.services.app-a.loadbalancer.server.port=80"
                  networks:
                    - web-gateway
              networks:
                web-gateway:
                  external: true
              INNEREOF

              # 5. Create App B Backend 
              echo '{"status": "success", "message": "Backend API is working!", "data": []}' | sudo tee /opt/infrastructure/app-b-backend/index.json
              cat << 'INNEREOF' | sudo tee /opt/infrastructure/app-b-backend/docker-compose.yml
              version: '3.8'
              services:
                app-b-api:
                  image: nginx:alpine
                  container_name: app-b-backend
                  volumes:
                    - ./index.json:/usr/share/nginx/html/index.json:ro
                  labels:
                    - "traefik.enable=true"
                    - "traefik.http.routers.app-b-api.rule=Host(`api.app-b.test`)"
                    - "traefik.http.routers.app-b-api.entrypoints=web"
                    - "traefik.http.services.app-b-api.loadbalancer.server.port=80"
                  networks:
                    - web-gateway
              networks:
                web-gateway:
                  external: true
              INNEREOF

              # 6. Create App B Frontend
              echo "<h1>App B - Modern Frontend </h1>" | sudo tee /opt/infrastructure/app-b-frontend/index.html
              cat << 'INNEREOF' | sudo tee /opt/infrastructure/app-b-frontend/docker-compose.yml
              version: '3.8'
              services:
                app-b-ui:
                  image: nginx:alpine
                  container_name: app-b-frontend
                  volumes:
                    - ./index.html:/usr/share/nginx/html/index.html:ro
                  labels:
                    - "traefik.enable=true"
                    - "traefik.http.routers.app-b-ui.rule=Host(`app-b.test`)"
                    - "traefik.http.routers.app-b-ui.entrypoints=web"
                    - "traefik.http.services.app-b-ui.loadbalancer.server.port=80"
                  networks:
                    - web-gateway
              networks:
                web-gateway:
                  external: true
              INNEREOF

              # 7. Start ALL Services
              cd /opt/infrastructure/gateway && sudo docker-compose up -d
              cd /opt/infrastructure/app-a && sudo docker-compose up -d
              cd /opt/infrastructure/app-b-backend && sudo docker-compose up -d
              cd /opt/infrastructure/app-b-frontend && sudo docker-compose up -d
              EOF

}
