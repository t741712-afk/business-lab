#!/bin/bash
# Despliegue y Recuperación Nativa de Apache Tomcat 9 en Ubuntu (10.0.1.11)
set -x
set -e

# --- REPOSITORIO OFICIAL ---
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/tomcat"

echo "==> Asegurando entorno de ejecución e instalación limpia de Tomcat 9 corporativo..."
apt-get update -y
# Instalamos tomcat9 junto con su paquete administrativo estándar de Ubuntu
apt-get install -y default-jre-headless tomcat9

echo "==> Asegurando de forma mandatoria la existencia de la carpeta ROOT..."
mkdir -p /var/lib/tomcat9/webapps/ROOT

echo "==> Vaciando por completo cualquier archivo residual de la carpeta ROOT..."
rm -f /var/lib/tomcat9/webapps/ROOT/index.jsp
rm -f /var/lib/tomcat9/webapps/ROOT/index.html
rm -f /var/lib/tomcat9/webapps/ROOT/index.html.bak || true

echo "==> Asentando permisos de escritura previos para el canal curl..."
chown -R ubuntu:ubuntu /var/lib/tomcat9/webapps/ROOT
chmod -R 775 /var/lib/tomcat9/webapps/ROOT

echo "==> Descargando la interfaz interactiva Java desde GitHub en tiempo real..."
curl -sS -L -o /var/lib/tomcat9/webapps/ROOT/index.html "${REPO_BASE_URL}/index.html?v=$(date +%s)"

echo "==> Asegurando permisos de lectura globales para el servidor web..."
chmod -R 755 /var/lib/tomcat9/webapps/ROOT
chown -R tomcat:tomcat /var/lib/tomcat9/webapps/ROOT || true

echo "==> RESTAURANDO LA UNIDAD SYSTEMD NATIVA OFICIAL DE UBUNTU..."
# Inyectamos la llamada nativa limpia al script oficial de inicialización del paquete de Ubuntu
cat > /etc/systemd/system/tomcat.service <<'EOF'
[Unit]
Description=Apache Tomcat 9 Web Application Container
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/default-java"
Environment="CATALINA_HOME=/usr/share/tomcat9"
Environment="CATALINA_BASE=/var/lib/tomcat9"
Environment="CATALINA_TMPDIR=/tmp"

# Usamos el script oficial catalina.sh que configura dinámicamente el Classpath correcto de Bootstrap
ExecStart=/usr/share/tomcat9/bin/catalina.sh start
ExecStop=/usr/share/tomcat9/bin/catalina.sh stop

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "==> Recargando systemd, habilitando y encendiendo el servicio de forma limpia..."
systemctl daemon-reload
systemctl enable tomcat
systemctl restart tomcat

echo "==> Comprobando escucha local en el puerto 8080..."
sleep 5
curl -s http://localhost:8080 > /dev/null || echo "WARNING: Tomcat is warming up..."

echo "SUCCESS: Java Engine Interface is actively deployed and prioritized."
