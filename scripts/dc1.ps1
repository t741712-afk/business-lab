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
    # Volvemos a la regla de la Versión 1 que SI funcionaba y no rompe la red
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
    $ouRoot = "DC=$($domain.DNSRoot.Replace('.', ',DC='))"

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
        Invoke-VulnAD -UsersLimit 100 -DomainName $domain.DNSRoot
        Write-Host "==> vulnerable-AD ejecutado con exito."
    }

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

    # Reemplazo de contraseña seguro en el bloque de texto
    $post = $post.Replace("__ADMINPASS__", $AdminPassword)
    $post | Set-Content -Path "C:\Scripts\PostDcSetup.ps1" -Encoding ASCII

    Write-Host "==> Registrando Tarea Programada ejecutable como SYSTEM..."
    $action  = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\PostDcSetup.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    # Usamos la definicion nativa directa de SYSTEM mas estable en Task Scheduler
    Register-ScheduledTask -TaskName "PostDcSetup" -Action $action -Trigger $trigger -RunLevel Highest -User "SYSTEM" -Force | Out-Null

    Write-Host "==> Iniciando promocion de bosque AD (La maquina se reiniciara sola)..."
    $sec = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    
    # Quitamos el switch conflictivo y dejamos que el comportamiento nativo reinicie
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
