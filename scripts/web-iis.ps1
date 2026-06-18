param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# Frontal IIS (Windows Server 2022) con pagina de ejemplo. NO se une al dominio.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
  Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
  Install-WindowsFeature -Name Web-Server,Web-Asp-Net45 -IncludeManagementTools
  $html = @"
<!doctype html><html><head><meta charset='utf-8'><title>IIS Corp</title>
<style>body{font-family:Segoe UI;background:#3a1b3a;color:#ffeaff;margin:2rem}</style></head>
<body><h1>IIS &mdash; $env:COMPUTERNAME</h1>
<p>Windows Server 2022 &middot; frontal web corporativo</p>
<p>Fecha: $(Get-Date)</p></body></html>
"@
  Set-Content -Path C:\inetpub\wwwroot\index.html -Value $html -Encoding UTF8
  Remove-Item C:\inetpub\wwwroot\iisstart.htm -ErrorAction SilentlyContinue
  "iis ready" | Out-File C:\prov.done
} catch { $_ | Out-File C:\prov.error }
Stop-Transcript
