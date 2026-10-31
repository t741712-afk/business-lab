#!/bin/bash
# App PHP-FPM + Nginx (Amazon Linux) con una mini-app de gestion de ejemplo.
set -x
dnf -y update
dnf -y install nginx php-fpm php-mysqlnd
cat > /usr/share/nginx/html/index.php <<'EOF'
<?php
$items = ["Pedido #1001 - OK","Pedido #1002 - Pendiente","Pedido #1003 - Enviado"];
echo "<!doctype html><html><head><meta charset='utf-8'><title>App PHP-FPM</title>";
echo "<style>body{font-family:system-ui;background:#3a2a10;color:#ffeacc;margin:2rem}</style></head><body>";
echo "<h1>Gestion de pedidos (PHP-FPM)</h1><p>Host: ".gethostname()."</p><ul>";
foreach($items as $i){ echo "<li>$i</li>"; }
echo "</ul></body></html>";
EOF
systemctl enable --now php-fpm nginx
echo "php-fpm ready" > /var/log/prov.done
