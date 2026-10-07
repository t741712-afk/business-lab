#!/bin/bash
# Intranet corporativa (Amazon Linux): httpd + portal interno de ejemplo.
set -x
dnf -y update
dnf -y install httpd
cat > /var/www/html/index.html <<'EOF'
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Intranet Corp</title>
<style>body{font-family:system-ui;margin:0;background:#2a2a2a;color:#eee}
nav{background:#444;padding:1rem}nav a{color:#9cf;margin-right:1rem}
.wrap{max-width:800px;margin:2rem auto;padding:1rem}</style></head>
<body><nav><a href="#">Inicio</a><a href="#">RRHH</a><a href="#">IT</a><a href="#">Finanzas</a></nav>
<div class="wrap"><h1>Intranet de la empresa</h1>
<p>Portal interno. Solo accesible desde la red corporativa (MZ).</p>
<ul><li>Solicitudes de vacaciones</li><li>Tickets de soporte IT</li>
<li>Directorio de empleados (LDAP)</li><li>Compartido de ficheros: \\\\10.0.3.12\\Public</li></ul>
</div></body></html>
EOF
systemctl enable --now httpd
echo "intranet ready" > /var/log/prov.done
