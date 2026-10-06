param(
    [string]\$DomainName,
    [string]\$AdminPassword
)

\$ErrorActionPreference = "Stop"

Start-Transcript -Path "C:\prov.log" -Append

try {
    Write-Host "==> Configurando contraseña de Administrator..."
    net user Administrator \$AdminPassword

    Write-Host "==> Habilitando ICMP..."
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" | Out-Null

    Write-Host "==> Instalando AD DS y DNS..."
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools

    Write-Host "==> Preparando directorio C:\Scripts..."
    New-Item -Path "C:\Scripts" -ItemType Directory -Force | Out-Null

    # --- INICIO DEL SCRIPT POST-REBOOT (Aquí usamos marcadores de texto para no romper variables) ---
    \(post = @'\)ErrorActionPreference = "Stop"

Start-Transcript -Path "C:\prov.log" -Append

\$taskName = "PostDcSetup"

try {
    Write-Host "==> PostDcSetup iniciado."
    Write-Host "==> Esperando a que Active Directory esté disponible..."

    ready = false
    for (\$i = 0; i -lt 180; i++) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop

            \$domain = Get-ADDomain -ErrorAction Stop
            \(forest = Get-ADForest -ErrorAction Stop\)admin  = Get-ADUser Administrator -ErrorAction Stop

            \(ntds = Get-Service NTDS -ErrorAction Stop\)dns  = Get-Service DNS -ErrorAction Stop

            if (ntds.Status -eq "Running" -and dns.Status -eq "Running") {
                ready = true
                break
            }
        }
        catch {
            Write-Host "    AD todavía no está listo..."
        }
        Start-Sleep -Seconds 10
    }

    if (-not \$ready) {
        throw "Active Directory no estuvo disponible dentro del tiempo esperado."
    }

    Write-Host "==> Active Directory disponible."
    Write-Host "    Domain: (domain.DNSRoot)"
    Write-Host "    Forest: (forest.RootDomain)"

    Write-Host "==> Configurando DNS forwarder..."
    Add-DnsServerForwarder -IPAddress "169.254.169.253" -ErrorAction SilentlyContinue

    Write-Host "==> Creando estructura de OUs..."
    \$ouRoot = "DC=(domain.DNSRoot.Replace('.', ',DC='))"

    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=Corp)" -SearchBase \$ouRoot -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Corp" -Path \$ouRoot
    }
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=Servers)" -SearchBase \$ouRoot -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Servers" -Path \$ouRoot
    }
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=Workstations)" -SearchBase \$ouRoot -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Workstations" -Path \$ouRoot
    }
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=Service)" -SearchBase \$ouRoot -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Service" -Path \$ouRoot
    }

    Write-Host "==> Creando cuenta DomainJoin..."
    \$domainJoinPassword = ConvertTo-SecureString "__ADMINPASS__" -AsPlainText -Force

    \$domainJoin = Get-ADUser -Identity "DomainJoin" -ErrorAction SilentlyContinue
    if (-not \$domainJoin) {
        New-ADUser -Name "DomainJoin" -SamAccountName "DomainJoin" -AccountPassword domainJoinPassword -Enabled true
    }

    Add-ADGroupMember -Identity "Domain Admins" -Members "DomainJoin" -ErrorAction SilentlyContinue

    Write-Host "==> Creando usuarios base..."
    \$baseUsers = @(
        @{ Sam = "jgarcia"; Name = "Juan Garcia" },
        @{ Sam = "mlopez"; Name = "Maria Lopez" },
        @{ Sam = "afernandez"; Name = "Ana Fernandez" },
        @{ Sam = "ops-svc"; Name = "Operations Service" }
    )

    foreach (u in baseUsers) {
        if (-not (Get-ADUser -Identity \(u.Sam -ErrorAction SilentlyContinue)) {\)password = ConvertTo-SecureString "__ADMINPASS__" -AsPlainText -Force
            New-ADUser -Name \$u.Name -SamAccountName u.Sam -AccountPassword password -Enabled true -Path "OU=Corp,ouRoot"
        }
    }

    Write-Host "==> Creando grupo IT-Admins..."
    if (-not (Get-ADGroup -Identity "IT-Admins" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name "IT-Admins" -GroupScope Global -GroupCategory Security -Path "OU=Corp,\$ouRoot"
    }

    Add-ADGroupMember -Identity "IT-Admins" -Members "jgarcia" -ErrorAction SilentlyContinue

    Write-Host "==> Descargando vulnerable-AD..."
    \$vulnPath = "C:\Scripts\vulnad.ps1"
    \$vulnScriptUrl = "https://raw.githubusercontent.com/safebuffer/vulnerable-AD/refs/heads/master/vulnad.ps1"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri vulnScriptUrl -OutFile vulnPath -UseBasicParsing

    if (-not (Test-Path \$vulnPath)) {
        throw "No se pudo descargar vulnad.ps1."
    }

    Write-Host "==> Calculando SHA256 de vulnad.ps1..."
    \$hash = Get-FileHash -Path \(vulnPath -Algorithm SHA256\)hash.Hash | Set-Content -Path "C:\Scripts\vulnad.sha256" -Encoding ASCII
    Write-Host "    SHA256: (hash.Hash)"

    Write-Host "==> Cargando e invocando vulnerable-AD..."
    Import-Module \$vulnPath -Force

    if (-not (Get-Command Invoke-VulnAD -ErrorAction SilentlyContinue)) {
        throw "Invoke-VulnAD no está disponible después de cargar vulnad.ps1."
    }

    Write-Host "    Invoke-VulnAD disponible. Ejecutando..."
    Invoke-VulnAD -UsersLimit 150 -DomainName \$domain.DNSRoot

    Write-Host "==> vulnerable-AD finalizado."
    Write-Host "==> Verificando AD..."

    \$verifyDomain = Get-ADDomain -ErrorAction Stop
    \(verifyForest = Get-ADForest -ErrorAction Stop\)verifyAdmin  = Get-ADUser Administrator -ErrorAction Stop

    if (-not \$verifyDomain) { throw "No se pudo verificar el dominio." }
    if (-not \$verifyForest) { throw "No se pudo verificar el forest." }
    if (-not \$verifyAdmin)  { throw "No se pudo verificar Administrator." }

    Write-Host "    Domain OK: (verifyDomain.DNSRoot)"
    Write-Host "    Forest OK: (verifyForest.RootDomain)"
    Write-Host "    Administrator OK."

    Write-Host "==> Provisionamiento DC1 completado."
    "OK" | Set-Content -Path "C:\prov.done" -Encoding ASCII
    Write-Host "==> Marcador C:\prov.done creado."

    Write-Host "==> Eliminando tarea PostDcSetup..."
    Unregister-ScheduledTask -TaskName taskName -Confirm:false -ErrorAction SilentlyContinue
}
catch {
    Write-Host "!!! ERROR EN POSTDCSETUP !!!"
    Write-Host \$_.Exception.Message
    \$_ | Out-File -FilePath "C:\prov.error" -Append
    Write-Host "La tarea se mantiene registrada para diagnóstico/reintento."
    throw
}
finally {
    Stop-Transcript
}
'@
    # --- FIN DEL SCRIPT POST-REBOOT ---

    # Reemplazo de marcadores seguro controlado por el script raíz
    \$post = \(post.Replace("__ADMINPASS__", \)AdminPassword)

    Write-Host "==> Escribiendo script PostDcSetup..."
    \$post | Set-Content -Path "C:\Scripts\PostDcSetup.ps1" -Encoding ASCII

    Write-Host "==> Registrando tarea PostDcSetup..."
    \$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\PostDcSetup.ps1"'
    \(trigger = New-ScheduledTaskTrigger -AtStartup\)principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    \$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2)

    Register-ScheduledTask -TaskName "PostDcSetup" -Action action -Trigger trigger -Principal principal -Settings settings -Force

    Write-Host "==> Promoviendo servidor a nuevo forest..."
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName "CORP" `
        -InstallDns `
        -SafeModeAdministratorPassword (ConvertTo-SecureString \$AdminPassword -AsPlainText -Force) `
        -Force `
        -NoRebootOnCompletion:\$false
}
catch {
    Write-Host "!!! ERROR CRÍTICO EN LA CONFIGURACIÓN INICIAL DE DC1 !!!"
    Write-Host \$_.Exception.Message
    \$_ | Out-File -FilePath "C:\prov.initial_error.log" -Append
    throw
}
finally {
    Stop-Transcript
}
