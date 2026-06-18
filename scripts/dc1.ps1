param(
  [string]$DomainName = "corp.local",
  [string]$AdminPassword = "BusinessLab#2026"
)
# DC1 - Promociona a bosque AD nuevo + DNS. Tras el reboot, una tarea programada
# crea OUs, usuarios de ejemplo y el usuario 'DomainJoin' (para que el resto se una).
Start-Transcript -Path C:\prov.log -Append
$sec = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
net user Administrator $AdminPassword
Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor

Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools

# Script post-reboot (crea estructura del dominio una sola vez)
New-Item -Path C:\Scripts -ItemType Directory -Force | Out-Null
$post = @'
Start-Sleep -Seconds 60
$pass = ConvertTo-SecureString "__ADMINPASS__" -AsPlainText -Force
# Reenvio DNS a AWS para que la red resuelva internet
Add-DnsServerForwarder -IPAddress 169.254.169.253 -ErrorAction SilentlyContinue
# OUs
foreach($ou in "Corp","Servers","Workstations","Service"){
  if(-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)){
    New-ADOrganizationalUnit -Name $ou -ProtectedFromAccidentalDeletion $false
  }
}
# Usuario para unir maquinas al dominio
if(-not (Get-ADUser -Filter "SamAccountName -eq 'DomainJoin'" -ErrorAction SilentlyContinue)){
  New-ADUser -Name DomainJoin -SamAccountName DomainJoin -AccountPassword $pass -Enabled $true -PasswordNeverExpires $true
  Add-ADGroupMember -Identity "Domain Admins" -Members DomainJoin
}
# Usuarios de ejemplo
foreach($u in "jgarcia","mlopez","afernandez","ops-svc"){
  if(-not (Get-ADUser -Filter "SamAccountName -eq '$u'" -ErrorAction SilentlyContinue)){
    New-ADUser -Name $u -SamAccountName $u -AccountPassword $pass -Enabled $true -PasswordNeverExpires $true -Path "OU=Corp,$((Get-ADDomain).DistinguishedName)"
  }
}
# Grupo de TI
if(-not (Get-ADGroup -Filter "Name -eq 'IT-Admins'" -ErrorAction SilentlyContinue)){
  New-ADGroup -Name IT-Admins -GroupScope Global -Path "OU=Corp,$((Get-ADDomain).DistinguishedName)"
  Add-ADGroupMember -Identity IT-Admins -Members jgarcia
}
"domain populated $(Get-Date)" | Out-File C:\prov.done
Unregister-ScheduledTask -TaskName PostDcSetup -Confirm:$false
'@
$post = $post.Replace("__ADMINPASS__",$AdminPassword)
Set-Content -Path C:\Scripts\PostDcSetup.ps1 -Value $post -Encoding ASCII -Force
$action  = New-ScheduledTaskAction -Execute PowerShell.exe -Argument "-ExecutionPolicy Bypass -File C:\Scripts\PostDcSetup.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName PostDcSetup -Action $action -Trigger $trigger -RunLevel Highest -User SYSTEM -Force

# Promocion (reinicia la maquina al terminar)
Install-ADDSForest -DomainName $DomainName -SafeModeAdministratorPassword $sec -InstallDNS -Force
Stop-Transcript
