#!/bin/bash
# Servicios base: DNS recursivo (BIND) + NTP (chrony) para la red Ops.
# Endurecido: reintentos de dnf, validacion de configuracion y verificacion del puerto 53.
set -x
for i in $(seq 1 10); do dnf -y install bind bind-utils chrony && break; sleep 15; done

# VULNERABILIDAD (transferencia de zona abierta): allow-transfer permite AXFR a cualquiera,
# por lo que un atacante puede descargar todos los registros de tai-internal.local
cat > /etc/named.conf <<'EOF'
options {
    listen-on port 53 { 10.0.5.11; 127.0.0.1; };
    listen-on-v6 { none; };
    directory "/var/named";
    pid-file "/run/named/named.pid";
    allow-query { any; };
    recursion yes;
    allow-recursion { 10.0.0.0/16; 127.0.0.1; };
    forwarders { 169.254.169.253; };
    dnssec-validation no;
};

# Reenvio del dominio interno al DC
zone "corp.local" {
    type forward;
    forward only;
    forwarders { 10.0.3.10; };
};

# Zona interna de TAI Labs (con transferencia abierta)
zone "tai-internal.local" {
    type primary;
    file "tai-internal.local.zone";
    allow-transfer { any; };
};
EOF

cat > /var/named/tai-internal.local.zone <<'EOF'
$TTL 3600
@       IN  SOA  ns1.tai-internal.local. hostmaster.tai-internal.local. (
                 2026103101 ; serial
                 3600       ; refresh
                 900        ; retry
                 604800     ; expire
                 300 )      ; negative cache TTL
        IN  NS   ns1.tai-internal.local.

; Ops
ns1         IN  A  10.0.5.11
ops-monitor IN  A  10.0.5.12
siem        IN  A  10.0.5.13
backup-old  IN  A  10.0.5.14
jenkins     IN  A  10.0.5.15
; Equipos de la DMZ
bastion     IN  A  10.0.0.10
lb          IN  A  10.0.0.20
nginx       IN  A  10.0.0.31
wordpress   IN  A  10.0.0.32
apache      IN  A  10.0.0.33
apache2     IN  A  10.0.0.34
iis         IN  A  10.0.0.35
monitor     IN  A  10.0.0.40
servicegw   IN  A  10.0.0.75
; App
tomcat      IN  A  10.0.1.11
node-api    IN  A  10.0.1.12
dotnet      IN  A  10.0.1.13
django      IN  A  10.0.1.14
portal      IN  A  10.0.1.15
docker      IN  A  10.0.1.16
; Datos
mysql       IN  A  10.0.2.11
postgres    IN  A  10.0.2.12
mssql       IN  A  10.0.2.13
mongo       IN  A  10.0.2.14
; Corp
dc1         IN  A  10.0.3.10
dc2         IN  A  10.0.3.11
files       IN  A  10.0.3.12
mail        IN  A  10.0.3.13
intranet    IN  A  10.0.3.14
linux-member IN A  10.0.3.15
; Clientes
ws-win01    IN  A  10.0.4.11
ws-win02    IN  A  10.0.4.12
lin-client  IN  A  10.0.4.13
EOF
chown named:named /var/named/tai-internal.local.zone

named-checkconf /etc/named.conf
named-checkzone tai-internal.local /var/named/tai-internal.local.zone

systemctl disable --now dnsmasq 2>/dev/null || true
systemctl enable chronyd
systemctl restart chronyd
systemctl enable --now named
systemctl restart named

# Verificar que named escucha en el 53
if ss -lun 2>/dev/null | grep -q ':53' && ss -ltn 2>/dev/null | grep -q ':53'; then
  echo "dns-ntp ready - named LISTEN :53 OK (corp.local -> 10.0.3.10, tai-internal.local AXFR abierto)" > /var/log/prov.done
else
  echo "WARN: named no escucha en :53 - revisar /etc/named.conf" > /var/log/prov.done
  journalctl -u named --no-pager | tail -20 >> /var/log/prov.done 2>&1
fi
