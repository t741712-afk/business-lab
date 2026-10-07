#!/bin/bash
# Frontal web Nginx + PHP-FPM + Autenticación Active Directory LDAP (Ubuntu 22.04)
set -x
set -e

export DEBIAN_FRONTEND=noninteractive

# --- REPOSITORIO OFICIAL ---
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/nginx"

echo "==> Actualizando índices de paquetes..."
apt-get update -y

echo "==> Instalando Nginx, PHP-FPM y extensión LDAP..."
apt-get install -y nginx php-fpm php-ldap curl

echo "==> Limpiando directorio web por defecto..."
rm -rf /var/www/html/*

echo "==> Descargando el código con login LDAP integrado desde GitHub..."
curl -sS -L -o /var/www/html/index.php "${REPO_BASE_URL}/index.php?v=$(date +%s)"
curl -sS -L -o /var/www/html/health "${REPO_BASE_URL}/health?v=$(date +%s)"

echo "==> Configurando Nginx para procesar PHP a través de PHP-FPM..."
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    # Pasar los scripts PHP al servidor FastCGI enlazado con PHP-FPM
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

echo "==> Detectando versión de PHP activa para enlazar el socket..."
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
ln -sf /var/run/php/php${PHP_VER}-fpm.sock /var/run/php/php-fpm.sock

echo "==> Ajustando permisos de la carpeta web para el usuario de Nginx..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "==> Reiniciando y habilitando servicios..."
systemctl restart php${PHP_VER}-fpm
systemctl enable php${PHP_VER}-fpm
systemctl restart nginx
systemctl enable nginx

echo "nginx-ldap ready" > /var/log/prov.done
