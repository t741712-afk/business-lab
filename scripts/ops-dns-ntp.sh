#!/bin/bash
# Servicios base: DNS recursivo (dnsmasq) + NTP (chrony) para la red Ops.
set -x
dnf -y update
dnf -y install dnsmasq chrony
cat > /etc/dnsmasq.d/corp.conf <<'EOF'
domain-needed
bogus-priv
# Reenvio del dominio interno al DC, resto a AWS
server=/corp.local/10.0.3.10
server=169.254.169.253
listen-address=0.0.0.0
EOF
systemctl enable --now dnsmasq chronyd
echo "dns-ntp ready" > /var/log/prov.done
