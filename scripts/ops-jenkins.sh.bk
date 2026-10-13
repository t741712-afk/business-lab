#!/bin/bash
# CI: Jenkins (Ubuntu) via Docker, escuchando en :8080.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io
systemctl enable --now docker
docker volume create jenkins_home 2>/dev/null || true
docker run -d --restart unless-stopped --name jenkins -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts-jdk17
echo "Jenkins arrancando. Password inicial:" > /var/log/prov.done
echo "  docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword" >> /var/log/prov.done
