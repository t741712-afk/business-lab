#!/bin/bash
# Frontal WordPress (Ubuntu 22.04): nginx + php-fpm + MariaDB local + WordPress.
set -Eeuo pipefail
set -x
export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script como root: sudo bash $0" >&2
  exit 1
fi

apt-get update -y
apt-get install -y \
  nginx mariadb-server php-fpm php-mysql php-curl php-gd \
  php-xml php-mbstring curl ca-certificates tar

systemctl enable --now mariadb

DBPASS="WpLab#2026"
WP_ADMIN="admin"
WP_ADMIN_PASS="WpAdmin#2026"
WP_TITLE="Business Lab WordPress"
WP_URL="http://10.0.0.32"
WP_PATH="/var/www/html"

# Crear la base de datos y el usuario de WordPress.
mysql -e "CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'wp'@'localhost' IDENTIFIED BY '${DBPASS}';"
mysql -e "ALTER USER 'wp'@'localhost' IDENTIFIED BY '${DBPASS}';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wp'@'localhost'; FLUSH PRIVILEGES;"

# Descargar WordPress.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
curl -fsSL https://wordpress.org/latest.tar.gz -o "${tmpdir}/wordpress.tar.gz"
tar -xzf "${tmpdir}/wordpress.tar.gz" -C "$tmpdir"

# Instalar los archivos de WordPress en el document root.
mkdir -p "$WP_PATH"
cp -a "${tmpdir}/wordpress/." "$WP_PATH/"
rm -rf "$tmpdir"

# Configurar wp-config.php.
if [[ ! -f "${WP_PATH}/wp-config.php" ]]; then
  cp "${WP_PATH}/wp-config-sample.php" "${WP_PATH}/wp-config.php"
fi

# Escapar caracteres especiales para sustitución segura en sed.
DBPASS_SED="$(printf '%s' "$DBPASS" | sed 's/[\/&]/\\&/g')"
sed -i \
  -e 's/database_name_here/wordpress/' \
  -e 's/username_here/wp/' \
  -e "s/password_here/${DBPASS_SED}/" \
  "${WP_PATH}/wp-config.php"

# Detectar la versión de PHP-FPM instalada.
PHP_FPM_SERVICE="$(systemctl list-unit-files 'php*-fpm.service' --no-legend | awk '$1 ~ /^php[0-9.]+-fpm\.service$/ {print $1; exit}')"
if [[ -z "$PHP_FPM_SERVICE" ]]; then
  echo "No se ha encontrado un servicio PHP-FPM instalado." >&2
  exit 1
fi
PHPVER="${PHP_FPM_SERVICE#php}"
PHPVER="${PHPVER%-fpm.service}"
PHP_SOCKET="/run/php/php${PHPVER}-fpm.sock"

systemctl enable --now "$PHP_FPM_SERVICE"

# Esperar a que el socket de PHP-FPM esté disponible.
for _ in $(seq 1 30); do
  [[ -S "$PHP_SOCKET" ]] && break
  sleep 1
done
if [[ ! -S "$PHP_SOCKET" ]]; then
  echo "No se encuentra el socket PHP-FPM: ${PHP_SOCKET}" >&2
  exit 1
fi

# Configurar nginx.
cat > /etc/nginx/sites-available/default <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root ${WP_PATH};
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCKET};
    }

    location ~* \.(?:css|js|jpg|jpeg|gif|png|svg|ico|webp)$ {
        expires 7d;
        access_log off;
    }

    location ~ /\. {
        deny all;
    }
}
NGINX

nginx -t
systemctl enable --now nginx
systemctl restart nginx

# Instalar WP-CLI.
curl -fsSL \
  https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  -o /usr/local/bin/wp
chmod 0755 /usr/local/bin/wp

# Permisos iniciales.
chown -R www-data:www-data "$WP_PATH"

# Instalar WordPress si todavía no está instalado.
if ! sudo -u www-data wp core is-installed --path="$WP_PATH" --allow-root 2>/dev/null; then
  sudo -u www-data wp core install \
    --path="$WP_PATH" \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN" \
    --admin_password="$WP_ADMIN_PASS" \
    --admin_email="admin@business-lab.local"
fi

# Actualizar título y descripción mediante la autenticación local por socket de MariaDB.
mysql wordpress <<'SQL'
UPDATE wp_options
SET option_value = 'TAI Insights | Science & Careers'
WHERE option_name = 'blogname';

UPDATE wp_options
SET option_value = 'Official research insights and technology career opportunities at Laboratories Corporation TAI.'
WHERE option_name = 'blogdescription';
SQL

# Obtener el tema activo mediante WP-CLI.
WP_THEME="$(sudo -u www-data wp theme list \
  --status=active --field=name --path="$WP_PATH")"

if [[ -z "$WP_THEME" || ! -d "${WP_PATH}/wp-content/themes/${WP_THEME}" ]]; then
  echo "No se ha podido determinar el tema activo de WordPress." >&2
  exit 1
fi

WP_THEME_DIR="${WP_PATH}/wp-content/themes/${WP_THEME}"
FUNCTIONS_FILE="${WP_THEME_DIR}/functions.php"

# No modificar un tema que no tenga functions.php con apertura PHP.
if [[ ! -f "$FUNCTIONS_FILE" ]] || ! grep -q '<?php' "$FUNCTIONS_FILE"; then
  echo "El tema activo no tiene un functions.php válido: ${FUNCTIONS_FILE}" >&2
  echo "Instala/activa un tema con functions.php antes de aplicar el diseño." >&2
  exit 1
fi

# Evitar duplicar la función. Si el archivo termina con ?>, quitar esa
# etiqueta final para que el bloque PHP añadido no quede como texto plano.
if ! grep -q 'function ctf_tai_corporate_theme' "$FUNCTIONS_FILE"; then
  sed -i '${ /^[[:space:]]*?>[[:space:]]*$/d; }' "$FUNCTIONS_FILE"
  cat >> "$FUNCTIONS_FILE" <<'PHP'

/* TAI corporate visual style for the CTF lab. */
if (!function_exists('ctf_tai_corporate_theme')) {
    function ctf_tai_corporate_theme() {
        echo <<<'TAI_CSS'
<style id="ctf-tai-corporate-theme">
:root {
    --bg-dark: #0B0F19;
    --card-bg: #111827;
    --accent-blue: #3B82F6;
    --accent-cyan: #06B6D4;
    --text-main: #F3F4F6;
    --text-muted: #9CA3AF;
}
html, body, #page, .site, main, .wp-site-blocks, .site-content {
    background-color: var(--bg-dark) !important;
    color: var(--text-main) !important;
    font-family: Inter, system-ui, -apple-system, sans-serif !important;
}
h1, h2, h3, h4, .site-title a, .wp-block-post-title a, .entry-title a {
    color: #FFFFFF !important;
    font-weight: 800 !important;
}
article, .wp-block-post, .entry {
    background-color: var(--card-bg) !important;
    border: 1px solid #1F2937 !important;
    border-radius: 0.75rem !important;
    padding: 2rem !important;
    margin-bottom: 2rem !important;
    box-sizing: border-box !important;
}
.wp-block-post-excerpt p, .entry-content p {
    color: var(--text-muted) !important;
}
a {
    color: var(--accent-cyan) !important;
    text-decoration: none !important;
}
a:hover {
    color: var(--accent-blue) !important;
}
.wp-block-navigation .wp-block-navigation-item__content {
    color: var(--text-muted) !important;
}
footer, .site-footer {
    background-color: #030712 !important;
    border-top: 1px solid #1F2937 !important;
    padding: 3rem 2rem !important;
    color: var(--text-muted) !important;
}
</style>
TAI_CSS;
    }
    add_action('wp_head', 'ctf_tai_corporate_theme', 999);
}
PHP
fi

chown -R www-data:www-data "${WP_PATH}/wp-content/themes"
nginx -t
systemctl reload nginx

# Verificaciones finales.
sudo -u www-data wp core is-installed --path="$WP_PATH"
mysql -N -e "SELECT option_value FROM wordpress.wp_options WHERE option_name='blogname';"
curl -fsS -o /dev/null -w 'HTTP status: %{http_code}\n' "$WP_URL/"

echo "wordpress ready" > /var/log/prov.done
echo "Despliegue completado: ${WP_URL}"
