#!/bin/bash
# Intranet corporativa (Amazon Linux 2023): httpd + Wiki de Investigacion Avanzada.
set -x
set -e

echo "==> Actualizando el sistema operativo e instalando Apache httpd..."
dnf -y update
dnf -y install httpd

echo "==> Creando el directorio web raiz si no existiera..."
mkdir -p /var/www/html

echo "==> Inyectando el portal Wiki Corporativo avanzado en index.html..."
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TAI Labs | Corporate Knowledge Base</title>
    <style>
        :root {
            --bg-dark: #070B14; --panel-bg: #0F172A; --accent-cyan: #06B6D4;
            --accent-blue: #3B82F6; --text-main: #F3F4F6; --text-muted: #64748B;
            --border-color: #1E293B; --alert-red: #EF4444;
        }
        body { font-family: 'Segoe UI', system-ui, sans-serif; background-color: var(--bg-dark); color: var(--text-main); margin: 0; padding: 0; line-height: 1.6; }
        header { background-color: rgba(15, 23, 42, 0.8); backdrop-filter: blur(8px); border-bottom: 1px solid var(--border-color); padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; }
        header h1 { margin: 0; font-size: 1.25rem; font-weight: 800; letter-spacing: 1px; }
        header h1 span { color: var(--accent-cyan); }
        nav { display: flex; gap: 1rem; }
        .nav-link { color: var(--text-muted); text-decoration: none; font-weight: 600; font-size: 0.9rem; padding: 0.5rem 1rem; border-radius: 0.375rem; cursor: pointer; transition: all 0.2s; }
        .nav-link:hover, .nav-link.active { color: var(--text-main); background-color: var(--border-color); }
        .nav-link.active { border-bottom: 2px solid var(--accent-cyan); }
        .container { max-width: 1100px; margin: 3rem auto; padding: 0 2rem; }
        .confidential-banner { background: rgba(239, 68, 68, 0.1); border: 1px solid var(--alert-red); border-left: 4px solid var(--alert-red); color: #FCA5A5; padding: 1rem; border-radius: 0.375rem; font-weight: bold; margin-bottom: 2rem; font-size: 0.9rem; letter-spacing: 0.5px; }
        .wiki-panel { background-color: var(--panel-bg); border: 1px solid var(--border-color); border-radius: 0.5rem; padding: 2.5rem; box-shadow: 0 4px 20px rgba(0,0,0,0.4); }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        h2 { margin-top: 0; font-size: 1.5rem; color: #FFF; border-bottom: 1px solid var(--border-color); padding-bottom: 0.5rem; }
        h3 { color: var(--accent-cyan); font-size: 1.1rem; margin-top: 1.5rem; }
        ul { padding-left: 1.25rem; }
        li { margin-bottom: 0.5rem; }
        code { font-family: monospace; background: #070B14; color: #34D399; padding: 0.2rem 0.4rem; border-radius: 4px; font-size: 0.9rem; }
        .network-box { background: #070B14; border: 1px solid var(--border-color); padding: 1rem; border-radius: 0.375rem; font-family: monospace; color: var(--accent-cyan); margin-top: 1rem; }
        footer { margin-top: 5rem; border-top: 1px solid var(--border-color); padding-top: 1.5rem; font-size: 0.8rem; color: var(--text-muted); text-align: center; }
    </style>
</head>
<body>
    <header>
        <h1>TAI LABORATORIES | <span>INTERNAL WIKI</span></h1>
        <nav>
            <div class="nav-link active" onclick="switchTab('main')">Home Base</div>
            <div class="nav-link" onclick="switchTab('hr')">HR & Vacations</div>
            <div class="nav-link" onclick="switchTab('it')">IT Support</div>
            <div class="nav-link" onclick="switchTab('finance')">Finance & Assets</div>
        </nav>
    </header>

    <main class="container">
        <div class="confidential-banner">RESTRICTED ACCESS: INTERNAL CORPORATE NETWORK ONLY (MZ DMZ-ZONE).</div>
        <div class="wiki-panel">
            <div id="tab-main" class="tab-content active">
                <h2>Berlin HQ Core Knowledge Portal</h2>
                <p>Welcome to the central information repository for <strong>Laboratories Corporation TAI</strong>.</p>
                <h3>Active Research Projects Telemetry:</h3>
                <ul>
                    <li><code>PRJ-01-GANs</code>: Training pipelines for molecular digital twins.</li>
                    <li><code>PRJ-03-IMMUNO</code>: Machine learning datasets applied to cancer cell sequence customization.</li>
                </ul>
            </div>
            <div id="tab-hr" class="tab-content">
                <h2>Human Resources & Personnel Portal</h2>
                <p>Corporate management and operational workflow patterns for scientists.</p>
                <ul>
                    <li><strong>Vacation Requests:</strong> All applications must be submitted 15 days in advance.</li>
                </ul>
            </div>
            <div id="tab-it" class="tab-content">
                <h2>IT Infrastructure & Helpdesk Node</h2>
                <p>Central management directory for active technicians.</p>
                <div class="network-box">\\\\10.0.3.12\\Public\\Research_Backups</div>
            </div>
            <div id="tab-finance" class="tab-content">
                <h2>Finance & Computational Assets Inventory</h2>
                <p>Control board for high-performance computing resources.</p>
                <ul>
                    <li><strong>Node-01 (API Gateway)</strong>: <code>10.0.1.12:3000</code></li>
                    <li><strong>Node-02 (Java Compute)</strong>: <code>10.0.1.11:8080</code></li>
                </ul>
            </div>
        </div>
    </main>
    <footer>&copy; 2026 Laboratories Corporation TAI. Berlin Global HQ.</footer>

    <script>
        function switchTab(tabName) {
            document.querySelectorAll('.nav-link').forEach(link => link.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            const targetLink = Array.from(document.querySelectorAll('.nav-link')).find(link => {
                const txt = link.innerText.toLowerCase();
                return tabName === 'main' ? txt.includes('home') : txt.includes(tabName);
            });
            if(targetLink) targetLink.classList.add('active');
            const targetContent = document.getElementById('tab-' + tabName);
            if(targetContent) targetContent.classList.add('active');
        }
    </script>
</body>
</html>
EOF

echo "==> Ajustando permisos para el usuario de Apache (httpd)..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

echo "==> Esperando el asentamiento de archivos en disco duro..."
sleep 2 # <--- CRÍTICO: Da margen a que el archivo index.html se cierre por completo

echo "==> Iniciando y forzando REINICIO DURO de httpd..."
systemctl enable httpd
systemctl stop httpd
sleep 1
systemctl start httpd # <--- Blinda el vaciado de memoria RAM de forma automática

echo "intranet ready" > /var/log/prov.done
