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
# Esperar a que el dominio resuelva (DC puede tardar ~20 min)
for i in $(seq 1 60); do host -t SRV _ldap._tcp."$DOMAIN" "$DCIP" && break; sleep 30; done
# Unir
echo "$ADMINPASS" | realm join --user=DomainJoin "$DOMAIN" 2>&1 | tee /var/log/realm-join.log
pam-auth-update --enable mkhomedir 2>/dev/null || true
realm permit --all 2>/dev/null || true
echo "linux-join done" > /var/log/prov.done
