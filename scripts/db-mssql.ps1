param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# MS SQL Server 2022 Express (Windows). Instancia POR DEFECTO -> escucha en 1433
# (una instancia nombrada SQLEXPRESS usaria un puerto dinamico, no el 1433).
# Endurecido: descarga del bootstrapper con reintentos -> descarga media -> extrae
# -> instala desatendido -> abre firewall 1433 -> verifica que escucha.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
  Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $ssei  = "C:\SQLEXPR-SSEI.exe"
  $media = "C:\sqlmedia"
  New-Item -ItemType Directory -Path $media -Force | Out-Null

  # 1) Bootstrapper de SQL Server 2022 Express (con reintentos)
  for ($i=0; $i -lt 5; $i++) {
    try { Invoke-WebRequest "https://go.microsoft.com/fwlink/p/?linkid=2216019" -OutFile $ssei -UseBasicParsing; break }
    catch { Start-Sleep 20 }
  }

  # 2) Descargar el paquete completo (Core) a la carpeta media
  Start-Process $ssei -ArgumentList "/ACTION=Download /MEDIAPATH=$media /MEDIATYPE=Core /QUIET /HIDEPROGRESSBAR" -Wait

  # 3) Extraer el instalador (SQLEXPR*.exe -> setup.exe)
  $pkg = Get-ChildItem $media -Filter "SQLEXPR*.exe" | Select-Object -First 1
  Start-Process $pkg.FullName -ArgumentList "/Q /X:$media\extract" -Wait

  # 4) Instalar instancia POR DEFECTO (MSSQLSERVER) en modo mixto, TCP habilitado
  $setupArgs = "/ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE " +
               "/INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=`"$AdminPassword`" " +
               "/TCPENABLED=1 /SQLSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`" " +
               "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`""
  Start-Process "$media\extract\setup.exe" -ArgumentList $setupArgs -Wait

  # 5) Firewall para 1433 + reinicio del servicio para aplicar TCP
  New-NetFirewallRule -DisplayName "SQL 1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue
  Restart-Service MSSQLSERVER -Force -ErrorAction SilentlyContinue

  # 6) Verificar que escucha en 1433
  $ok = $false
  for ($i=0; $i -lt 24; $i++) {
    if (Test-NetConnection 127.0.0.1 -Port 1433 -InformationLevel Quiet) { $ok = $true; break }
    Start-Sleep 10
  }
  if ($ok) { "mssql ready - LISTEN 1433 OK $(Get-Date)" | Out-File C:\prov.done }
  else     { "WARN: SQL instalado pero no escucha en 1433 - revisar Configuration Manager" | Out-File C:\prov.done }
} catch {
  $_.Exception.Message | Out-File C:\prov.error
}
Stop-Transcript
