#!/bin/bash
# MySQL/MariaDB (Ubuntu) con BD de ejemplo poblada. Escucha en toda la VPC.
# Endurecido: reintentos de apt, espera al socket, bind-address robusto y verificacion.
set -x
export DEBIAN_FRONTEND=noninteractive

# apt con reintentos (la salida por NAT puede tardar en estar lista)
for i in $(seq 1 10); do apt-get update -y && break; sleep 15; done
for i in $(seq 1 10); do apt-get install -y mariadb-server && break; sleep 15; done

# Escuchar en toda la red interna (cubre cualquier variante/espaciado del fichero)
sed -ri 's/^[[:space:]]*bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl enable mariadb
systemctl restart mariadb

# Esperar a que MariaDB acepte conexiones antes de operar
for i in $(seq 1 30); do mysqladmin ping --silent 2>/dev/null && break; sleep 5; done

ROOTPASS="DbRoot#2026"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOTPASS}';" || true
mysql -uroot -p${ROOTPASS} -e "CREATE DATABASE IF NOT EXISTS empresa;"
mysql -uroot -p${ROOTPASS} -e "CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY 'App#2026'; GRANT ALL ON empresa.* TO 'app'@'%'; FLUSH PRIVILEGES;"
mysql -uroot -p${ROOTPASS} empresa <<'SQL'
CREATE TABLE IF NOT EXISTS empleados(id INT PRIMARY KEY AUTO_INCREMENT, nombre VARCHAR(80), depto VARCHAR(40));
INSERT INTO empleados(nombre,depto) VALUES ('Juan Garcia','IT'),('Maria Lopez','RRHH'),('Ana Fernandez','Finanzas');
CREATE TABLE IF NOT EXISTS pedidos(id INT PRIMARY KEY AUTO_INCREMENT, cliente VARCHAR(80), total DECIMAL(10,2));
INSERT INTO pedidos(cliente,total) VALUES ('ACME',1200.50),('Globex',840.00);
SQL

# Verificar que realmente escucha en 3306 en todas las interfaces
if ss -ltn 2>/dev/null | grep -qE '0\.0\.0\.0:3306|\*:3306|:::3306'; then
  echo "mysql ready - LISTEN 0.0.0.0:3306 OK" > /var/log/prov.done
else
  echo "WARN: mariadb arrancada pero NO escucha en 3306 en red - revisar 50-server.cnf" > /var/log/prov.done
  ss -ltn | grep 3306 >> /var/log/prov.done 2>&1
fi
