#!/bin/bash
# Servidor de correo interno (Ubuntu): Postfix (SMTP) + Dovecot (IMAP/POP3).
set -x
export DEBIAN_FRONTEND=noninteractive
DOMAIN="${DOMAIN:-corp.local}"
debconf-set-selections <<< "postfix postfix/mailname string ${DOMAIN}"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get update -y
apt-get install -y postfix dovecot-imapd dovecot-pop3d mailutils
postconf -e "myhostname = mail.${DOMAIN}"
postconf -e "mydestination = mail.${DOMAIN}, ${DOMAIN}, localhost"
postconf -e "mynetworks = 10.0.0.0/16 127.0.0.0/8"
postconf -e "home_mailbox = Maildir/"
# Usuarios de buzon de ejemplo
for u in jgarcia mlopez afernandez; do
  id "$u" &>/dev/null || useradd -m -s /usr/sbin/nologin "$u"
  echo "${u}:Mail#2026" | chpasswd
done
systemctl enable --now postfix dovecot
echo "mail ready" > /var/log/prov.done
