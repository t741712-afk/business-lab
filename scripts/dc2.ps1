param(
  [string]$DomainName = "corp.local",
  [string]$DcIp = "10.0.3.10",
  [string]$AdminPassword = "BusinessLab#2026"
)
# DC2 - DC adicional (replica). Apunta su DNS a DC1, espera a que el dominio
# este disponible y se promociona como controlador adicional.
Start-Transcript -Path C:\prov.log -Append
net user Administrator $AdminPassword

# DNS -> DC1
$if = Get-NetAdapter | Where-Object Status -eq Up | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ServerAddresses $DcIp

Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools

# Esperar a que DC1 publique el dominio (hasta ~25 min)
$sec = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("$DomainName\Administrator",$sec)
for($i=0;$i -lt 50;$i++){
  try { Get-ADDomain -Server $DcIp -ErrorAction Stop; break } catch { Start-Sleep 30 }
}
"promoting dc2 $(Get-Date)" | Out-File C:\prov.done
Install-ADDSDomainController -DomainName $DomainName -SafeModeAdministratorPassword $sec -Credential $cred -InstallDns -Force
Stop-Transcript
