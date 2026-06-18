#!/bin/bash
# Frontal WordPress (Ubuntu 22.04): nginx + php-fpm + mariadb local + WordPress.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx mariadb-server php-fpm php-mysql php-curl php-gd php-xml php-mbstring curl
systemctl enable --now mariadb
DBPASS="WpLab#2026"
mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
mysql -e "CREATE USER IF NOT EXISTS 'wp'@'localhost' IDENTIFIED BY '${DBPASS}';"
mysql -e "GRANT ALL ON wordpress.* TO 'wp'@'localhost'; FLUSH PRIVILEGES;"
# Descargar WordPress
cd /var/www
curl -fsSL https://wordpress.org/latest.tar.gz | tar xz
cp -r wordpress/* /var/www/html/ 2>/dev/null || true
cd /var/www/html
[ -f wp-config-sample.php ] && cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/wordpress/; s/username_here/wp/; s/password_here/${DBPASS}/" wp-config.php
chown -R www-data:www-data /var/www/html
PHPVER=$(ls /run/php/ | grep -oP 'php\K[0-9.]+' | head -1)
cat > /etc/nginx/sites-available/default <<EOF
server { listen 80 default_server; root /var/www/html; index index.php index.html;
  location / { try_files \$uri \$uri/ /index.php?\$args; }
  location ~ \.php\$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php${PHPVER}-fpm.sock; }
}
EOF
systemctl enable --now php${PHPVER}-fpm nginx
systemctl restart nginx
echo "wordpress ready" > /var/log/prov.done
