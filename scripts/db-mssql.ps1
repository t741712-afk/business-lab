param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# MS SQL Server Express (Windows). Descarga e instala SQL Express + crea BD demo.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  $url = "https://go.microsoft.com/fwlink/p/?linkid=2216019"   # SQL Server 2022 Express bootstrap
  $exe = "C:\sqlexpress.exe"
  Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
  # Instalacion desatendida con instancia por defecto y modo mixto
  Start-Process $exe -ArgumentList "/ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SECURITYMODE=SQL /SAPWD=$AdminPassword /TCPENABLED=1" -Wait
  Set-NetFirewallRule -DisplayName "SQL*" -Enabled True -ErrorAction SilentlyContinue
  "mssql installed $(Get-Date)" | Out-File C:\prov.done
} catch { $_ | Out-File C:\prov.error }
Stop-Transcript
