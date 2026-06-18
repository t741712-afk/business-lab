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
$if = Get-NetAdapter | Where-Object Status -eq Up | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ServerAddresses $DcIp

# Herramientas de cliente
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
New-Item -Path C:\Tools -ItemType Directory -Force | Out-Null
try { Invoke-WebRequest "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.83-installer.msi" -OutFile C:\Tools\putty.msi -UseBasicParsing
      Start-Process msiexec.exe -ArgumentList "/i C:\Tools\putty.msi /qn /norestart" -Wait } catch {}

"client ready $(Get-Date)" | Out-File C:\prov.done

# Esperar dominio y unir (reinicia)
$sec = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("$DomainName\DomainJoin",$sec)
for($i=0;$i -lt 50;$i++){
  try { Resolve-DnsName $DomainName -Server $DcIp -ErrorAction Stop; break } catch { Start-Sleep 30 }
}
Add-Computer -DomainName $DomainName -Credential $cred -NewName $NewName -Restart -Force
Stop-Transcript
