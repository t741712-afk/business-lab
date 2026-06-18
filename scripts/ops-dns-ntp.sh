#!/bin/bash
# Servicios base: DNS recursivo (dnsmasq) + NTP (chrony) para la red Ops.
# Endurecido: reintentos de dnf, bind-interfaces y verificacion del puerto 53.
set -x
for i in $(seq 1 10); do dnf -y install dnsmasq chrony && break; sleep 15; done

cat > /etc/dnsmasq.d/corp.conf <<'EOF'
domain-needed
bogus-priv
bind-interfaces
listen-address=0.0.0.0,127.0.0.1
# Reenvio del dominio interno al DC, el resto a AWS
server=/corp.local/10.0.3.10
server=169.254.169.253
EOF

systemctl enable dnsmasq chronyd
systemctl restart chronyd
systemctl restart dnsmasq

# Verificar que dnsmasq escucha en el 53
if ss -lun 2>/dev/null | grep -q ':53' && ss -ltn 2>/dev/null | grep -q ':53'; then
  echo "dns-ntp ready - dnsmasq LISTEN :53 OK (corp.local -> 10.0.3.10)" > /var/log/prov.done
else
  echo "WARN: dnsmasq no escucha en :53 - revisar /etc/dnsmasq.d/corp.conf" > /var/log/prov.done
  journalctl -u dnsmasq --no-pager | tail -20 >> /var/log/prov.done 2>&1
fi
