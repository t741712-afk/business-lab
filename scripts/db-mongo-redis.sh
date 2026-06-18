#!/bin/bash
# NoSQL: MongoDB + Redis (Amazon Linux), accesibles desde la VPC.
set -x
dnf -y update
# Redis
dnf -y install redis6 || dnf -y install redis
sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis6/redis6.conf 2>/dev/null || sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf 2>/dev/null
systemctl enable --now redis6 2>/dev/null || systemctl enable --now redis
# MongoDB (repo oficial)
cat > /etc/yum.repos.d/mongodb-org-7.0.repo <<'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF
dnf -y install mongodb-org
sed -i 's/  bindIp:.*/  bindIp: 0.0.0.0/' /etc/mongod.conf
systemctl enable --now mongod
sleep 10
# Datos de ejemplo
mongosh --quiet --eval 'db = db.getSiblingDB("inventario"); db.productos.insertMany([{sku:"A1",stock:42},{sku:"B2",stock:7}]);' || true
echo "mongo-redis ready" > /var/log/prov.done
