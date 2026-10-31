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
# VULNERABILIDAD (informacion sensible en el jump host): nota de traspaso del equipo de
# operaciones con credenciales de servicios internos. Solo util tras obtener acceso al bastion.
mkdir -p /home/ec2-user/notes
cat > /home/ec2-user/notes/handover-ops.txt <<'EOF'
TAI LABORATORIES - OPS HANDOVER (internal, do not forward)
Owner: Operations team, Berlin HQ

Pending items before the Q4 audit:
  - Java deployment portal: http://tomcat.tai-internal.local:8080/manager/html
    deployer / Deploy#2026  (manager-gui, manager-script)
  - Order portal database: mysql.tai-internal.local, user app / App#2026
  - Intranet backups are kept under /backup on the intranet host
  - DNS zone tai-internal.local is still on the old resolver, pending review

Remember to rotate the shared passwords once the audit is closed.
EOF
chown -R ec2-user:ec2-user /home/ec2-user/notes

echo "bastion ready" > /var/log/prov.done
