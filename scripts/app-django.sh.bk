#!/bin/bash
# App Python/Django (Ubuntu) servida con gunicorn via systemd en :8000.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-pip python3-venv
python3 -m venv /opt/django/venv
/opt/django/venv/bin/pip install --upgrade pip django gunicorn
cd /opt/django
/opt/django/venv/bin/django-admin startproject corp .
# Permitir cualquier host (lab)
sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = ['*']/" /opt/django/corp/settings.py
/opt/django/venv/bin/python manage.py migrate
cat > /etc/systemd/system/django.service <<'EOF'
[Unit]
Description=Corp Django
After=network.target
[Service]
WorkingDirectory=/opt/django
ExecStart=/opt/django/venv/bin/gunicorn --bind 0.0.0.0:8000 corp.wsgi
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now django
echo "django ready" > /var/log/prov.done
