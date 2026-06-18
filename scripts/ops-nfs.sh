#!/bin/bash
# Almacenamiento compartido: servidor NFS (Amazon Linux) para backups del lab.
set -x
dnf -y update
dnf -y install nfs-utils
mkdir -p /export/backups /export/shared
chmod 777 /export/backups /export/shared
echo "Backup inicial $(date)" > /export/backups/README.txt
cat > /etc/exports <<'EOF'
/export/backups 10.0.0.0/16(rw,sync,no_subtree_check,no_root_squash)
/export/shared  10.0.0.0/16(rw,sync,no_subtree_check,no_root_squash)
EOF
systemctl enable --now nfs-server
exportfs -ra
echo "nfs ready" > /var/log/prov.done
