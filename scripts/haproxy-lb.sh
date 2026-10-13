#!/bin/bash
# Balanceador HAProxy (Amazon Linux 2023). Reparte HTTP a los frontales nginx.
set -x
dnf -y update
dnf -y install haproxy
cat > /etc/haproxy/haproxy.cfg <<'EOF'
global
    log /dev/log local0
    maxconn 2000
defaults
    mode http
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    log global
    option httplog
frontend http_in
    bind *:80
    default_backend web_farm
    
    # -------------------------------------------------------------------------
    # VULNERABILIDAD 1: Panel de estadísticas expuesto y con control total (Riesgo Alto)
    # -------------------------------------------------------------------------
    stats enable
    stats uri /haproxy?stats
    stats refresh 5s
    stats admin if TRUE  # VULNERABILIDAD: Permite a cualquiera deshabilitar nodos de la granja web sin contraseña

backend web_farm
    balance roundrobin
    
    # -------------------------------------------------------------------------
    # VULNERABILIDAD 2: No se sanitizan ni se fuerzan las cabeceras de origen reales
    # -------------------------------------------------------------------------
    # En un entorno seguro se usaría "option forwardfor". Al no estar, el atacante puede
    # falsificar su IP de origen inyectando cabeceras personalizadas hacia los servidores web.
    
    server web1 10.0.0.33:80 check
    server web2 10.0.0.34:80 check
EOF
systemctl enable --now haproxy
echo "haproxy ready" > /var/log/prov.done