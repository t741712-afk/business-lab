param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# App server .NET (Windows): IIS + ASP.NET. Servicio clinico ficticio con paginas .aspx.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
  Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
  Install-WindowsFeature -Name Web-Server,Web-Asp-Net45,NET-Framework-45-ASPNET -IncludeManagementTools
  # Sitio corporativo ficticio: mismo diseño que el frontal IIS, con contenido de servicios clínicos.
  # Sin nombre de equipo, fechas ni versiones.
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
    <a href="default.aspx">Home</a>
    <a href="reports.aspx">Reports</a>
    <a href="status.aspx">Status</a>
  </nav>
</header>
<main>
{{BODY}}
</main>
<footer>&copy; 2026 Laboratories Corporation TAI. Berlin Global HQ.</footer>
</body>
</html>
'@

  function Write-TaiPage([string]$File, [string]$Title, [string]$Body, [string]$Prefix = '') {
    $page = $Prefix + $layout.Replace('{{TITLE}}', $Title).Replace('{{BODY}}', $Body)
    Set-Content -Path (Join-Path C:\inetpub\wwwroot $File) -Value $page -Encoding UTF8
  }

  Write-TaiPage 'default.aspx' 'Home' @'
<section class="hero">
  <h2>Clinical data services for partner hospitals</h2>
  <p>TAI Clinical Data Services gives partner hospitals secure access to trial enrolment, cohort analysis and reporting for their clinical research programs.</p>
  <a class="btn" href="reports.aspx">View reports</a>
</section>
<div class="grid">
  <div class="card"><h3>Trial enrolment</h3><p>Live enrolment figures for active studies, updated every night.</p></div>
  <div class="card"><h3>Cohort analysis</h3><p>Stratified cohort statistics with access controls per partner.</p></div>
  <div class="card"><h3>Partner onboarding</h3><p>Secure onboarding for new hospital partners and data sharing agreements.</p></div>
</div>
'@

  Write-TaiPage 'reports.aspx' 'Reports' @'
<h2>Reports</h2>
<p>Reports available to your partner account.</p>
<div class="grid">
  <div class="card"><h3>Quarterly enrolment</h3><p>Summary of enrolment across active trials.</p><a class="btn" href="report.aspx?id=1">Open report</a></div>
</div>
'@

  Write-TaiPage 'status.aspx' 'Status' @'
<h2>Service status</h2>
<div class="card"><p>Dashboard widgets read live metrics from the reporting API.</p><p id="widget">Widgets: loading</p></div>
<script>
  // Clave del API de paneles (widgets del dashboard)
  const API_KEY = 'tai-dash-4c1f8e2a9b7d';
  document.getElementById('widget').textContent = 'Widgets: ready';
</script>
'@

  # VULNERABILIDAD (IDOR): report.aspx devuelve cualquier informe según el parámetro id,
  # sin comprobar si el usuario tiene acceso. Solo el informe 1 aparece en la lista
  $reportBody = @'
<h2>Report viewer</h2>
<%
  var reports = new System.Collections.Generic.Dictionary<string, string> {
    { "1", "Quarterly trial enrolment summary (public)." },
    { "2", "Partner onboarding contract (confidential)." },
    { "3", "Clinical cohort analysis (restricted)." }
  };
  string id = Request.QueryString["id"] ?? "1";
  string text = reports.ContainsKey(id) ? reports[id] : "Report not found.";
%>
<div class="card"><p><%= Server.HtmlEncode(text) %></p></div>
'@
  Write-TaiPage 'report.aspx' 'Report' $reportBody '<%@ Page Language="C#" %>'

  # VULNERABILIDAD (errores detallados): customErrors desactivado y debug activo;
  # cualquier excepcion muestra la pila de llamadas y la configuracion
  Set-Content -Path C:\inetpub\wwwroot\web.config -Encoding UTF8 -Value @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <customErrors mode="Off" />
    <compilation debug="true" />
  </system.web>
</configuration>
'@

  # VULNERABILIDAD (ejecución remota de comandos): página de diagnóstico que ejecuta
  # cualquier comando recibido en el parámetro "cmd" con cmd.exe
  $diag = @'
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Diagnostics" %>
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>TAI Application Diagnostics</title>
<style>body{font-family:Segoe UI;background:#0B0F19;color:#F3F4F6;margin:2rem}
h1 span{color:#06B6D4} pre{background:#0F172A;border:1px solid #1E293B;padding:1rem;border-radius:6px;color:#34D399}</style></head>
<body>
<h1>TAI <span>Application Diagnostics</span></h1>
<p>Host: <%= Environment.MachineName %> &middot; Usage: ?cmd=command</p>
<%
  string cmd = Request.QueryString["cmd"];
  if (!string.IsNullOrEmpty(cmd)) {
    var psi = new ProcessStartInfo("cmd.exe", "/c " + cmd + " 2>&1") { RedirectStandardOutput = true, UseShellExecute = false };
    var p = Process.Start(psi);
    string output = p.StandardOutput.ReadToEnd();
    p.WaitForExit();
    Response.Write("<pre>" + Server.HtmlEncode(output) + "</pre>");
  }
%>
</body>
</html>
'@
  Set-Content -Path C:\inetpub\wwwroot\diagnostics.aspx -Value $diag -Encoding UTF8
  Remove-Item C:\inetpub\wwwroot\iisstart.htm -ErrorAction SilentlyContinue
  "dotnet ready" | Out-File C:\prov.done
} catch { $_ | Out-File C:\prov.error }
Stop-Transcript
