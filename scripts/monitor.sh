#!/bin/bash
# =============================================================================
# MONITOR (DMZ 10.0.0.40) - Vigila los servicios de TODAS las maquinas del lab.
#   Prometheus + Blackbox Exporter + Grafana (Docker).
#   Sondas: HTTP (curl), TCP (puerto), ICMP (ping), DNS.
#   probe_success == 1  -> servicio ARRIBA ;  == 0 -> CAIDO (dispara alerta).
# Acceso: Grafana http://<IP-monitor>:3000  ·  Prometheus http://<IP-monitor>:9090
# =============================================================================
set -x
GF_PASS="${GF_PASS:-Monitor#2026}"
dnf -y update
dnf -y install docker
systemctl enable --now docker

mkdir -p /opt/mon/prometheus /opt/mon/blackbox \
         /opt/mon/grafana/provisioning/datasources \
         /opt/mon/grafana/provisioning/dashboards \
         /opt/mon/grafana/dashboards

# --- Blackbox: modulos de sonda --------------------------------------------
cat > /opt/mon/blackbox/blackbox.yml <<'EOF'
modules:
  http_2xx:
    prober: http
    timeout: 8s
    http:
      preferred_ip_protocol: ip4
      valid_status_codes: [200,201,204,301,302,401,403]   # "responde" = arriba
      fail_if_not_ssl: false
  tcp_connect:
    prober: tcp
    timeout: 6s
    tcp:
      preferred_ip_protocol: ip4
  icmp:
    prober: icmp
    timeout: 6s
    icmp:
      preferred_ip_protocol: ip4
  dns_corp:
    prober: dns
    timeout: 6s
    dns:
      preferred_ip_protocol: ip4
      query_name: corp.local
      query_type: A
EOF

# --- Prometheus: alertas ----------------------------------------------------
cat > /opt/mon/prometheus/alert.rules.yml <<'EOF'
groups:
  - name: servicios
    rules:
      - alert: ServicioCaido
        expr: probe_success == 0
        for: 1m
        labels: { severity: critical }
        annotations:
          summary: "Servicio CAIDO: {{ $labels.instance }} ({{ $labels.job }})"
EOF

# --- Prometheus: config + targets (TODOS los servicios del lab) -------------
cat > /opt/mon/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 30s
  evaluation_interval: 30s
rule_files:
  - /etc/prometheus/alert.rules.yml

scrape_configs:
  # ----- Prometheus a si mismo -----
  - job_name: prometheus
    static_configs: [{ targets: ['localhost:9090'] }]

  # ===== HTTP (curl) =====
  - job_name: http
    metrics_path: /probe
    params: { module: [http_2xx] }
    static_configs:
      - targets:
          - http://10.0.0.20         # LB HAProxy
          - http://10.0.0.31         # nginx-1
          - http://10.0.0.32         # wordpress
          - http://10.0.0.33         # apache-php
          - http://10.0.0.34         # IIS
          - http://10.0.1.11:8080    # tomcat
          - http://10.0.1.12:3000    # node API
          - http://10.0.1.13         # dotnet/IIS
          - http://10.0.1.14:8000    # django
          - http://10.0.1.15         # php-fpm
          - http://10.0.1.16:8081    # docker nginx
          - http://10.0.1.16:8082    # docker httpbin
          - http://10.0.1.16:8083    # docker whoami
          - http://10.0.3.14         # intranet
          - http://10.0.5.12:3000    # grafana (ops MZ)
          - http://10.0.5.12:9090    # prometheus (ops MZ)
          - http://10.0.5.13:9200    # elasticsearch
          - http://10.0.5.13:5601    # kibana
          - http://10.0.5.15:8080    # jenkins
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115

  # ===== TCP (puerto abierto) =====
  - job_name: tcp
    metrics_path: /probe
    params: { module: [tcp_connect] }
    static_configs:
      - targets:
          - 10.0.0.10:22       # bastion ssh
          - 10.0.2.11:3306     # mysql
          - 10.0.2.12:5432     # postgres
          - 10.0.2.13:1433     # mssql
          - 10.0.2.14:27017    # mongodb
          - 10.0.2.14:6379     # redis
          - 10.0.1.16:6380     # redis docker
          - 10.0.3.10:389      # LDAP DC1
          - 10.0.3.10:445      # SMB DC1
          - 10.0.3.11:389      # LDAP DC2
          - 10.0.3.12:445      # file server SMB
          - 10.0.3.13:25       # smtp
          - 10.0.3.13:143      # imap
          - 10.0.5.14:2049     # nfs
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115

  # ===== ICMP (ping) a todas las maquinas =====
  - job_name: icmp
    metrics_path: /probe
    params: { module: [icmp] }
    static_configs:
      - targets:
          - 10.0.0.10
          - 10.0.0.20
          - 10.0.0.31
          - 10.0.0.32
          - 10.0.0.33
          - 10.0.0.34
          - 10.0.1.11
          - 10.0.1.12
          - 10.0.1.13
          - 10.0.1.14
          - 10.0.1.15
          - 10.0.1.16
          - 10.0.2.11
          - 10.0.2.12
          - 10.0.2.13
          - 10.0.2.14
          - 10.0.3.10
          - 10.0.3.11
          - 10.0.3.12
          - 10.0.3.13
          - 10.0.3.14
          - 10.0.3.15
          - 10.0.4.11
          - 10.0.4.12
          - 10.0.4.13
          - 10.0.5.11
          - 10.0.5.12
          - 10.0.5.13
          - 10.0.5.14
          - 10.0.5.15
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115

  # ===== DNS (resuelve corp.local en DC1 y en dnsmasq) =====
  - job_name: dns
    metrics_path: /probe
    params: { module: [dns_corp] }
    static_configs:
      - targets:
          - 10.0.3.10:53       # DC1 (AD DNS)
          - 10.0.5.11:53       # dnsmasq ops
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115
EOF

# --- Grafana: datasource + provider de dashboards ---------------------------
cat > /opt/mon/grafana/provisioning/datasources/ds.yml <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
cat > /opt/mon/grafana/provisioning/dashboards/dash.yml <<'EOF'
apiVersion: 1
providers:
  - name: business-lab
    folder: Business-Lab
    type: file
    options:
      path: /var/lib/grafana/dashboards
EOF

# --- Grafana: dashboard "Estado de servicios" -------------------------------
cat > /opt/mon/grafana/dashboards/blackbox.json <<'EOF'
{
  "title": "Business-Lab · Estado de servicios",
  "uid": "biz-lab-status",
  "schemaVersion": 39,
  "refresh": "30s",
  "time": { "from": "now-6h", "to": "now" },
  "panels": [
    {
      "type": "stat", "title": "Servicios ARRIBA", "id": 1,
      "gridPos": { "h": 4, "w": 6, "x": 0, "y": 0 },
      "fieldConfig": { "defaults": { "color": { "mode": "fixed", "fixedColor": "green" } } },
      "targets": [ { "expr": "sum(probe_success)", "refId": "A" } ]
    },
    {
      "type": "stat", "title": "Servicios CAIDOS", "id": 2,
      "gridPos": { "h": 4, "w": 6, "x": 6, "y": 0 },
      "fieldConfig": { "defaults": { "color": { "mode": "fixed", "fixedColor": "red" },
        "thresholds": { "steps": [ {"color":"green","value":null}, {"color":"red","value":1} ] } } },
      "targets": [ { "expr": "count(probe_success == 0) or vector(0)", "refId": "A" } ]
    },
    {
      "type": "table", "title": "Detalle por servicio", "id": 3,
      "gridPos": { "h": 18, "w": 24, "x": 0, "y": 4 },
      "transformations": [
        { "id": "labelsToFields", "options": {} },
        { "id": "organize", "options": { "excludeByName": { "Time": true, "Value": false } } }
      ],
      "fieldConfig": { "defaults": { "mappings": [
        { "type": "value", "options": { "0": { "text": "CAIDO",  "color": "red"   },
                                        "1": { "text": "ARRIBA", "color": "green" } } } ],
        "custom": { "displayMode": "color-background" } } },
      "targets": [ { "expr": "probe_success", "format": "table", "instant": true, "refId": "A" } ]
    }
  ]
}
EOF

# --- Certificado autofirmado para HTTPS (no hay dominio: CN = IP publica) ---
mkdir -p /opt/mon/grafana/certs
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
PUBIP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
[ -z "$PUBIP" ] && PUBIP=monitor.corp.local
openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
  -keyout /opt/mon/grafana/certs/grafana.key \
  -out    /opt/mon/grafana/certs/grafana.crt \
  -subj "/CN=${PUBIP}" -addext "subjectAltName=IP:${PUBIP}"
chmod 644 /opt/mon/grafana/certs/grafana.key /opt/mon/grafana/certs/grafana.crt

# --- Arranque de contenedores (idempotente: rm -f por si se re-ejecuta) -----
docker network create mon 2>/dev/null || true
docker rm -f blackbox prometheus grafana 2>/dev/null || true

docker run -d --restart unless-stopped --name blackbox --network mon \
  --cap-add NET_RAW \
  -v /opt/mon/blackbox:/config \
  prom/blackbox-exporter:latest --config.file=/config/blackbox.yml

docker run -d --restart unless-stopped --name prometheus --network mon -p 9090:9090 \
  -v /opt/mon/prometheus:/etc/prometheus \
  prom/prometheus:latest

# Grafana sirve HTTPS en el 443 del host -> 3000 del contenedor (TLS lo termina Grafana).
docker run -d --restart unless-stopped --name grafana --network mon -p 443:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD="${GF_PASS}" \
  -e GF_USERS_ALLOW_SIGN_UP=false \
  -e GF_SERVER_PROTOCOL=https \
  -e GF_SERVER_CERT_FILE=/etc/grafana/certs/grafana.crt \
  -e GF_SERVER_CERT_KEY=/etc/grafana/certs/grafana.key \
  -v /opt/mon/grafana/certs:/etc/grafana/certs \
  -v /opt/mon/grafana/provisioning:/etc/grafana/provisioning \
  -v /opt/mon/grafana/dashboards:/var/lib/grafana/dashboards \
  grafana/grafana:latest

echo "monitor ready - Grafana https://${PUBIP}/ (443, admin/${GF_PASS}) · Prometheus :9090 (interno)" > /var/log/prov.done
