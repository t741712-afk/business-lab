#!/bin/bash
# TAI Corporate Intranet — Django + Gunicorn + systemd
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

APP_DIR="/opt/django"
VENV="${APP_DIR}/venv"
SERVICE="/etc/systemd/system/django.service"

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

apt-get update -y
apt-get install -y python3-pip python3-venv

if ! id django >/dev/null 2>&1; then
    useradd --system --home-dir "${APP_DIR}" --shell /usr/sbin/nologin django
fi

mkdir -p "${APP_DIR}"
cd "${APP_DIR}"

python3 -m venv "${VENV}"
"${VENV}/bin/pip" install --upgrade pip
"${VENV}/bin/pip" install "Django>=5.2,<6.0" gunicorn

if [[ ! -f manage.py ]]; then
    "${VENV}/bin/django-admin" startproject corp .
fi

mkdir -p templates/intranet

cat > corp/views.py <<'PY'
from django.shortcuts import render
from django.utils import timezone
from django.views.decorators.http import require_GET


@require_GET
def intranet(request):
    context = {
        "current_date": timezone.localdate(),
        "employee": {
            "name": "Alex Morgan",
            "role": "Research & Development",
            "initials": "AM",
        },
        "announcements": [
            {
                "category": "CORPORATE",
                "date": "18 OCT",
                "title": "Internal Policy Updates",
                "description": "Review the latest updates to corporate procedures, security guidelines, and compliance policies.",
                "color": "blue",
            },
            {
                "category": "RESEARCH",
                "date": "17 OCT",
                "title": "New Molecular Analysis Environment",
                "description": "The new research workspace is now available to authorized research teams.",
                "color": "cyan",
            },
            {
                "category": "HUMAN RESOURCES",
                "date": "15 OCT",
                "title": "Training Calendar",
                "description": "Explore upcoming technical training sessions and professional development opportunities.",
                "color": "purple",
            },
        ],
        "quick_links": [
            {
                "icon": "♙",
                "title": "My Profile",
                "description": "Personal information and professional details",
                "url": "#profile",
            },
            {
                "icon": "▦",
                "title": "Calendar",
                "description": "Events, meetings, and training sessions",
                "url": "#calendar",
            },
            {
                "icon": "▤",
                "title": "Documentation",
                "description": "Policies, procedures, and resources",
                "url": "#documentation",
            },
            {
                "icon": "♧",
                "title": "Directory",
                "description": "Teams and departments",
                "url": "#directory",
            },
        ],
    }
    return render(request, "intranet/dashboard.html", context)
PY

cat > corp/urls.py <<'PY'
from django.contrib import admin
from django.urls import path
from corp.views import intranet

urlpatterns = [
    path("", intranet, name="intranet"),
    path("admin/", admin.site.urls),
]
PY

python3 - <<'PY'
from pathlib import Path

settings = Path("/opt/django/corp/settings.py")
content = settings.read_text()

content = content.replace(
    "ALLOWED_HOSTS = []",
    'ALLOWED_HOSTS = ["*"]',
)

content = content.replace(
    "'DIRS': [],",
    "'DIRS': [BASE_DIR / " + '"templates"' + "],",
)

settings.write_text(content)
PY

cat > templates/intranet/dashboard.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#0B0F19">
    <meta name="description" content="TAI Laboratories Corporation employee intranet portal.">
    <title>Corporate Intranet | TAI</title>
    <style>
        :root {
            color-scheme: dark;
            --bg: #0B0F19;
            --card: #111827;
            --card-hover: #172235;
            --blue: #3B82F6;
            --cyan: #06B6D4;
            --text: #F3F4F6;
            --muted: #9CA3AF;
            --border: #1F2937;
            --green: #34D399;
            --radius: 12px;
        }

        * { box-sizing: border-box; }

        html {
            scroll-behavior: smooth;
            scroll-padding-top: 100px;
        }

        body {
            margin: 0;
            min-height: 100vh;
            background:
                radial-gradient(ellipse at 85% 0%, rgba(6,182,212,.09), transparent 38%),
                var(--bg);
            color: var(--text);
            font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            line-height: 1.6;
        }

        a { color: inherit; text-decoration: none; }

        a:focus-visible {
            outline: 2px solid var(--cyan);
            outline-offset: 4px;
        }

        .topbar {
            position: sticky;
            top: 0;
            z-index: 10;
            border-bottom: 1px solid var(--border);
            background: rgba(11,15,25,.92);
            backdrop-filter: blur(16px);
        }

        .nav {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 24px;
            width: min(1240px, 100%);
            min-height: 76px;
            margin: auto;
            padding: 14px 28px;
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 12px;
            min-width: 0;
        }

        .brand-mark {
            display: grid;
            place-items: center;
            width: 42px;
            height: 42px;
            flex-shrink: 0;
            border-radius: 11px;
            background: linear-gradient(135deg, var(--blue), var(--cyan));
            color: white;
            font-size: 20px;
            font-weight: 900;
        }

        .brand-name {
            font-size: 14px;
            font-weight: 800;
            letter-spacing: 1.2px;
            line-height: 1.3;
        }

        .brand-name span {
            background: linear-gradient(90deg, var(--blue), var(--cyan));
            -webkit-background-clip: text;
            background-clip: text;
            color: transparent;
        }

        .brand-subtitle {
            margin-top: 3px;
            color: var(--muted);
            font-size: 11px;
            letter-spacing: .5px;
        }

        .nav-right {
            display: flex;
            align-items: center;
            gap: 20px;
        }

        .status {
            display: flex;
            align-items: center;
            gap: 8px;
            color: var(--muted);
            font-size: 12px;
            white-space: nowrap;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--green);
            box-shadow: 0 0 12px rgba(52,211,153,.4);
        }

        .avatar {
            display: grid;
            place-items: center;
            width: 42px;
            height: 42px;
            flex-shrink: 0;
            border: 1px solid rgba(59,130,246,.4);
            border-radius: 50%;
            background: linear-gradient(135deg, #1D4ED8, #0891B2);
            color: white;
            font-size: 13px;
            font-weight: 800;
        }

        .container {
            width: min(1184px, 100%);
            margin: auto;
            padding: 44px 24px 72px;
        }

        .welcome {
            display: flex;
            align-items: flex-end;
            justify-content: space-between;
            gap: 24px;
            margin-bottom: 32px;
        }

        .eyebrow {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 14px;
            color: #60A5FA;
            font-size: 11px;
            font-weight: 800;
            letter-spacing: 1.7px;
        }

        .eyebrow::before {
            width: 22px;
            height: 2px;
            background: var(--cyan);
            content: "";
        }

        h1, h2, h3, p { margin-top: 0; }

        .welcome h1 {
            margin-bottom: 10px;
            font-size: clamp(29px, 4vw, 43px);
            font-weight: 800;
            line-height: 1.14;
            letter-spacing: -1.2px;
        }

        .welcome h1 span {
            background: linear-gradient(90deg, #22D3EE, #3B82F6);
            -webkit-background-clip: text;
            background-clip: text;
            color: transparent;
        }

        .welcome p {
            margin-bottom: 0;
            color: var(--muted);
            font-size: 14px;
        }

        .date-card {
            min-width: 150px;
            padding: 13px 17px;
            border: 1px solid var(--border);
            border-radius: 10px;
            background: rgba(17,24,39,.72);
        }

        .date-label {
            color: var(--muted);
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 1.2px;
        }

        .date-value {
            margin-top: 3px;
            font-size: 14px;
            font-weight: 700;
        }

        .hero-panel {
            position: relative;
            overflow: hidden;
            padding: 30px;
            margin-bottom: 38px;
            border: 1px solid #24364F;
            border-radius: var(--radius);
            background:
                radial-gradient(ellipse at 95% 10%, rgba(6,182,212,.15), transparent 38%),
                linear-gradient(120deg, #111827, #101B30);
        }

        .hero-panel::after {
            position: absolute;
            top: 50%;
            right: 38px;
            transform: translateY(-50%);
            color: rgba(96,165,250,.055);
            font-size: clamp(100px, 17vw, 190px);
            font-weight: 900;
            letter-spacing: -12px;
            content: "TAI";
            pointer-events: none;
        }

        .panel-content {
            position: relative;
            z-index: 1;
            max-width: 650px;
        }

        .pill {
            display: inline-block;
            padding: 5px 10px;
            margin-bottom: 14px;
            border: 1px solid rgba(6,182,212,.25);
            border-radius: 20px;
            background: rgba(6,182,212,.08);
            color: #67E8F9;
            font-size: 10px;
            font-weight: 800;
            letter-spacing: 1px;
        }

        .hero-panel h2 {
            margin-bottom: 10px;
            font-size: clamp(22px, 3vw, 30px);
            line-height: 1.3;
        }

        .hero-panel p {
            max-width: 570px;
            margin-bottom: 0;
            color: #A8B4C7;
            font-size: 14px;
        }

        .section-heading {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            margin-bottom: 20px;
        }

        .section-heading h2 {
            margin-bottom: 0;
            font-size: 19px;
            font-weight: 750;
        }

        .section-caption {
            color: var(--muted);
            font-size: 12px;
        }

        .quick-grid {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 16px;
            margin-bottom: 42px;
        }

        .quick-card {
            display: flex;
            flex-direction: column;
            min-height: 166px;
            padding: 21px;
            border: 1px solid var(--border);
            border-radius: 11px;
            background: var(--card);
            transition: transform .2s, border-color .2s, background .2s;
        }

        .quick-card:hover {
            transform: translateY(-3px);
            border-color: rgba(6,182,212,.45);
            background: var(--card-hover);
        }

        .quick-icon {
            display: grid;
            place-items: center;
            width: 42px;
            height: 42px;
            margin-bottom: 17px;
            border: 1px solid rgba(59,130,246,.2);
            border-radius: 10px;
            background: rgba(59,130,246,.1);
            color: #60A5FA;
            font-size: 22px;
        }

        .quick-card h3 {
            margin-bottom: 5px;
            font-size: 14px;
        }

        .quick-card p {
            margin-bottom: 0;
            color: var(--muted);
            font-size: 11px;
            line-height: 1.6;
        }

        .content-grid {
            display: grid;
            grid-template-columns: minmax(0, 1.65fr) minmax(260px, 1fr);
            gap: 24px;
        }

        .surface {
            min-width: 0;
            padding: 24px;
            border: 1px solid var(--border);
            border-radius: var(--radius);
            background: rgba(17,24,39,.84);
        }

        .announcement-list {
            display: grid;
            gap: 0;
        }

        .announcement {
            display: flex;
            align-items: flex-start;
            gap: 15px;
            padding: 19px 0;
            border-bottom: 1px solid var(--border);
        }

        .announcement:first-child { padding-top: 8px; }

        .announcement:last-child {
            padding-bottom: 0;
            border-bottom: 0;
        }

        .announcement-date {
            display: grid;
            place-items: center;
            width: 53px;
            height: 53px;
            flex-shrink: 0;
            border: 1px solid var(--border);
            border-radius: 9px;
            background: #0B1220;
            color: #D1D5DB;
            font-size: 10px;
            font-weight: 800;
            text-align: center;
        }

        .announcement-category {
            display: block;
            margin-bottom: 5px;
            font-size: 9px;
            font-weight: 800;
            letter-spacing: 1px;
        }

        .blue { color: #60A5FA; }
        .cyan { color: #22D3EE; }
        .purple { color: #C4B5FD; }

        .announcement h3 {
            margin-bottom: 6px;
            font-size: 14px;
            line-height: 1.45;
        }

        .announcement p {
            margin-bottom: 0;
            color: var(--muted);
            font-size: 12px;
            line-height: 1.7;
        }

        .team-card {
            padding: 20px;
            margin-bottom: 14px;
            border: 1px solid var(--border);
            border-radius: 10px;
            background: #0D1422;
        }

        .team-card:last-child { margin-bottom: 0; }

        .team-top {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 14px;
        }

        .team-icon {
            display: grid;
            place-items: center;
            width: 40px;
            height: 40px;
            border-radius: 10px;
            background: rgba(6,182,212,.1);
            color: #67E8F9;
            font-size: 20px;
        }

        .team-top h3 {
            margin-bottom: 2px;
            font-size: 13px;
        }

        .team-top p {
            margin-bottom: 0;
            color: var(--muted);
            font-size: 11px;
        }

        .team-link {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding-top: 12px;
            border-top: 1px solid var(--border);
            color: #93C5FD;
            font-size: 12px;
            font-weight: 650;
        }

        .team-link:hover { color: var(--cyan); }

        .footer {
            padding: 22px 24px;
            border-top: 1px solid var(--border);
            background: #070B13;
            color: var(--muted);
            font-size: 11px;
        }

        .footer-inner {
            display: flex;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
            width: min(1184px, 100%);
            margin: auto;
        }

        .footer strong { color: #D1D5DB; }

        @media (max-width: 900px) {
            .quick-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
            .content-grid { grid-template-columns: 1fr; }
            .hero-panel::after { right: 15px; }
        }

        @media (max-width: 600px) {
            .nav { padding: 12px 16px; }
            .brand-name { font-size: 11px; letter-spacing: .7px; }
            .brand-subtitle { font-size: 10px; }
            .brand-mark { width: 36px; height: 36px; }
            .nav-right { gap: 10px; }
            .status { font-size: 0; gap: 0; }
            .status-dot { width: 9px; height: 9px; }
            .avatar { width: 36px; height: 36px; }
            .container { padding: 32px 16px 48px; }
            .welcome { align-items: flex-start; flex-direction: column; }
            .date-card { min-width: 0; }
            .hero-panel { padding: 23px; }
            .hero-panel::after { right: 10px; font-size: 100px; }
            .quick-grid { gap: 11px; }
            .quick-card { min-height: 155px; padding: 16px; }
            .surface { padding: 18px; }
            .section-heading { align-items: flex-start; flex-direction: column; }
            .announcement { gap: 11px; }
            .announcement-date { width: 47px; height: 47px; }
            .footer-inner { flex-direction: column; }
        }

        @media (prefers-reduced-motion: reduce) {
            *, *::before, *::after {
                scroll-behavior: auto !important;
                transition-duration: .01ms !important;
            }
        }
    </style>
</head>
<body>
    <header class="topbar">
        <nav class="nav" aria-label="Main navigation">
            <a class="brand" href="/" aria-label="TAI Intranet home">
                <span class="brand-mark" aria-hidden="true">T</span>
                <span>
                    <span class="brand-name">LABORATORIES CORPORATION <span>TAI</span></span>
                    <span class="brand-subtitle">CORPORATE EMPLOYEE PORTAL</span>
                </span>
            </a>
            <div class="nav-right">
                <div class="status">
                    <span class="status-dot" aria-hidden="true"></span>
                    All systems operational
                </div>
                <a class="avatar" href="#profile" aria-label="Profile of {{ employee.name }}">
                    {{ employee.initials }}
                </a>
            </div>
        </nav>
    </header>

    <main class="container">
        <section class="welcome" aria-labelledby="welcome-title">
            <div>
                <div class="eyebrow">YOUR DIGITAL WORKSPACE</div>
                <h1 id="welcome-title">Welcome back,<br><span>{{ employee.name }}</span></h1>
                <p>Everything you need for your workday, all in one place.</p>
            </div>
            <div class="date-card">
                <div class="date-label">TODAY'S DATE</div>
                <div class="date-value">{{ current_date|date:"d/m/Y" }}</div>
            </div>
        </section>

        <section class="hero-panel" aria-labelledby="hero-title">
            <div class="panel-content">
                <span class="pill">INTRANET · TAI CORPORATION</span>
                <h2>Connecting teams.<br>Driving innovation.</h2>
                <p>Access corporate tools, stay up to date with company news, and collaborate with the teams transforming research.</p>
            </div>
        </section>

        <section id="quick-access" aria-labelledby="quick-title">
            <div class="section-heading">
                <h2 id="quick-title">Quick Access</h2>
                <span class="section-caption">Your corporate resources</span>
            </div>
            <div class="quick-grid">
                {% for item in quick_links %}
                <a class="quick-card" href="{{ item.url }}">
                    <span class="quick-icon" aria-hidden="true">{{ item.icon }}</span>
                    <h3>{{ item.title }}</h3>
                    <p>{{ item.description }}</p>
                </a>
                {% endfor %}
            </div>
        </section>

        <div class="content-grid">
            <section class="surface" id="news" aria-labelledby="news-title">
                <div class="section-heading">
                    <h2 id="news-title">Latest News</h2>
                    <span class="section-caption">Corporate updates</span>
                </div>
                <div class="announcement-list">
                    {% for item in announcements %}
                    <article class="announcement">
                        <div class="announcement-date">{{ item.date }}</div>
                        <div>
                            <span class="announcement-category {{ item.color }}">{{ item.category }}</span>
                            <h3>{{ item.title }}</h3>
                            <p>{{ item.description }}</p>
                        </div>
                    </article>
                    {% endfor %}
                </div>
            </section>

            <aside class="surface" aria-labelledby="team-title">
                <div class="section-heading">
                    <h2 id="team-title">My Workspace</h2>
                </div>

                <article class="team-card" id="profile">
                    <div class="team-top">
                        <div class="team-icon" aria-hidden="true">♙</div>
                        <div>
                            <h3>My Space</h3>
                            <p>{{ employee.role }}</p>
                        </div>
                    </div>
                    <a class="team-link" href="#profile">View My Profile <span aria-hidden="true">→</span></a>
                </article>

                <article class="team-card" id="documentation">
                    <div class="team-top">
                        <div class="team-icon" aria-hidden="true">▤</div>
                        <div>
                            <h3>Document Center</h3>
                            <p>Resources and procedures</p>
                        </div>
                    </div>
                    <a class="team-link" href="#documentation">Browse Documents <span aria-hidden="true">→</span></a>
                </article>

                <article class="team-card" id="directory">
                    <div class="team-top">
                        <div class="team-icon" aria-hidden="true">♧</div>
                        <div>
                            <h3>Company Directory</h3>
                            <p>Teams and departments</p>
                        </div>
                    </div>
                    <a class="team-link" href="#directory">View Departments <span aria-hidden="true">→</span></a>
                </article>
            </aside>
        </div>
    </main>

    <footer class="footer">
        <div class="footer-inner">
            <span>© 2026 <strong>Laboratories Corporation TAI</strong>. Internal use only.</span>
            <span>Corporate Intranet · Digital Workplace</span>
        </div>
    </footer>
</body>
</html>
HTML

cat > "${SERVICE}" <<'UNIT'
[Unit]
Description=TAI Corporate Intranet - Django Gunicorn
After=network.target

[Service]
Type=simple
User=django
Group=django
WorkingDirectory=/opt/django
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/django/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 --access-logfile - --error-logfile - corp.wsgi:application
Restart=always
RestartSec=3
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

chown -R django:django "${APP_DIR}"

"${VENV}/bin/python" manage.py check
"${VENV}/bin/python" manage.py migrate --noinput

# VULNERABILIDAD (cuenta de administrador por defecto): superusuario con contraseña conocida
DJANGO_SUPERUSER_USERNAME=admin \
DJANGO_SUPERUSER_EMAIL=admin@business-lab.local \
DJANGO_SUPERUSER_PASSWORD='Admin#2026' \
"${VENV}/bin/python" manage.py createsuperuser --noinput || true

systemctl daemon-reload
systemctl enable django
systemctl restart django

echo "django ready" > /var/log/prov.done

echo "Intranet available at http://<SERVER_IP>:8000"
systemctl --no-pager --full status django