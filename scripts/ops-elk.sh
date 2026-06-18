#!/bin/bash
# SIEM / logs: Elasticsearch + Kibana (Ubuntu) via Docker. Necesita CPU/RAM
# (por eso c5.2xlarge). Modo single-node, sin seguridad (lab aislado).
# Endurecido: reintentos de apt/pull, ulimits de ES, espera a que ES este SANO
# antes de arrancar Kibana, y verificacion final.
set -x
export DEBIAN_FRONTEND=noninteractive
ES_IMG="docker.elastic.co/elasticsearch/elasticsearch:8.13.4"
KB_IMG="docker.elastic.co/kibana/kibana:8.13.4"

# 1) Docker (apt con reintentos por el NAT)
for i in $(seq 1 10); do apt-get update -y && break; sleep 15; done
for i in $(seq 1 10); do apt-get install -y docker.io && break; sleep 15; done
systemctl enable --now docker

# 2) Requisito del kernel para Elasticsearch
sysctl -w vm.max_map_count=262144
grep -q vm.max_map_count /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf

# 3) Pre-descarga de imagenes (con reintentos; son grandes)
for i in $(seq 1 5); do docker pull "$ES_IMG" && break; sleep 20; done
for i in $(seq 1 5); do docker pull "$KB_IMG" && break; sleep 20; done

docker network create elk 2>/dev/null || true
docker rm -f elasticsearch kibana 2>/dev/null || true

# 4) Elasticsearch (ulimits recomendados; 2g heap, holgado en c5.2xlarge/16GB)
docker run -d --restart unless-stopped --name elasticsearch --net elk -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  -e "ES_JAVA_OPTS=-Xms2g -Xmx2g" \
  --ulimit nofile=65536:65536 \
  --ulimit memlock=-1:-1 \
  "$ES_IMG"

# 5) Esperar a que ES responda ANTES de arrancar Kibana (hasta ~10 min)
ES_OK=no
for i in $(seq 1 60); do
  if curl -fs http://localhost:9200 >/dev/null 2>&1; then ES_OK=yes; break; fi
  sleep 10
done

# 6) Kibana
docker run -d --restart unless-stopped --name kibana --net elk -p 5601:5601 \
  -e "ELASTICSEARCH_HOSTS=http://elasticsearch:9200" \
  "$KB_IMG"

# 7) Esperar a que Kibana levante (su primer arranque optimiza, tarda; hasta ~10 min)
KB_OK=no
for i in $(seq 1 60); do
  if curl -fs http://localhost:5601/api/status >/dev/null 2>&1; then KB_OK=yes; break; fi
  sleep 10
done

echo "elk ready - Elasticsearch(9200)=$ES_OK Kibana(5601)=$KB_OK" > /var/log/prov.done
if [ "$ES_OK" != yes ] || [ "$KB_OK" != yes ]; then
  echo "--- docker ps ---" >> /var/log/prov.done
  docker ps -a --format '{{.Names}} {{.Status}}' >> /var/log/prov.done 2>&1
fi
