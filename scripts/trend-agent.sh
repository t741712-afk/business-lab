#!/bin/bash
# Instala y activa el agente de Trend Micro Deep Security (Ubuntu: .deb, Amazon Linux / RHEL: .rpm).
# Uso: trend-agent.sh <tenant_id> <token>
# Las URLs de los paquetes van aquí; el tenant y el token son los únicos datos que se pasan.
set -euo pipefail

TENANT_ID="${1:-}"
TOKEN="${2:-}"
DSM_URL="dsm://agents.workload.de-1.cloudone.trendmicro.com:443/"
WORK=/opt/ds_agent

# URLs de los paquetes del agente Deep Security 20.0.3 (zip con el .deb o el .rpm)
PKG_UBUNTU_2204="https://files.trendmicro.com/products/deepsecurity/en/20.0/Agent-Ubuntu_22.04-20.0.3-28120.x86_64.zip"
PKG_AMZN2023="https://files.trendmicro.com/products/deepsecurity/en/20.0/Agent-amzn2023-20.0.3-28120.x86_64.zip"

if [ -z "$TENANT_ID" ] || [ -z "$TOKEN" ]; then
  echo "trend-agent: faltan tenant o token" >&2
  exit 1
fi

# Elegir el paquete según el sistema operativo
. /etc/os-release
case "$ID" in
  ubuntu) PKG_URL="$PKG_UBUNTU_2204" ;;
  amzn) PKG_URL="$PKG_AMZN2023" ;;
  *) echo "trend-agent: sistema no soportado: $ID" >&2; exit 1 ;;
esac


# Ubuntu Server no trae unzip de serie (Amazon Linux sí): se instala si falta
if ! command -v unzip >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y unzip
fi

mkdir -p "$WORK"
cd "$WORK"
curl -fsSL -o agent.zip "$PKG_URL"
unzip -o agent.zip

if ls Agent-Core-*.deb >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive dpkg -i Agent-Core-*.deb || apt-get -f install -y
elif ls Agent-Core-*.rpm >/dev/null 2>&1; then
  rpm -Uvh Agent-Core-*.rpm
else
  echo "trend-agent: no se encontro paquete .deb ni .rpm en el zip" >&2
  exit 1
fi

sleep 30
"$WORK/dsa_control" -a "$DSM_URL" "tenantID:$TENANT_ID" "token:$TOKEN"
echo "trend-agent: agente instalado y activado"
