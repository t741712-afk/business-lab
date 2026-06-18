#!/bin/bash
# PostgreSQL (Ubuntu) con BD de ejemplo poblada, accesible desde la VPC.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y postgresql
PGVER=$(ls /etc/postgresql/)
echo "listen_addresses = '*'" >> /etc/postgresql/${PGVER}/main/postgresql.conf
echo "host all all 10.0.0.0/16 md5" >> /etc/postgresql/${PGVER}/main/pg_hba.conf
systemctl enable --now postgresql
sudo -u postgres psql <<'SQL'
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
