#!/bin/bash
# PostgreSQL (Ubuntu) con BD de ejemplo poblada, accesible desde la VPC.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y postgresql
PGVER=$(ls /etc/postgresql/)
echo "listen_addresses = '*'" >> /etc/postgresql/${PGVER}/main/postgresql.conf
# VULNERABILIDAD (pg_hba permisivo): la subred de clientes accede sin contraseña.
# pg_hba evalúa las reglas en orden, por eso esta línea va antes que la regla md5 de la VPC
echo "host all all 10.0.4.0/24 trust" >> /etc/postgresql/${PGVER}/main/pg_hba.conf
echo "host all all 10.0.0.0/16 md5" >> /etc/postgresql/${PGVER}/main/pg_hba.conf
systemctl enable --now postgresql
sudo -u postgres psql <<'SQL'
-- VULNERABILIDAD (contraseña débil del superusuario)
ALTER USER postgres WITH PASSWORD 'postgres';
CREATE DATABASE crm;
CREATE USER app WITH PASSWORD 'App#2026';
GRANT ALL PRIVILEGES ON DATABASE crm TO app;
\c crm
CREATE TABLE clientes(id SERIAL PRIMARY KEY, nombre TEXT, sector TEXT);
INSERT INTO clientes(nombre,sector) VALUES ('ACME','Industria'),('Globex','Retail'),('Initech','Software');
GRANT ALL ON ALL TABLES IN SCHEMA public TO app;
SQL
systemctl restart postgresql
echo "postgres ready" > /var/log/prov.done
