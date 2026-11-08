# Instala y activa el agente de Trend Micro Deep Security en Windows.
# Uso: trend-agent.ps1 -TenantId <id> -Token <token>
# Es idempotente: si el agente ya esta instalado, solo se vuelve a activar.
# Si existe la tarea programada TrendAgentInstall (la registra el UserData para ejecutarse al arrancar),
# se elimina cuando la activacion termina bien.
param(
  [Parameter(Mandatory)][string]$TenantId,
  [Parameter(Mandatory)][string]$Token
)
$ErrorActionPreference = "Stop"

# URL del zip del agente Deep Security 20.0.3 (con el .msi)
$PackageUrl = "https://files.trendmicro.com/products/deepsecurity/en/20.0/Agent-Windows-20.0.3-31610.x86_64.zip"
$DsaControl = "C:\Program Files\Trend Micro\Deep Security Agent\dsa_control.cmd"

Start-Transcript -Path C:\prov.log -Append
try {
  if (-not (Test-Path $DsaControl)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zip = "$env:TEMP\trend-agent.zip"
    $extract = "$env:TEMP\trend-agent"

    Invoke-WebRequest -Uri $PackageUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $extract -Force

    $msi = Get-ChildItem -Path $extract -Filter *.msi -Recurse | Select-Object -First 1
    if (-not $msi) { throw "No se encontro ningun .msi en el paquete" }
    Start-Process msiexec.exe -ArgumentList "/i `"$($msi.FullName)`" /qn" -Wait
  }

  # Activacion con el tenant y el token
  Start-Sleep -Seconds 20
  & $DsaControl -a dsm://agents.workload.de-1.cloudone.trendmicro.com:443/ "tenantID:$TenantId" "token:$Token"

  Unregister-ScheduledTask -TaskName TrendAgentInstall -Confirm:$false -ErrorAction SilentlyContinue
  "trend agent activado $(Get-Date)" | Out-File C:\prov.trend
} catch {
  $_ | Out-File C:\prov.trend.error
} finally {
  Stop-Transcript
}
