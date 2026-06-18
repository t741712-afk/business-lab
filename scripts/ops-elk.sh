#!/bin/bash
# SIEM / logs: Elasticsearch + Kibana (Ubuntu) via Docker. Necesita CPU/RAM
# (por eso c5.2xlarge). Modo single-node, sin seguridad (lab aislado).
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io
systemctl enable --now docker
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
docker network create elk 2>/dev/null || true
docker run -d --restart unless-stopped --name elasticsearch --net elk -p 9200:9200 \
  -e "discovery.type=single-node" -e "xpack.security.enabled=false" -e "ES_JAVA_OPTS=-Xms2g -Xmx2g" \
  docker.elastic.co/elasticsearch/elasticsearch:8.13.4
sleep 30
docker run -d --restart unless-stopped --name kibana --net elk -p 5601:5601 \
  -e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
  docker.elastic.co/kibana/kibana:8.13.4
echo "elk ready" > /var/log/prov.done
