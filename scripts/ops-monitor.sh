#!/bin/bash
# Monitorizacion: Prometheus + Grafana (Ubuntu) via Docker para simplicidad.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io
systemctl enable --now docker
# Prometheus
mkdir -p /opt/prom
cat > /opt/prom/prometheus.yml <<'EOF'
global: { scrape_interval: 15s }
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['10.0.1.11:9100','10.0.2.11:9100','10.0.5.13:9100']
EOF
docker run -d --restart unless-stopped --name prometheus -p 9090:9090 \
  -v /opt/prom/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
# Grafana
docker run -d --restart unless-stopped --name grafana -p 3000:3000 grafana/grafana
echo "monitor ready" > /var/log/prov.done
