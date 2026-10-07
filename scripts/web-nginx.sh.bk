#!/bin/bash
# Frontal web Nginx (Ubuntu 22.04) + pequena SPA estatica + API health.
set -x
export DEBIAN_FRONTEND=noninteractive
SITE="${SITE:-corp-portal}"
apt-get update -y
apt-get install -y nginx
cat > /var/www/html/index.html <<EOF
<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>${SITE}</title>
<style>body{font-family:system-ui;margin:0;background:#0b1f3a;color:#eaf2ff}
header{background:#12305e;padding:2rem;text-align:center}
.card{max-width:760px;margin:2rem auto;background:#13294b;padding:2rem;border-radius:12px}
code{background:#0b1f3a;padding:.2rem .4rem;border-radius:4px}</style></head>
<body><header><h1>Corp Portal &mdash; ${SITE}</h1>
<p>Frontal Nginx (Ubuntu) &middot; $(hostname)</p></header>
<div class="card"><h2>Servicios</h2><ul>
<li>Backend API: <code>http://10.0.1.12:3000</code> (Node)</li>
<li>App Java: <code>http://10.0.1.11:8080</code> (Tomcat)</li>
<li>Intranet: <code>http://10.0.3.14</code></li>
</ul><p>Health endpoint: <a href="/health">/health</a></p></div></body></html>
EOF
echo '{"status":"ok","host":"'"$(hostname)"'"}' > /var/www/html/health
systemctl enable --now nginx
echo "nginx ready" > /var/log/prov.done
