#!/bin/bash
set -euo pipefail

CONTAINER="prometheus"
DATA_MOUNT="/prometheus"

echo "==> Localizando volumen de Prometheus..."

VOLUME=$(sudo docker inspect "$CONTAINER" \
  --format '{{range .Mounts}}{{if eq .Destination "/prometheus"}}{{.Name}}{{end}}{{end}}')

if [ -z "$VOLUME" ]; then
  echo "ERROR: no se encontró ningún volumen montado en $DATA_MOUNT"
  exit 1
fi

MOUNTPOINT=$(sudo docker volume inspect "$VOLUME" \
  --format '{{.Mountpoint}}')

if [ -z "$MOUNTPOINT" ] || [ ! -d "$MOUNTPOINT" ]; then
  echo "ERROR: no se pudo localizar el Mountpoint del volumen:"
  echo "$VOLUME"
  exit 1
fi

echo "    Contenedor : $CONTAINER"
echo "    Volumen    : $VOLUME"
echo "    Mountpoint : $MOUNTPOINT"

echo
echo "==> Deteniendo Prometheus..."
sudo docker stop "$CONTAINER"

echo "==> Eliminando histórico de Prometheus..."
sudo find "$MOUNTPOINT" \
  -mindepth 1 \
  -maxdepth 1 \
  -exec rm -rf -- {} +

echo "==> Arrancando Prometheus..."
sudo docker start "$CONTAINER"

echo
echo "==> Comprobando estado..."
sleep 3
sudo docker ps --filter "name=^/${CONTAINER}$" \
  --format 'table {{.Names}}\t{{.Status}}'

echo
echo "OK: histórico de Prometheus eliminado."
echo "Prometheus ha vuelto a arrancar desde cero."