#!/bin/bash
# Host de contenedores (Amazon Linux): Docker + varios microservicios de ejemplo.
set -x
dnf -y update
dnf -y install docker
systemctl enable --now docker
usermod -aG docker ec2-user || true
# Microservicios de ejemplo (publican puertos al host)
docker run -d --restart unless-stopped --name web    -p 8081:80   nginx:alpine
docker run -d --restart unless-stopped --name api    -p 8082:80   kennethreitz/httpbin
docker run -d --restart unless-stopped --name cache  -p 6380:6379 redis:7-alpine
docker run -d --restart unless-stopped --name whoami -p 8083:80   traefik/whoami
echo "docker host ready" > /var/log/prov.done
