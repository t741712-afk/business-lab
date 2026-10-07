#!/bin/bash
# Frontal Apache + PHP (Amazon Linux 2023) con una app PHP de ejemplo.
set -x
dnf -y update
dnf -y install httpd php php-mysqlnd
cat > /var/www/html/index.php <<'EOF'
<?php
echo "<!doctype html><html><head><meta charset='utf-8'><title>Apache PHP</title>";
echo "<style>body{font-family:system-ui;background:#1b3a1b;color:#eaffea;margin:2rem}</style></head><body>";
echo "<h1>Apache + PHP &mdash; ".gethostname()."</h1>";
echo "<p>Fecha servidor: ".date('Y-m-d H:i:s')."</p>";
echo "<p>PHP ".phpversion()."</p>";
echo "<h2>phpinfo (resumen)</h2><pre>";
echo "SERVER_ADDR: ".($_SERVER['SERVER_ADDR']??'?')."\n";
echo "HTTP_HOST:   ".($_SERVER['HTTP_HOST']??'?')."\n";
echo "</pre><p><a href='/info.php'>info.php</a></p></body></html>";
EOF
echo "<?php phpinfo();" > /var/www/html/info.php
systemctl enable --now httpd
echo "apache-php ready" > /var/log/prov.done
