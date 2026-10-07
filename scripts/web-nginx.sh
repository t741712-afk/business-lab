#!/bin/bash
# Frontal web Nginx Corporativo (Ubuntu 22.04)
set -x
set -e

export DEBIAN_FRONTEND=noninteractive

# --- REPOSITORIO OFICIAL ---
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/nginx"

echo "==> Actualizando el sistema operativo..."
apt-get update -y

echo "==> Instalando Nginx y dependencias de red..."
apt-get install -y nginx curl

echo "==> Limpiando el directorio web raiz por defecto..."
rm -rf /var/www/html/*

echo "==> Descargando el panel corporativo y health endpoint desde GitHub..."
# Forzamos la descarga en tiempo real saltando caches mediante un timestamp aleatorio
curl -sS -L -o /var/www/html/index.html "${REPO_BASE_URL}/index.html?v=$(date +%s)"
curl -sS -L -o /var/www/html/health "${REPO_BASE_URL}/health?v=$(date +%s)"

# --- CONTROL DE FALLAS (FALLBACK) ---
if [ ! -s /var/www/html/index.html ]; then
    echo "ERROR: Fallo al descargar de GitHub. Inyectando panel local de contingencia..."
    cat > /var/www/html/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head><title>TAI Labs - Emergency Gateway</title></head>
<body style="font-family:sans-serif; background:#090D16; color:white; text-align:center; padding-top:10%;">
    <h1>LABORATORIES CORPORATION TAI</h1>
    <p>Operations Gateway - Emergency Contingency Mode Active.</p>
</body>
</html>
EOF
fi

echo "==> Configurando permisos correctos para Nginx (www-data)..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "==> Iniciando y habilitando Nginx..."
systemctl enable --now nginx

echo "nginx corporate ready" > /var/log/prov.done