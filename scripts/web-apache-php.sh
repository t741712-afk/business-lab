#!/bin/bash
# Frontal Apache + PHP Corporativo (Amazon Linux 2023)
set -x
set -e

# --- REPOSITORIO OFICIAL ---
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/apache"

echo "==> Actualizando el sistema e instalando dependencias..."
dnf -y update
dnf -y install httpd php php-mysqlnd curl

echo "==> Limpiando el directorio web raiz..."
rm -rf /var/www/html/*

echo "==> Descargando la aplicacion web corporativa desde GitHub..."
# Descarga de index.php corporativo
curl -sS -L -o /var/www/html/index.php "${REPO_BASE_URL}/index.php"

# Descarga de info.php de diagnostico
curl -sS -L -o /var/www/html/info.php "${REPO_BASE_URL}/info.php"

# --- CONTROL DE FALLAS (FALLBACK) ---
# Validamos que index.php no este vacio o corrupto por un error de red
if [ ! -s /var/www/html/index.php ]; then
    echo "ERROR: No se pudo descargar desde el repositorio. Aplicando contingencia local..."
    cat > /var/www/html/index.php <<'EOF'
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>Laboratories Corporation TAI - Contingencia</title></head>
<body style="font-family:sans-serif; background:#0F172A; color:white; text-align:center; padding-top:10%;">
    <h1>LABORATORIES CORPORATION TAI</h1>
    <p>Modo de contingencia activo. Error de comunicacion con el repositorio de despliegue.</p>
</body>
</html>
EOF
fi

echo "==> Ajustando permisos de la carpeta web para Apache..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

echo "==> Iniciando y habilitando el servicio de Apache..."
systemctl enable --now httpd

echo "apache-php corporate ready" > /var/log/prov.done
