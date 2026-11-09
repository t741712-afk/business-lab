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
# VULNERABILIDAD (enumeracion de usuarios): el comando VRFY responde si una cuenta existe
postconf -e "disable_vrfy_command = no"
# Usuarios de buzon de ejemplo
for u in jgarcia mlopez afernandez; do
  id "$u" &>/dev/null || useradd -m -s /usr/sbin/nologin "$u"
  echo "${u}:Mail#2026" | chpasswd
done
# VULNERABILIDAD (informacion sensible en correo): el buzon de jgarcia contiene un correo del equipo de
# soporte con las credenciales de la cuenta de copias de seguridad
mkdir -p /home/jgarcia/Maildir/{cur,new,tmp}
cat > "/home/jgarcia/Maildir/cur/1700000000.M1P1.mail:2,S" <<MAIL
Return-Path: <helpdesk@corp.local>
Delivered-To: jgarcia@corp.local
From: IT Helpdesk <helpdesk@corp.local>
To: jgarcia@corp.local
Subject: Backup share access for the audit
Date: $(date -R)
Message-ID: <backup-access-01@mail.corp.local>
Content-Type: text/plain; charset=UTF-8

Juan,

As agreed for the audit, the backup share on the file server uses the service account below.
Please do not forward this message.

  Account:  CORP\svc-backup
  Password: Backup2026!
  Share:    \\\\fileserver.corp.local\Public

Regards,
IT Helpdesk
MAIL
chown -R jgarcia:jgarcia /home/jgarcia/Maildir
chmod 700 /home/jgarcia/Maildir

systemctl enable --now postfix dovecot
echo "mail ready" > /var/log/prov.done
