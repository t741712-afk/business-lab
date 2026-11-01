param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# Frontal IIS corporativo (ficticio) con portal de documentos. NO se une al dominio.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
  Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
  Install-WindowsFeature -Name Web-Server,Web-Asp-Net45 -IncludeManagementTools
  # Sitio corporativo ficticio: una plantilla común y cuatro páginas. Sin nombre de equipo, fechas ni versiones.
  $layout = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}} | Laboratories Corporation TAI</title>
<style>
:root{--bg:#070B14;--panel:#0F172A;--border:#1E293B;--cyan:#06B6D4;--blue:#2563EB;--text:#F3F4F6;--muted:#94A3B8}
body{margin:0;font-family:'Segoe UI',system-ui,sans-serif;background:var(--bg);color:var(--text);line-height:1.6}
header{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:1rem;padding:1rem 2rem;background:rgba(15,23,42,.85);border-bottom:1px solid var(--border)}
header h1{margin:0;font-size:1.2rem;font-weight:800;letter-spacing:1px}
header h1 span{color:var(--cyan)}
nav a{color:var(--muted);text-decoration:none;margin-left:1.2rem;font-weight:600;font-size:.9rem}
nav a:hover{color:var(--text)}
main{max-width:1000px;margin:3rem auto;padding:0 2rem}
h2{font-size:2rem;margin:0 0 .5rem}
p{color:var(--muted)}
.hero{padding:2rem 0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1.5rem;margin-top:2rem}
.card{background:var(--panel);border:1px solid var(--border);border-radius:8px;padding:1.5rem}
.card h3{margin-top:0;color:var(--cyan)}
.btn{display:inline-block;background:var(--blue);color:#fff;padding:.6rem 1.2rem;border-radius:6px;text-decoration:none;font-weight:600;margin-top:1rem}
footer{border-top:1px solid var(--border);color:var(--muted);text-align:center;padding:2rem;font-size:.85rem;margin-top:4rem}
</style>
</head>
<body>
<header>
  <h1>LABORATORIES CORPORATION <span>TAI</span></h1>
  <nav>
    <a href="index.html">Home</a>
    <a href="research.html">Research</a>
    <a href="careers.html">Careers</a>
    <a href="contact.html">Contact</a>
  </nav>
</header>
<main>
{{BODY}}
</main>
<footer>&copy; 2026 Laboratories Corporation TAI. Berlin Global HQ.</footer>
</body>
</html>
'@

  function Write-TaiPage([string]$File, [string]$Title, [string]$Body) {
    $page = $layout.Replace('{{TITLE}}', $Title).Replace('{{BODY}}', $Body)
    Set-Content -Path (Join-Path C:\inetpub\wwwroot $File) -Value $page -Encoding UTF8
  }

  Write-TaiPage 'index.html' 'Home' @'
<section class="hero">
  <h2>Advancing biomedicine with artificial intelligence</h2>
  <p>Laboratories Corporation TAI develops AI-driven research platforms for genomics, immunotherapy and clinical trials. Headquartered in Berlin, with research teams across Europe.</p>
  <a class="btn" href="research.html">Explore our research</a>
</section>
<div class="grid">
  <div class="card"><h3>Genomic analysis</h3><p>Pipelines that turn raw sequencing data into validated molecular targets.</p></div>
  <div class="card"><h3>Clinical trials</h3><p>Data-driven trial design and patient stratification for Phase I and II studies.</p></div>
  <div class="card"><h3>Platform services</h3><p>Secure computing infrastructure for partner laboratories and research groups.</p></div>
</div>
'@

  Write-TaiPage 'research.html' 'Research' @'
<h2>Research programs</h2>
<p>Our teams work across four programs, from early discovery to clinical validation.</p>
<div class="grid">
  <div class="card"><h3>Immunotherapy</h3><p>Designing targeted immune responses against solid tumours.</p></div>
  <div class="card"><h3>Molecular synthesis</h3><p>Computational design of candidate molecules and synthesis planning.</p></div>
  <div class="card"><h3>Pathogen modelling</h3><p>Simulation of pathogen evolution to support preparedness studies.</p></div>
  <div class="card"><h3>Neuro models</h3><p>Computational models of neural circuits for drug response prediction.</p></div>
</div>
'@

  Write-TaiPage 'careers.html' 'Careers' @'
<h2>Careers at TAI</h2>
<p>We are hiring bioinformaticians, machine learning engineers, clinical data specialists and security engineers for our Berlin headquarters and our European research sites.</p>
<a class="btn" href="contact.html">Contact recruiting</a>
'@

  Write-TaiPage 'contact.html' 'Contact' @'
<h2>Contact</h2>
<div class="card">
  <p><strong>Berlin Global HQ</strong><br>Friedrichstrasse 1, 10117 Berlin, Germany</p>
  <p>General enquiries: info@tai-labs.local<br>Recruiting: careers@tai-labs.local</p>
</div>
'@
  Remove-Item C:\inetpub\wwwroot\iisstart.htm -ErrorAction SilentlyContinue

  # VULNERABILIDAD (subida insegura de ficheros): el portal acepta cualquier extension
  # y guarda el fichero en una ruta servida por IIS, por lo que un .aspx se ejecuta
  New-Item -Path C:\inetpub\wwwroot\upload -ItemType Directory -Force | Out-Null
  $upload = @'
<%@ Page Language="C#" %>
<%@ Import Namespace="System.IO" %>
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>TAI Document Portal</title>
<style>body{font-family:Segoe UI;background:#0B0F19;color:#F3F4F6;margin:2rem}
h1 span{color:#06B6D4} .box{background:#0F172A;border:1px solid #1E293B;border-radius:8px;padding:1.5rem;max-width:720px}
button{background:#2563EB;color:#fff;border:none;padding:.5rem 1rem;border-radius:6px;font-weight:600}</style></head>
<body>
<h1>TAI <span>Document Portal</span></h1>
<div class="box">
<p>Upload research documents for the Berlin HQ review board.</p>
<form method="post" enctype="multipart/form-data">
  <input type="file" name="document" />
  <button type="submit">Upload</button>
</form>
<%
  if (Request.Files.Count > 0) {
    HttpPostedFile f = Request.Files[0];
    string dir = Server.MapPath("~/upload/files");
    Directory.CreateDirectory(dir);
    string name = Path.GetFileName(f.FileName);
    f.SaveAs(Path.Combine(dir, name));
    Response.Write("<p>Document stored at: /upload/files/" + name + "</p>");
  }
%>
</div>
</body>
</html>
'@
  Set-Content -Path C:\inetpub\wwwroot\upload\upload.aspx -Value $upload -Encoding UTF8
  icacls C:\inetpub\wwwroot\upload /grant "IIS_IUSRS:(OI)(CI)M" | Out-Null
  "iis ready" | Out-File C:\prov.done
} catch { $_ | Out-File C:\prov.error }
Stop-Transcript
