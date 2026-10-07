#!/bin/bash
# App server Java: Tomcat 9 (Ubuntu) con app de ejemplo desplegada.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y tomcat9 tomcat9-admin
# App de ejemplo (JSP)
mkdir -p /var/lib/tomcat9/webapps/ROOT
cat > /var/lib/tomcat9/webapps/ROOT/index.jsp <<'EOF'
<%@ page contentType="text/html;charset=UTF-8" %>
<html><head><title>App Java (Tomcat)</title></head>
<body style="font-family:system-ui;background:#102a43;color:#dbeafe;margin:2rem">
<h1>Servicio de negocio (Java / Tomcat)</h1>
<p>Host: <%= java.net.InetAddress.getLocalHost().getHostName() %></p>
<p>Fecha: <%= new java.util.Date() %></p>
<p>Backend de aplicacion corporativa, escuchando en :8080</p>
</body></html>
EOF
systemctl enable --now tomcat9
echo "tomcat ready" > /var/log/prov.done
