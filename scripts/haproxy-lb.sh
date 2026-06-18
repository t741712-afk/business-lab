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
    stats enable
    stats uri /haproxy?stats
backend web_farm
    balance roundrobin
    server web1 10.0.0.31:80 check
    server wordpress 10.0.0.32:80 check
    server apache 10.0.0.33:80 check
EOF
systemctl enable --now haproxy
echo "haproxy ready" > /var/log/prov.done
