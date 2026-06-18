#!/bin/bash
# MySQL/MariaDB (Ubuntu) con BD de ejemplo poblada. Escucha en toda la VPC.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server
# Escuchar en la red interna
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl enable --now mariadb
ROOTPASS="DbRoot#2026"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOTPASS}';"
mysql -uroot -p${ROOTPASS} -e "CREATE DATABASE IF NOT EXISTS empresa;"
mysql -uroot -p${ROOTPASS} -e "CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY 'App#2026'; GRANT ALL ON empresa.* TO 'app'@'%'; FLUSH PRIVILEGES;"
mysql -uroot -p${ROOTPASS} empresa <<'SQL'
CREATE TABLE IF NOT EXISTS empleados(id INT PRIMARY KEY AUTO_INCREMENT, nombre VARCHAR(80), depto VARCHAR(40));
INSERT INTO empleados(nombre,depto) VALUES ('Juan Garcia','IT'),('Maria Lopez','RRHH'),('Ana Fernandez','Finanzas');
CREATE TABLE IF NOT EXISTS pedidos(id INT PRIMARY KEY AUTO_INCREMENT, cliente VARCHAR(80), total DECIMAL(10,2));
INSERT INTO pedidos(cliente,total) VALUES ('ACME',1200.50),('Globex',840.00);
SQL
echo "mysql ready" > /var/log/prov.done
