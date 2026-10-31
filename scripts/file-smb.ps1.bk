param(
  [string]$DomainName = "corp.local",
  [string]$DcIp = "10.0.3.10",
  [string]$AdminPassword = "BusinessLab#2026"
)
# File server Windows: une al dominio, crea shares SMB de ejemplo.
Start-Transcript -Path C:\prov.log -Append
net user Administrator $AdminPassword
Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
$if = Get-NetAdapter | Where-Object Status -eq Up | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ServerAddresses $DcIp

# Crear shares (antes del reboot del join)
New-Item -Path C:\Shares\Public  -ItemType Directory -Force | Out-Null
New-Item -Path C:\Shares\Finanzas -ItemType Directory -Force | Out-Null
"Documento publico de la empresa." | Out-File C:\Shares\Public\LEEME.txt
"Datos financieros (confidencial)." | Out-File C:\Shares\Finanzas\Q1.txt
New-SmbShare -Name Public  -Path C:\Shares\Public  -FullAccess Everyone -ErrorAction SilentlyContinue
New-SmbShare -Name Finanzas -Path C:\Shares\Finanzas -FullAccess Everyone -ErrorAction SilentlyContinue

# Tarea post-reboot que confirma el share tras unirse
"fileserver ready $(Get-Date)" | Out-File C:\prov.done

# Esperar al dominio y unir (reinicia)
$sec = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("$DomainName\DomainJoin",$sec)
for($i=0;$i -lt 50;$i++){
  try { Resolve-DnsName $DomainName -Server $DcIp -ErrorAction Stop; break } catch { Start-Sleep 30 }
}
Add-Computer -DomainName $DomainName -Credential $cred -Restart -Force
Stop-Transcript
