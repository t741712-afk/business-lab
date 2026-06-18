param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# App server .NET (Windows): IIS + ASP.NET + pagina .aspx de ejemplo.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
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
  Remove-Item C:\inetpub\wwwroot\iisstart.htm -ErrorAction SilentlyContinue
  "dotnet ready" | Out-File C:\prov.done
} catch { $_ | Out-File C:\prov.error }
Stop-Transcript
