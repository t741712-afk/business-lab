param(
  [string]$DomainName = "corp.local",
  [string]$AdminPassword = "BusinessLab#2026"
)

$ErrorActionPreference = "Stop"

# Iniciar log raíz
Start-Transcript -Path "C:\prov.log" -Append

try {
    Write-Host "==> Configurando contrasena de Administrator..."
    net user Administrator $AdminPassword

    Write-Host "==> Habilitando ICMP de forma segura (Ping)..."
    Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In

    Write-Host "==> Instalando AD DS y DNS..."
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools

    Write-Host "==> Preparando directorio C:\Scripts..."
    New-Item -Path "C:\Scripts" -ItemType Directory -Force | Out-Null

    # --- INICIO DEL SCRIPT POST-REBOOT (Here-String Literal Puro) ---
    $post = @'
$ErrorActionPreference = "Stop"
Start-Transcript -Path "C:\prov.log" -Append

try {
    Write-Host "==> PostDcSetup iniciado. Esperando disponibilidad de AD..."
    
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            $domain = Get-ADDomain -ErrorAction Stop
            $ntds = Get-Service NTDS -ErrorAction Stop
            $dns = Get-Service DNS -ErrorAction Stop

            if ($ntds.Status -eq "Running" -and $dns.Status -eq "Running") {
                $ready = $true
                break
            }
        }
        catch {
            Write-Host "    AD aun no esta listo, esperando..."
        }
        Start-Sleep -Seconds 10
    }

    if (-not $ready) { throw "Active Directory no levanto a tiempo." }

    Write-Host "==> AD Listo. Configurando DNS forwarder de AWS..."
    Add-DnsServerForwarder -IPAddress "169.254.169.253" -ErrorAction SilentlyContinue

    Write-Host "==> Creando OUs..."
    $ouRoot = "DC=$("__DOMAINNAME__".Replace('.', ',DC='))"

    foreach($ou in "Corp","Servers","Workstations","Service"){
        if(-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)){
            New-ADOrganizationalUnit -Name $ou -Path $ouRoot -ProtectedFromAccidentalDeletion $false
        }
    }

    Write-Host "==> Creando cuenta DomainJoin..."
    $pass = ConvertTo-SecureString "__ADMINPASS__" -AsPlainText -Force
    if(-not (Get-ADUser -Filter "SamAccountName -eq 'DomainJoin'" -ErrorAction SilentlyContinue)){
        New-ADUser -Name "DomainJoin" -SamAccountName "DomainJoin" -AccountPassword $pass -Enabled $true -PasswordNeverExpires $true
        Add-ADGroupMember -Identity "Domain Admins" -Members "DomainJoin"
    }

    Write-Host "==> Creando usuarios base..."
    $baseUsers = @(
        @{ Sam = "jgarcia"; Name = "Juan Garcia" },
        @{ Sam = "mlopez"; Name = "Maria Lopez" },
        @{ Sam = "afernandez"; Name = "Ana Fernandez" },
        @{ Sam = "ops-svc"; Name = "Operations Service" }
    )
    foreach ($u in $baseUsers) {
        if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
            New-ADUser -Name $u.Name -SamAccountName $u.Sam -AccountPassword $pass -Enabled $true -PasswordNeverExpires $true -Path "OU=Corp,$ouRoot"
        }
    }

    Write-Host "==> Creando grupo IT-Admins..."
    if (-not (Get-ADGroup -Filter "Name -eq 'IT-Admins'" -ErrorAction SilentlyContinue)){
        New-ADGroup -Name "IT-Admins" -GroupScope Global -Path "OU=Corp,$ouRoot"
        Add-ADGroupMember -Identity "IT-Admins" -Members "jgarcia"
    }

    Write-Host "==> Descargando e Invocando vulnerable-AD..."
    $vulnPath = "C:\Scripts\vulnad.ps1"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/safebuffer/vulnerable-AD/refs/heads/master/vulnad.ps1" -OutFile $vulnPath -UseBasicParsing
    
    if (Test-Path $vulnPath) {
        # Carga por Dot-Sourcing para asegurar visibilidad de funciones de script plano
        . $vulnPath
        # Usamos el marcador estatico inyectado para evitar problemas de scope
        Invoke-VulnAD -UsersLimit 150 -DomainName "__DOMAINNAME__"
        Write-Host "==> vulnerable-AD ejecutado con exito."
    }

    # VULNERABILIDAD (AS-REP Roasting): preautenticacion Kerberos desactivada para tvasquez
    Write-Host "==> Creando cuenta tvasquez (AS-REP Roasting)..."
    $tvPass = ConvertTo-SecureString "Spring2026!" -AsPlainText -Force
    if(-not (Get-ADUser -Filter "SamAccountName -eq 'tvasquez'" -ErrorAction SilentlyContinue)){
        New-ADUser -Name "Teresa Vasquez" -SamAccountName "tvasquez" -AccountPassword $tvPass -Enabled $true -PasswordNeverExpires $true -Path "OU=Corp,$ouRoot"
    }
    Set-ADAccountControl -Identity "tvasquez" -DoesNotRequirePreAuth $true

    # VULNERABILIDAD (Kerberoasting): cuenta de servicio con SPN y contrasena debil
    Write-Host "==> Creando cuenta svc-sql (Kerberoasting)..."
    $svcPass = ConvertTo-SecureString "Summer2026!" -AsPlainText -Force
    if(-not (Get-ADUser -Filter "SamAccountName -eq 'svc-sql'" -ErrorAction SilentlyContinue)){
        New-ADUser -Name "SQL Service" -SamAccountName "svc-sql" -AccountPassword $svcPass -Enabled $true -PasswordNeverExpires $true -Path "OU=Service,$ouRoot"
        Set-ADUser -Identity "svc-sql" -ServicePrincipalNames @{Add="MSSQLSvc/mssql.corp.local:1433"}
    }

    # VULNERABILIDAD (ACL excesiva): IT-Admins puede modificar la cuenta ops-svc (GenericWrite)
    Write-Host "==> Aplicando ACL debil: IT-Admins -> GenericWrite sobre ops-svc..."
    $grp = Get-ADGroup -Identity "IT-Admins"
    $target = Get-ADUser -Identity "ops-svc"
    $sid = New-Object System.Security.Principal.SecurityIdentifier $grp.SID
    $dn = "AD:" + $target.DistinguishedName
    $acl = Get-Acl -Path $dn
    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid, [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite, [System.Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule)
    Set-Acl -Path $dn -AclObject $acl

    "OK" | Set-Content -Path "C:\prov.done" -Encoding ASCII
    Unregister-ScheduledTask -TaskName "PostDcSetup" -Confirm:$false -ErrorAction SilentlyContinue
}
catch {
    Write-Host "!!! ERROR EN POSTDCSETUP !!!"
    $_.Exception.Message | Out-File -FilePath "C:\prov.error" -Append
    throw
}
finally {
    Stop-Transcript
}
'@
    # --- FIN DEL SCRIPT POST-REBOOT ---

    # Reemplazos seguros en el bloque de texto (Contraseña y Nombre de Dominio)
    $post = $post.Replace("__ADMINPASS__", $AdminPassword)
    $post = $post.Replace("__DOMAINNAME__", $DomainName)
    
    $post | Set-Content -Path "C:\Scripts\PostDcSetup.ps1" -Encoding ASCII

    Write-Host "==> Registrando Tarea Programada ejecutable como SYSTEM..."
    $action  = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\PostDcSetup.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "PostDcSetup" -Action $action -Trigger $trigger -RunLevel Highest -User "SYSTEM" -Force | Out-Null

    Write-Host "==> Iniciando promocion de bosque AD (La maquina se reiniciara sola)..."
    $sec = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    
    Install-ADDSForest -DomainName $DomainName -SafeModeAdministratorPassword $sec -InstallDNS -Force
}
catch {
    Write-Host "!!! ERROR CRITICO INICIAL !!!"
    $_.Exception.Message | Out-File -FilePath "C:\prov.initial_error.log" -Append
    throw
}
finally {
    Stop-Transcript
}
