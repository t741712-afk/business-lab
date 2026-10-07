#!/bin/bash
# Frontal API REST Node.js Corporativa (Amazon Linux 2023) gestionada con systemd. Escucha en :3000.
set -x
set -e

echo "==> Actualizando el sistema operativo e instalando Node.js..."
dnf -y update
dnf -y install nodejs npm

echo "==> Preparando el directorio de la aplicacion..."
mkdir -p /opt/api

echo "==> Escribiendo el codigo de la API biomedica en server.js..."
cat > /opt/api/server.js <<'EOF'
const http = require('http');
const os = require('os');

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  
  if (req.url === '/health') {
    return res.end(JSON.stringify({ status: 'ok' }));
  }
  
  res.end(JSON.stringify({
    status: 'ONLINE',
    service: 'corp-api',
    subsystem: 'AI Molecular Synthesis Engine',
    location: 'Berlin HQ Cluster',
    host: os.hostname(),
    time_utc: new Date().toISOString(),
    metrics: {
      processed_sequences: 145920,
      accuracy_rate: '99.84%',
      gans_status: 'Stable'
    },
    endpoints: ['/health']
  }));
});

server.listen(3000, () => {
  console.log('TAI Labs API Engine active on port 3000');
});
EOF

echo "==> Creando el archivo de servicio systemd para control y persistencia..."
cat > /etc/systemd/system/corp-api.service <<'EOF'
[Unit]
Description=Laboratories Corporation TAI Node API
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/api/server.js
Restart=always
User=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "==> Recargando systemd, habilitando y REINICIANDO el servicio..."
systemctl daemon-reload
systemctl enable corp-api
systemctl restart corp-api # <--- Fuerza la carga del nuevo codigo en memoria

echo "==> Comprobando ejecucion local en el puerto 3000..."
sleep 2
curl -s http://localhost:3000

echo "node-api corporate ready" > /var/log/prov.done
