#!/bin/bash
# Frontal web Nginx + PHP-FPM + Autenticación Active Directory LDAP + Proxy Inverso Limpio
set -x
set -e

export DEBIAN_FRONTEND=noninteractive

# --- REPOSITORIO OFICIAL ---
REPO_BASE_URL="https://raw.githubusercontent.com/t741712-afk/business-lab/refs/heads/main/nginx"

echo "==> Actualizando índices de paquetes..."
apt-get update -y

echo "==> Instalando Nginx, PHP-FPM y extensión LDAP..."
apt-get install -y nginx php-fpm php-ldap curl

echo "==> Limpiando el directorio web raíz por defecto..."
rm -rf /var/www/html/*

echo "==> Descargando el archivo index.php y health desde GitHub..."
curl -sS -L -o /var/www/html/index.php "${REPO_BASE_URL}/index.php?v=$(date +%s)"
curl -sS -L -o /var/www/html/health "${REPO_BASE_URL}/health?v=$(date +%s)"

echo "==> Saneando las carpetas de configuración de Nginx para evitar duplicados..."
# Borramos cualquier archivo en sites-enabled para asegurar que no se carguen rutas viejas
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/conf.d/*

echo "==> Escribiendo la configuración del Proxy Inverso limpia en sites-available..."
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm;

    server_name _;

    # Portal Principal protegido con Login
    location / {
        try_files $uri $uri/ =404;
    }

    # 1. Redirección Proxy Inverso a la API real de Node (Mantiene la IP interna correcta)
    location /api/ {
        proxy_pass http://10.0.1.12:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 2. Redirección Proxy Inverso a la App de Java (Tomcat)
    location /java-app/ {
        proxy_pass http://10.0.1.11:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 3. Redirección Proxy Inverso a la Intranet Corporativa
    location /intranet/ {
        proxy_pass http://10.0.3;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Procesamiento de PHP para la pasarela de autenticación
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

echo "==> Creando el enlace simbólico mandatorio hacia sites-enabled..."
# Si este enlace no existe, Nginx ignora por completo el archivo default modificado
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

echo "==> Sincronizando sockets de PHP..."
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
ln -sf /var/run/php/php${PHP_VER}-fpm.sock /var/run/php/php-fpm.sock

echo "==> Ajustando permisos de la carpeta web para www-data..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "==> FORZANDO LIMPIEZA AGRESIVA DE PROCESOS FANTASMA EN MEMORIA RAM..."
# Matamos los procesos huérfanos de Nginx de forma fulminante para limpiar los sockets heredados
killall -9 nginx || true

echo "==> Inicializando los servicios de forma limpia..."
systemctl restart php${PHP_VER}-fpm
systemctl restart nginx

echo "nginx-gateway-proxy corporate ready" > /var/log/prov.done