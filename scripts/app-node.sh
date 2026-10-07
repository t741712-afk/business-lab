#!/bin/bash
# API REST Avanzada de TAI Labs (Consola Interactiva 100% Local + 50 Secuencias)
set -x
set -e

echo "==> Asegurando entorno de ejecucion..."
dnf -y install nodejs npm

echo "==> Preparando el directorio de la aplicacion..."
mkdir -p /opt/api

echo "==> Escribiendo codigo con dataset extendido y Consola de Control Autonoma en server.js..."
cat > /opt/api/server.js <<'EOF'
const http = require('http');
const os = require('os');

// Dataset automatizado de 50 secuencias moleculares detalladas para Laboratories Corporation TAI
let molecularSequences = [];
const types = ["Immunotherapy", "Pathogen_Twin", "Molecular_Synth", "Genomic_Variant", "Neuro_Model"];
const statuses = ["Verified", "In_Progress", "Simulated", "Under_Review"];

for (let i = 1; i <= 50; i++) {
  const type = types[i % types.length];
  const status = statuses[i % statuses.length];
  const randMatch = (Math.random() * (100 - 88) + 88).toFixed(2) + "%";
  
  molecularSequences.push({
    id: `TAI-${String(i).padStart(3, '0')}`,
    name: `${type}_Cluster_Beta_${i * 7}`,
    status: status,
    match_rate: randMatch
  });
}

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  
  // 1. Endpoint de salud
  if (req.url === '/health' || req.url === '/api/health') {
    return res.end(JSON.stringify({ status: 'ok' }));
  }
  
  // 2. CONSOLA DE INTERACCION CORPORATIVA (Endpoint: /api/docs) - 100% Autónoma y Local
  if (req.url === '/docs' || req.url === '/api/docs' || req.url === '/api/docs/') {
    res.setHeader('Content-Type', 'text/html');
    return res.end(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>TAI Labs | Interactive Console</title>
        <style>
          body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0B0F19; color: #F3F4F6; margin: 0; padding: 2rem; }
          .container { max-width: 900px; margin: 0 auto; }
          h1 { font-size: 1.8rem; font-weight: 800; border-bottom: 1px solid #1F2937; padding-bottom: 1rem; }
          h1 span { color: #06B6D4; }
          .endpoint-block { background: #111827; border: 1px solid #1F2937; border-radius: 0.5rem; padding: 1.5rem; margin-bottom: 1.5rem; }
          .badge { padding: 0.25rem 0.6rem; border-radius: 4px; font-weight: bold; font-family: monospace; font-size: 0.85rem; margin-right: 0.5rem; }
          .get { background: rgba(59, 130, 246, 0.2); color: #60A5FA; border: 1px solid #3B82F6; }
          .post { background: rgba(16, 185, 129, 0.2); color: #34D399; border: 1px solid #10B981; }
          .path { font-family: monospace; font-weight: bold; color: #E5E7EB; font-size: 1rem; }
          .desc { color: #9CA3AF; margin: 0.5rem 0 1rem; font-size: 0.95rem; }
          button { background: #2563EB; color: white; border: none; padding: 0.5rem 1rem; border-radius: 0.375rem; font-weight: 600; cursor: pointer; }
          button:hover { background: #1D4ED8; }
          .form-input { background: #090D16; border: 1px solid #1F2937; color: white; padding: 0.5rem; border-radius: 0.375rem; width: 250px; margin-right: 0.5rem; }
          pre { background: #090D16; border: 1px solid #1F2937; padding: 1rem; border-radius: 0.375rem; color: #34D399; font-family: monospace; overflow-x: auto; max-height: 250px; margin-top: 1rem; display: none; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>TAI LABORATORIES | <span>AI Engine Interactive Console</span></h1>
          <p style="color: #9CA3AF;">Berlin HQ Subsystem Routing Interface - Local Autonomous Mode</p>
          
          <!-- GET / -->
          <div class="endpoint-block">
            <span class="badge get">GET</span> <span class="path">/api/</span>
            <div class="desc">Obtener estado general del motor de Inteligencia Artificial molecular.</div>
            <button onclick="runFetch('/api/', 'res-root')">Execute Request</button>
            <pre id="res-root"></pre>
          </div>

          <!-- GET /sequences -->
          <div class="endpoint-block">
            <span class="badge get">GET</span> <span class="path">/api/sequences/</span>
            <div class="desc">Listar el dataset completo de las 50 secuencias moleculares analizadas.</div>
            <button onclick="runFetch('/api/sequences', 'res-seq')">Execute Request</button>
            <pre id="res-seq"></pre>
          </div>

          <!-- POST /sequences -->
          <div class="endpoint-block">
            <span class="badge post">POST</span> <span class="path">/api/sequences/</span>
            <div class="desc">Inyectar una nueva simulacion molecular interactiva en la memoria RAM del cl&uacute;ster.</div>
            <input type="text" id="seq-name" class="form-input" placeholder="e.g., SARS-CoV-3_Twin">
            <button onclick="runPost()" style="background:#10B981;">Submit Simulation</button>
            <pre id="res-post"></pre>
          </div>
        </div>

        <script>
          function runFetch(url, elementId) {
            const pre = document.getElementById(elementId);
            fetch(url)
              .then(res => res.json())
              .then(data => {
                pre.innerText = JSON.stringify(data, null, 2);
                pre.style.display = 'block';
              })
              .catch(err => {
                pre.innerText = 'Error executing request: ' + err;
                pre.style.display = 'block';
              });
          }

          function runPost() {
            const nameInput = document.getElementById('seq-name');
            const pre = document.getElementById('res-post');
            if(!nameInput.value) { alert('Please enter a sequence name'); return; }
            
            fetch('/api/sequences', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ name: nameInput.value })
            })
            .then(res => res.json())
            .then(data => {
              pre.innerText = JSON.stringify(data, null, 2);
              pre.style.display = 'block';
              nameInput.value = '';
            })
            .catch(err => {
              pre.innerText = 'Error submitting sequence: ' + err;
              pre.style.display = 'block';
            });
          }
        </script>
      </body>
      </html>
    `);
  }

  // 3. ENDPOINT DINÁMICO: LISTAR SECUENCIAS (GET /api/sequences)
  if ((req.url === '/sequences' || req.url === '/api/sequences' || req.url === '/api/sequences/') && req.method === 'GET') {
    return res.end(JSON.stringify(molecularSequences, null, 2));
  }

  // 4. ENDPOINT DINÁMICO: CREAR SECUENCIA (POST /api/sequences)
  if ((req.url === '/sequences' || req.url === '/api/sequences' || req.url === '/api/sequences/') && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        if (!data.name) throw new Error("Missing parameter 'name'");
        
        const newSeq = {
          id: `TAI-${String(molecularSequences.length + 1).padStart(3, '0')}`,
          name: data.name,
          status: "Simulated",
          match_rate: (Math.random() * (100 - 90) + 90).toFixed(2) + "%"
        };
        molecularSequences.push(newSeq);
        res.statusCode = 201;
        return res.end(JSON.stringify({ message: "Sequence injected successfully", sequence: newSeq }));
      } catch (err) {
        res.statusCode = 400;
        return res.end(JSON.stringify({ error: "Bad Request", message: err.message }));
      }
    });
    return;
  }
  
  // 5. ENRUTADOR RAÍZ PRINCIPAL
  if (req.url === '/' || req.url === '/api' || req.url === '/api/') {
    return res.end(JSON.stringify({
      status: 'ONLINE',
      service: 'corp-api',
      subsystem: 'AI Molecular Synthesis Engine',
      location: 'Berlin HQ Cluster',
      host: os.hostname(),
      time_utc: new Date().toISOString(),
      metrics: {
        processed_sequences: molecularSequences.length,
        accuracy_rate: '99.84%',
        gans_status: 'Stable'
      },
      endpoints: ['/health', '/api/docs', '/api/sequences']
    }));
  }

  res.statusCode = 404;
  res.end(JSON.stringify({ error: 'Endpoint not found', requested_url: req.url }));
});

server.listen(3000, () => {
  console.log('TAI Labs Advanced API Engine active on port 3000');
});
EOF

echo "==> Reiniciando el servicio para aplicar la consola de ejecucion local..."
systemctl restart corp-api

echo "==> Verificando localmente..."
sleep 2
curl -s http://localhost:3000
