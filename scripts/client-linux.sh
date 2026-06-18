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
echo "linux-client ready" > /var/log/prov.done
