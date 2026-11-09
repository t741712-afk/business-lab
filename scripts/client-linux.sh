#!/bin/bash
# Workstation Linux (Ubuntu) con escritorio XFCE + herramientas de cliente.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y xfce4 xrdp firefox openssh-client remmina filezilla
systemctl enable --now xrdp
adduser --disabled-password --gecos "" labuser || true
echo "labuser:Lab#2026" | chpasswd
usermod -aG sudo labuser

# VULNERABILIDAD (escalada de privilegios): tarea de sincronizacion que ejecuta root cada 2 minutos,
# pero el script que ejecuta esta en una carpeta que labuser puede modificar
mkdir -p /opt/tai-sync
cat > /opt/tai-sync/sync.sh <<'SYNC'
#!/bin/bash
# Sincronizacion de documentos del puesto con el servidor de ficheros (registro de ejecucion)
echo "$(date -u +%FT%TZ) sync ok" >> /var/log/tai-sync.log
SYNC
chmod 755 /opt/tai-sync/sync.sh
chown -R labuser:labuser /opt/tai-sync
cat > /etc/cron.d/tai-sync <<'CRON'
*/2 * * * * root /opt/tai-sync/sync.sh
CRON
chmod 644 /etc/cron.d/tai-sync

echo "linux-client ready" > /var/log/prov.done
