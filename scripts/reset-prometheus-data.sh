#!/bin/bash
set -euo pipefail

CONTAINER="prometheus"
DATA_MOUNT="/prometheus"

echo "==> Verificando existencia del contenedor $CONTAINER..."
if ! sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: El contenedor $CONTAINER no existe."
  exit 1
fi

echo "    Contenedor detectado correctamente."
echo

echo "==> Deteniendo Prometheus..."
sudo docker stop "$CONTAINER"

echo "==> Eliminando histórico de Prometheus de forma segura..."
# Explicación: Montamos el mismo almacenamiento en un contenedor temporal 'alpine' 
# y borramos el contenido de forma nativa desde dentro de Docker, evitando problemas de permisos en el Host.
sudo docker run --rm \
  --volumes-from "$CONTAINER" \
  alpine sh -c "find $DATA_MOUNT -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"

echo "==> Arrancando Prometheus..."
sudo docker start "$CONTAINER"

echo
echo "==> Comprobando estado..."
sleep 3
sudo docker ps --filter "name=^/${CONTAINER}$" \
  --format 'table {{.Names}}\t{{.Status}}'

echo
echo "OK: histórico de Prometheus eliminado con éxito."
echo "Prometheus ha vuelto a arrancar desde cero."
