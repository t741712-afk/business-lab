#!/bin/bash
# API REST Avanzada de TAI Labs - Desacoplada desde GitHub (Amazon Linux 2023)
set -x
set -e

REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/api"

echo "==> Asegurando entorno de ejecucion (Sin forzar el conflicto de curl)..."
# Eliminamos "curl" de la lista; nodejs y npm instalaran limpiamente sin chocar con curl-minimal
dnf -y install nodejs npm

echo "==> Preparando el directorio de la aplicacion..."
mkdir -p /opt/api

echo "==> Descargando server.js limpio desde GitHub en tiempo real..."
curl -sS -L -o /opt/api/server.js "${REPO_BASE_URL}/server.js?v=$(date +%s)"

echo "==> Creando el archivo de servicio systemd para control y persistencia..."
cat > /etc/systemd/system/corp-api.service <<'EOF'
[Unit]
Description=Laboratories Corporation TAI Node API Advanced
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/api/server.js
Restart=always
User=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "==> Recargando systemd, habilitando y forzando el REINICIO del proceso..."
systemctl daemon-reload
systemctl enable corp-api
systemctl restart corp-api

echo "==> Comprobando ejecucion local en el puerto 3000..."
sleep 2
curl -s http://localhost:3000

echo "node-api corporate ready" > /var/log/prov.done
