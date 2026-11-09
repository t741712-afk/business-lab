const http = require('http');
const os = require('os');
const fs = require('fs');
const path = require('path');

// La consola se lee una vez al arrancar. Si falta el fichero, el servidor sigue funcionando
let docsPage;
try {
  docsPage = fs.readFileSync(path.join(__dirname, 'docs.html'), 'utf8');
} catch (err) {
  docsPage = '<!doctype html><title>API console</title><p>docs.html no encontrado.</p>';
}

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
  
  // 2. CONSOLA DE INTERACCION (Endpoint: /api/docs). La pagina vive en docs.html, junto a este fichero
  if (req.url === '/docs' || req.url === '/api/docs' || req.url === '/api/docs/') {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.end(docsPage);
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
