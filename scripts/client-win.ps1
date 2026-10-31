param(
  [string]$DomainName = "corp.local",
  [string]$DcIp = "10.0.3.10",
  [string]$AdminPassword = "BusinessLab#2026",
  [string]$NewName = "WIN-CLIENT"
)
# Workstation Windows unida al dominio (Win Server 2022 como estacion de trabajo
# de laboratorio; Win10/11 requeriria Marketplace, bloqueado en PX).
Start-Transcript -Path C:\prov.log -Append
net user Administrator $AdminPassword
Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
$if = Get-NetAdapter | Where-Object Status -eq Up | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ServerAddresses $DcIp

# Herramientas de cliente
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
New-Item -Path C:\Tools -ItemType Directory -Force | Out-Null
try { Invoke-WebRequest "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.83-installer.msi" -OutFile C:\Tools\putty.msi -UseBasicParsing
      Start-Process msiexec.exe -ArgumentList "/i C:\Tools\putty.msi /qn /norestart" -Wait } catch {}

# VULNERABILIDAD (escalada de privilegios): tarea programada como SYSTEM que ejecuta
# un script situado en una carpeta que los usuarios pueden modificar
New-Item -Path C:\TAI\Maintenance -ItemType Directory -Force | Out-Null
@'
# TAI workstation maintenance: registra la ejecucion periodica de mantenimiento
$log = "C:\TAI\Maintenance\maintenance.log"
Add-Content -Path $log -Value ("{0} maintenance run" -f (Get-Date))
'@ | Set-Content -Path C:\TAI\Maintenance\maintenance.ps1 -Encoding ASCII
icacls C:\TAI\Maintenance /grant "BUILTIN\Users:(OI)(CI)M" | Out-Null
$maintAction  = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\TAI\Maintenance\maintenance.ps1"
$maintTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName "TAI-Maintenance" -Action $maintAction -Trigger $maintTrigger -User "SYSTEM" -RunLevel Highest -Force | Out-Null

"client ready $(Get-Date)" | Out-File C:\prov.done

# Esperar dominio y unir (reinicia)
$sec = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("$DomainName\DomainJoin",$sec)
for($i=0;$i -lt 50;$i++){
  try { Resolve-DnsName $DomainName -Server $DcIp -ErrorAction Stop; break } catch { Start-Sleep 30 }
}
Add-Computer -DomainName $DomainName -Credential $cred -NewName $NewName -Restart -Force
Stop-Transcript
