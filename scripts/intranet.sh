#!/bin/bash
# Intranet corporativa (Amazon Linux 2023): httpd + Descarga automatizada desde GitHub (IaC)
set -x
set -e

# --- REPOSITORIO OFICIAL ---
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/intranet"

echo "==> Actualizando el sistema operativo e instalando Apache httpd..."
dnf -y update
dnf -y install httpd

echo "==> Creando el directorio web raiz si no existiera..."
mkdir -p /var/www/html

echo "==> Descargando el archivo index.html limpio desde GitHub en tiempo real..."
# Forzamos saltar caches de GitHub usando la marca de tiempo ?v=
curl -sS -L -o /var/www/html/index.html "${REPO_BASE_URL}/index.html?v=$(date +%s)"

# VULNERABILIDAD (exposicion de copias de seguridad): /backup con listado de directorio
# y un fichero de configuracion con credenciales de la base de datos
echo "==> Publicando copias de seguridad antiguas (listado de directorio activo)..."
mkdir -p /var/www/html/backup
cat > /var/www/html/backup/intranet-config.bak <<'EOF'
# TAI Intranet - configuracion de respaldo (copia anterior a la migracion de 2026)
DB_ENGINE=mysql
DB_HOST=10.0.2.11
DB_NAME=empresa
DB_USER=app
DB_PASS=App#2026
APP_DEBUG=False
SECRET_KEY=kb7X2qP0tRz9LmW4cVn8sYj1
EOF
cat > /var/www/html/backup/README.txt <<'EOF'
Backups of the intranet configuration. Restore before the next release.
EOF
cat > /var/www/html/robots.txt <<'EOF'
User-agent: *
Disallow: /backup/
EOF
cat > /etc/httpd/conf.d/intranet-backup.conf <<'EOF'
<Directory "/var/www/html/backup">
    Options +Indexes
    Require all granted
</Directory>
EOF

echo "==> Ajustando permisos para el usuario de Apache (httpd)..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

echo "==> Esperando el asentamiento de archivos en disco..."
sleep 2

echo "==> Iniciando y forzando REINICIO DURO de httpd para limpiar cache RAM..."
systemctl enable httpd
systemctl stop httpd
sleep 1
systemctl start httpd

echo "intranet ready" > /var/log/prov.done
