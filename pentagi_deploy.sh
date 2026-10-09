#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# PentAGI + Docker
# Ubuntu 22.04 / 24.04 LTS
# Compatible con ejecución mediante sudo y autenticación SSH PEM
# Almacenamiento Docker predeterminado en /
# ============================================================

REPO_URL="https://github.com/vxcontrol/pentagi.git"

# Detectar el usuario original incluso cuando se ejecuta con sudo.
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="${SUDO_USER}"
else
    TARGET_USER="${USER:-$(id -un)}"
fi

TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
    echo "[ERROR] No se pudo determinar el directorio personal de ${TARGET_USER}."
    exit 1
fi

INSTALL_DIR="${TARGET_HOME}/pentagi"

trap 'echo "[ERROR] Fallo en la línea ${LINENO}. Revisa el mensaje anterior."' ERR

error_exit() {
    echo
    echo "[ERROR] $1"
    exit 1
}

info() {
    echo
    echo "[+] $1"
}

# ============================================================
# COMPROBACIONES INICIALES
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        error_exit "sudo no está instalado."
    fi

    exec sudo -E bash "$0" "$@"
fi

if [[ ! -r /etc/os-release ]]; then
    error_exit "No se encuentra /etc/os-release."
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    error_exit "Este script está preparado para Ubuntu. Sistema detectado: ${PRETTY_NAME:-desconocido}"
fi

CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

if [[ -z "${CODENAME}" ]]; then
    error_exit "No se pudo detectar el codename de Ubuntu."
fi

case "${CODENAME}" in
    jammy|noble)
        ;;
    *)
        echo "[AVISO] Ubuntu detectado: ${CODENAME}"
        echo "[AVISO] Se continuará con la configuración para Ubuntu."
        ;;
esac

ARCH="$(dpkg --print-architecture)"

case "${ARCH}" in
    amd64|arm64)
        ;;
    *)
        error_exit "Arquitectura no soportada: ${ARCH}"
        ;;
esac

echo
echo "============================================================"
echo " INSTALACIÓN DE PENTAGI"
echo "============================================================"
echo
echo "[+] Usuario de instalación : ${TARGET_USER}"
echo "[+] Directorio personal    : ${TARGET_HOME}"
echo "[+] Directorio de PentAGI  : ${INSTALL_DIR}"
echo "[+] Ubuntu                 : ${CODENAME}"
echo "[+] Arquitectura           : ${ARCH}"
echo

info "Comprobando espacio disponible en el disco raíz..."

df -h /

info "Actualizando APT e instalando dependencias..."

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    jq \
    python3

# ============================================================
# INSTALACIÓN DE DOCKER
# ============================================================

info "Configurando el repositorio oficial de Docker..."

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/sources.list.d/docker.sources

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update

if ! apt-cache show docker-ce >/dev/null 2>&1; then
    error_exit "APT no encuentra docker-ce. Revisa la salida de apt-get update."
fi

info "Instalando Docker Engine y Docker Compose..."

apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

info "Habilitando e iniciando Docker..."

systemctl enable containerd.service
systemctl enable docker.service

systemctl start containerd.service
systemctl start docker.service

echo "[+] Esperando a que Docker esté operativo..."

for i in {1..30}; do
    if docker info >/dev/null 2>&1; then
        break
    fi

    sleep 2
done

if ! docker info >/dev/null 2>&1; then
    echo
    echo "[ERROR] Docker no ha arrancado correctamente."
    echo

    systemctl status docker --no-pager || true

    echo

    journalctl -u docker --no-pager -n 50 || true

    exit 1
fi

info "Comprobando Docker Compose..."

docker compose version

echo
echo "[+] Directorio de almacenamiento Docker:"
docker info --format '{{.DockerRootDir}}'

echo
echo "[+] Espacio disponible:"
df -h /

# ============================================================
# PERMISOS DOCKER
# ============================================================

info "Configurando el grupo docker..."

groupadd -f docker
usermod -aG docker "${TARGET_USER}"

echo "[+] El usuario ${TARGET_USER} se ha añadido al grupo docker."
echo "[+] Los permisos de grupo se aplicarán al iniciar una nueva sesión."

# ============================================================
# INSTALACIÓN DE PENTAGI
# ============================================================

info "Preparando PentAGI..."

if [[ -d "${INSTALL_DIR}/.git" ]]; then
    echo "[+] El repositorio ya existe."
    echo "[+] Se conservará el repositorio existente."

elif [[ -e "${INSTALL_DIR}" ]]; then
    error_exit "${INSTALL_DIR} existe pero no es un repositorio Git."

else
    info "Clonando el repositorio oficial de PentAGI..."

    runuser -u "${TARGET_USER}" -- \
        git clone "${REPO_URL}" "${INSTALL_DIR}"
fi

cd "${INSTALL_DIR}"

if [[ ! -f ".env.example" ]]; then
    error_exit "PentAGI no contiene .env.example."
fi

if [[ ! -f "docker-compose.yml" ]]; then
    error_exit "PentAGI no contiene docker-compose.yml."
fi

if [[ ! -f ".env" ]]; then
    info "Creando .env..."

    install -o "${TARGET_USER}" -g "$(id -gn "${TARGET_USER}")" \
        -m 0600 .env.example .env
else
    echo "[+] Ya existe .env; se conservará antes de actualizar las claves."
fi

# ============================================================
# CONFIGURACIÓN DE API
# ============================================================

echo
echo "============================================================"
echo " CONFIGURACIÓN DE APIs"
echo "============================================================"
echo
echo "Introduce las claves API."
echo "No se mostrarán mientras las escribes."
echo

read -r -s -p "DeepSeek API key: " DEEPSEEK_KEY
echo

read -r -s -p "Jina API key: " JINA_KEY
echo

read -r -s -p "OpenRouter API key: " OPENROUTER_KEY
echo

if [[ -z "${DEEPSEEK_KEY}" ]]; then
    error_exit "La clave de DeepSeek está vacía."
fi

if [[ -z "${JINA_KEY}" ]]; then
    error_exit "La clave de Jina está vacía."
fi

if [[ -z "${OPENROUTER_KEY}" ]]; then
    error_exit "La clave de OpenRouter está vacía."
fi

info "Guardando configuración de APIs en .env..."

DEEPSEEK_KEY="${DEEPSEEK_KEY}" \
JINA_KEY="${JINA_KEY}" \
OPENROUTER_KEY="${OPENROUTER_KEY}" \
INSTALL_DIR="${INSTALL_DIR}" \
python3 <<'PY'
import os
import pathlib
import re

path = pathlib.Path(os.environ["INSTALL_DIR"]) / ".env"
text = path.read_text()

settings = {
    "DEEPSEEK_API_KEY": os.environ["DEEPSEEK_KEY"],
    "DEEPSEEK_SERVER_URL": "https://api.deepseek.com",

    "LLM_SERVER_URL": "https://openrouter.ai/api/v1",
    "LLM_SERVER_KEY": os.environ["OPENROUTER_KEY"],
    "LLM_SERVER_MODEL": "nex-agi/nex-n2.5-pro",

    "EMBEDDING_URL": "https://api.jina.ai/v1",
    "EMBEDDING_KEY": os.environ["JINA_KEY"],
    "EMBEDDING_MODEL": "jina-embeddings-v3",
    "EMBEDDING_PROVIDER": "jina",

    "PENTAGI_LISTEN_IP": "0.0.0.0",
}

for key, value in settings.items():
    pattern = re.compile(
        r"(?m)^" + re.escape(key) + r"=.*$"
    )

    replacement = f"{key}={value}"

    if pattern.search(text):
        text = pattern.sub(
            lambda _: replacement,
            text,
            count=1
        )
    else:
        if not text.endswith("\n"):
            text += "\n"

        text += replacement + "\n"

path.write_text(text)
path.chmod(0o600)
PY

unset DEEPSEEK_KEY
unset JINA_KEY
unset OPENROUTER_KEY

chown "${TARGET_USER}:$(id -gn "${TARGET_USER}")" \
    "${INSTALL_DIR}/.env"

# ============================================================
# VALIDACIÓN Y DESPLIEGUE
# ============================================================

info "Validando configuración de PentAGI..."

docker compose config --quiet

info "Descargando imágenes de PentAGI..."

docker compose pull

info "Arrancando PentAGI..."

docker compose up -d

# ============================================================
# RESULTADO FINAL
# ============================================================

echo
echo "============================================================"
echo " DESPLIEGUE COMPLETADO"
echo "============================================================"
echo

echo "[+] Docker:"
docker info --format ' Docker Root: {{.DockerRootDir}}'

echo
echo "[+] Contenedores:"
docker compose ps

echo
echo "[+] Espacio disponible en el disco raíz:"
df -h /

echo
echo "[+] PentAGI debería estar disponible en:"
echo
echo "    https://localhost:8443"
echo

echo "[+] Para ver los logs:"
echo
echo "    cd ${INSTALL_DIR}"
echo "    sudo docker compose logs -f pentagi"
echo

echo "============================================================"
echo " FIN"
echo "============================================================"