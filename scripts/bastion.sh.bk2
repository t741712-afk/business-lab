#!/bin/bash
# Bastion / jump host (Amazon Linux 2023). Herramientas de salto y diagnostico.
set -x
dnf -y update
dnf -y install nmap-ncat tmux git jq bind-utils nc telnet socat tcpdump htop
# Mensaje de bienvenida
cat > /etc/motd <<'EOF'
============================================================
  BUSINESS-LAB  ·  BASTION (DMZ)
  Punto de entrada. Desde aqui salta a la red interna (MZ):
    ssh ubuntu@10.0.1.x  /  rdp 10.0.3.x  (via tunel)
============================================================
EOF
echo "bastion ready" > /var/log/prov.done
