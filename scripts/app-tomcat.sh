#!/bin/bash
# Personalización Definitiva del Servidor Java Apache Tomcat (10.0.1.11) - Desacoplado desde GitHub
set -x
set -e

TOMCAT_ROOT="/var/lib/tomcat9/webapps/ROOT"
TOMCAT_SERVICE="tomcat9"
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/tomcat"

echo "==> Vaciando por completo cualquier archivo residual de la carpeta ROOT..."
# Eliminamos físicamente los ficheros antiguos para que no pisen el nuevo index.html
rm -f /var/lib/tomcat9/webapps/ROOT/index.jsp
rm -f /var/lib/tomcat9/webapps/ROOT/index.html
rm -f /var/lib/tomcat9/webapps/ROOT/index.html.bak || true

echo "==> Descargando la interfaz interactiva Java desde GitHub en tiempo real..."
# Forzamos a Tomcat a descargar la versión fresca saltándose el CDN mediante un timestamp
curl -sS -L -o /var/lib/tomcat9/webapps/ROOT/index.html "${REPO_BASE_URL}/index.html?v=$(date +%s)"

echo "==> Aplicando permisos de seguridad reglamentarios en la carpeta ROOT..."
chown -R tomcat:tomcat /var/lib/tomcat9/webapps/ROOT
chmod -R 755 /var/lib/tomcat9/webapps/ROOT

echo "==> Forzando reinicio limpio del servicio tomcat9 para liberar sockets..."
systemctl restart tomcat9

echo "SUCCESS: Java Engine Interface is actively deployed and prioritized."
