#!/bin/bash
# Frontal Apache + PHP Corporativo (Amazon Linux 2023)
set -x
set -e

# --- REPOSITORIO OFICIAL ---
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/apache"

echo "==> Actualizando el sistema..."
dnf -y update

# --- AJUSTE CRÍTICO 1: Configurar SELinux en modo permisivo ---
# Evita que las políticas de seguridad del sistema bloqueen la ejecución de comandos (RCE) en PHP
if command -v setenforce >/dev/null 2>&1; then
    sudo setenforce 0 || true
fi

echo "==> Instalando dependencias web (sin forzar el paquete curl en AL2023)..."
# Eliminamos 'curl' de la lista de instalación ya que curl-minimal está preinstalado en el sistema
dnf -y install httpd php php-mysqlnd

echo "==> Limpiando el directorio web raiz..."
rm -rf /var/www/html/*

echo "==> Descargando la aplicacion web corporativa desde GitHub..."
# curl-minimal ejecutará esta descarga perfectamente
curl -sS -L -o /var/www/html/index.php "${REPO_BASE_URL}/index.php"
curl -sS -L -o /var/www/html/info.php "${REPO_BASE_URL}/info.php"

# --- CONTROL DE FALLAS (FALLBACK) ---
if [ ! -s /var/www/html/index.php ]; then
    echo "ERROR: No se pudo descargar desde el repositorio. Aplicando contingencia local..."
    cat > /var/www/html/index.php <<'EOF'
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>Laboratories Corporation TAI - Contingencia</title></head>
<body style="font-family:sans-serif; background:#0F172A; color:white; text-align:center; padding-top:10%;">
    <h1>LABORATORIES CORPORATION TAI</h1>
    <p>Modo de contingencia activo. Error de comunicacion con el repositorio de despliegue.</p>
</body>
</html>
EOF
fi

# --- AJUSTE CRÍTICO 2: Preparación del entorno de subidas y permisos ---
# Forzamos la creación del directorio de destino y aplicamos los permisos adecuados
mkdir -p /var/www/html/uploads
echo "==> Ajustando permisos de la carpeta web para Apache..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
chmod 777 /var/www/html/uploads  # Garantiza que el formulario PHP pueda escribir sin importar la máscara

echo "==> Iniciando y habilitando el servicio de Apache..."
systemctl enable --now httpd

echo "apache-php corporate ready" > /var/log/prov.done