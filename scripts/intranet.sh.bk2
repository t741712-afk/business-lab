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
