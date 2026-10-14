#!/bin/bash
# CI: Wordpress Vulnerable (DockerLabs) - Parcheo e Inyección de Puertos Directa
set -x
set -e
export DEBIAN_FRONTEND=noninteractive

echo "==> Instalando dependencias básicas del sistema..."
apt-get update -y
apt-get install -y docker.io wget unzip

echo "==> Asegurando y arrancando el servicio de Docker..."
systemctl enable --now docker

echo "==> Creando directorio de trabajo..."
WORKDIR="/opt/wordpress-lab"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> Descargando el laboratorio de DockerLabs..."
ZIP_URL="https://gestion-maquinas.dockerlabs.es/dl/pressenter.zip"
wget -q --show-progress "$ZIP_URL" -O pressenter.zip

echo "==> Descomprimiendo el paquete del CTF..."
unzip -o pressenter.zip

# Localizamos el script auto_deploy.sh en el directorio
SCRIPT_PATH=$(find . -name "auto_deploy.sh" | head -n 1)

if [ -z "$SCRIPT_PATH" ]; then
    echo "ERROR: No se encontró el archivo auto_deploy.sh dentro del ZIP."
    exit 1
fi

SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
cd "$SCRIPT_DIR"

echo "==> Modificando la línea de despliegue en auto_deploy.sh de forma dinámica..."
# Buscamos la línea exacta 'docker run -d --name $CONTAINER_NAME $IMAGE_NAME'
# e inyectamos los mapeos requeridos: 8080 de la VM al 80 del contenedor, y 2222 de la VM al 22 del contenedor.
TARGET_RUN="docker run -d --name \$CONTAINER_NAME \$IMAGE_NAME"
MODIFIED_RUN="docker run -d -p 80:80 -p 2222:22 --name \$CONTAINER_NAME \$IMAGE_NAME"

sed -i "s|$TARGET_RUN|$MODIFIED_RUN|g" auto_deploy.sh

echo "==> Localizando la imagen del laboratorio empaquetada..."
TAR_FILE=$(find . -name "*.tar" | head -n 1 | xargs basename)

if [ -z "$TAR_FILE" ]; then
    echo "ERROR: No se encontró el archivo de la imagen (.tar) en el directorio."
    exit 1
fi

echo "==> Levantando la máquina vulnerable en segundo plano (Persistent Run)..."
# Ejecutamos el script redirigiendo la salida a un log y en segundo plano (&).
# Esto evita que el bucle "while true" del script original bloquee tu aprovisionamiento.
sudo bash auto_deploy.sh "$TAR_FILE" > /var/log/wordpress_deploy.log 2>&1 &

# Damos un breve margen de tiempo para que Docker cargue la imagen e inicie el proceso
sleep 5

echo "Wordpress vulnerable desplegado con éxito. Puertos accesibles desde la VM: 80 y 2222." > /var/log/prov.done
