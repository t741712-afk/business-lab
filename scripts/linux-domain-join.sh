#!/bin/bash
# Servidor Linux unido al dominio AD (Ubuntu) via realmd/SSSD.
set -x
export DEBIAN_FRONTEND=noninteractive
DOMAIN="${DOMAIN:-corp.local}"
DCIP="${DCIP:-10.0.3.10}"
ADMINPASS="${ADMINPASS:-BusinessLab#2026}"
apt-get update -y
apt-get install -y realmd sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit krb5-user
# DNS -> DC
sed -i "s/^#\?DNS=.*/DNS=${DCIP}/" /etc/systemd/resolved.conf 2>/dev/null || true
echo -e "[main]\ndns=none" > /etc/NetworkManager/conf.d/dns.conf 2>/dev/null || true
resolvectl dns "$(ip route show default | awk '{print $5; exit}')" "$DCIP" 2>/dev/null || true
echo "nameserver ${DCIP}" > /etc/resolv.conf
timedatectl set-ntp true
# Esperar a que el DC acepte conexiones LDAP. El registro SRV aparece antes de que NTDS esté listo,
# por eso no basta con comprobarlo (puede tardar ~20-30 min en un despliegue limpio)
for i in $(seq 1 60); do
  if host -t SRV _ldap._tcp."$DOMAIN" "$DCIP" >/dev/null 2>&1 && timeout 3 bash -c "</dev/tcp/${DCIP}/389" 2>/dev/null; then
    break
  fi
  sleep 30
done
# Kerberos necesita nombres, no IPs: sin esto, la resolución inversa de la IP del DC devuelve
# el nombre de AWS (ip-10-0-3-10.ec2.internal, que cloud-init añade a /etc/hosts) y el ticket de LDAP
# no existe en el KDC. Se ejecuta antes de cada intento, porque el registro SRV del DC aún no existe al principio.
# realmd elige cualquiera de los DC que responda (puede ser DC2), así que se añaden todos.
# Se borra antes cualquier línea previa de cada IP, porque la resolución inversa usa la primera que coincida.
add_dc_names() {
  for target in $(host -t SRV _ldap._tcp."$DOMAIN" 2>/dev/null | awk '{print $NF}' | sed 's/\.$//'); do
    dc_ip="$(host -t A "$target" 2>/dev/null | awk '/has address/{print $NF}' | head -1)"
    if [ -n "$dc_ip" ]; then
      sed -i "/^${dc_ip}[[:space:]]/d" /etc/hosts
      echo "$dc_ip $target" >> /etc/hosts
    fi
  done
  MY_IP="$(hostname -I | awk '{print $1}')"
  MY_NAME="$(hostname)"
  grep -q "$MY_NAME.$DOMAIN" /etc/hosts || echo "$MY_IP $MY_NAME.$DOMAIN $MY_NAME" >> /etc/hosts
}
# Unir con reintentos: el primer intento puede fallar aunque el DC responda
JOINED=false
for i in $(seq 1 10); do
  add_dc_names
  if echo "$ADMINPASS" | realm join --user=DomainJoin "$DOMAIN" 2>&1 | tee -a /var/log/realm-join.log; then
    realm list | grep -q "$DOMAIN" && JOINED=true && break
  fi
  echo "Intento de union $i fallido, reintentando en 60 s..." | tee -a /var/log/realm-join.log
  sleep 60
done
if [ "$JOINED" != true ]; then
  echo "ERROR: no se pudo unir a ${DOMAIN}. Revisa /var/log/realm-join.log" > /var/log/prov.error
  exit 1
fi
pam-auth-update --enable mkhomedir 2>/dev/null || true
realm permit --all 2>/dev/null || true

# VULNERABILIDAD (sudo mal configurado): cuenta de soporte que puede abrir un editor como root sin contraseña
apt-get install -y vim
id itsupport &>/dev/null || useradd -m -s /bin/bash itsupport
echo "itsupport:Support#2026" | chpasswd
echo "itsupport ALL=(root) NOPASSWD: /usr/bin/vim" > /etc/sudoers.d/itsupport
chmod 440 /etc/sudoers.d/itsupport

echo "linux-join done" > /var/log/prov.done
