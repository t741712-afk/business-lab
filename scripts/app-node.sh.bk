#!/bin/bash
# API REST Node.js (Amazon Linux) gestionada con systemd. Escucha en :3000.
set -x
dnf -y update
dnf -y install nodejs npm
mkdir -p /opt/api
cat > /opt/api/server.js <<'EOF'
const http = require('http');
const os = require('os');
const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url === '/health') return res.end(JSON.stringify({status:'ok'}));
  res.end(JSON.stringify({
    service: 'corp-api', host: os.hostname(),
    time: new Date().toISOString(),
    endpoints: ['/health','/api/empleados','/api/pedidos']
  }));
});
server.listen(3000, () => console.log('API on :3000'));
EOF
cat > /etc/systemd/system/corp-api.service <<'EOF'
[Unit]
Description=Corp Node API
After=network.target
[Service]
ExecStart=/usr/bin/node /opt/api/server.js
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now corp-api
echo "node-api ready" > /var/log/prov.done
