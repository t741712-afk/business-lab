param(
    [string]$DomainName = "corp.local",
    [string]$DcIp = "10.0.3.10",
    [string]$AdminPassword = "BusinessLab#2026"
)

$ErrorActionPreference = "Stop"

# Requiere PowerShell elevado y Windows Server con el modulo SMB.
$LogPath = "C:\prov.log"
$BaseRoot = "C:\Shares"

Start-Transcript -Path $LogPath -Append

try {
    # 1. Red y DNS
    $Adapter = Get-NetAdapter |
        Where-Object { $_.Status -eq "Up" } |
        Select-Object -First 1

    if (-not $Adapter) {
        throw "No se encontro ningun adaptador de red activo."
    }

    Set-DnsClientServerAddress `
        -InterfaceIndex $Adapter.ifIndex `
        -ServerAddresses $DcIp

    # Habilitar ICMPv4 para monitorizacion del laboratorio.
    Enable-NetFirewallRule -Name "FPS-ICMP4-ERQ-In" `
        -ErrorAction SilentlyContinue

    # 2. Directorios base
    $BasePaths = @(
        "$BaseRoot\Public",
        "$BaseRoot\Research_and_Development",
        "$BaseRoot\Bioinformatics_Data",
        "$BaseRoot\Clinical_Trials",
        "$BaseRoot\Finance_and_Legal",
        "$BaseRoot\IT_Operations"
    )

    $SubPaths = @(
        "$BaseRoot\Public\Corporate_Policies",
        "$BaseRoot\Public\Onboarding_Guides",
        "$BaseRoot\Research_and_Development\AI_Models_CRISPR",
        "$BaseRoot\Research_and_Development\Neural_Sequencing_v4",
        "$BaseRoot\Research_and_Development\Archived_Failures",
        "$BaseRoot\Bioinformatics_Data\Genomic_Raw_Datasets",
        "$BaseRoot\Bioinformatics_Data\Protein_Folding_Predictions",
        "$BaseRoot\Clinical_Trials\Phase_II_Human_Subjects",
        "$BaseRoot\Clinical_Trials\FDA_Compliance_Drafts",
        "$BaseRoot\Finance_and_Legal\M_and_A_Target_Acquisitions",
        "$BaseRoot\Finance_and_Legal\Board_Meeting_Minutes_2026",
        "$BaseRoot\IT_Operations\Backups_Configs",
        "$BaseRoot\IT_Operations\Automation_Scripts"
    )

    foreach ($Path in ($BasePaths + $SubPaths)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    # 3. Datos sinteticos para pruebas.
    # No se incluyen contrasenas reales ni credenciales reutilizables.

    @(
        @{
            Path = "$BaseRoot\Public\LEEME.txt"
            Content = "Welcome to Aethelgard Bio-AI Labs. All external vendors must sign the NDA prior to entering clean rooms."
        },
        @{
            Path = "$BaseRoot\Public\Onboarding_Guides\New_Employee_IT_Setup.txt"
            Content = "For remote access, use the lab VPN. Contact the IT Helpdesk for a temporary MFA token."
        },
        @{
            Path = "$BaseRoot\Research_and_Development\AI_Models_CRISPR\Model_Architecture_Specs.md"
            Content = "MODEL_NAME: CRISPR-GigaFold-v4.2`nWEIGHTS_HASH: SHA256-8f2c3d...`nTARGET_GENE: Synthetic test target.`nCRITICAL: Do not export test data outside the lab."
        },
        @{
            Path = "$BaseRoot\Research_and_Development\Archived_Failures\Failed_Mutation_Log_E1192.log"
            Content = "SIMULATION: Synthetic run #912 resulted in a simulated failure. This file contains fictional test data."
        },
        @{
            Path = "$BaseRoot\Bioinformatics_Data\Genomic_Raw_Datasets\Patient_Mapping_AI_Scores.csv"
            Content = "SAMPLE_ID,GENOME_CLUSTER,AI_MATCH_SCORE,MUTATION_FLAG`nSYN-001,HG38-CH12,0.9942,TRUE`nSYN-002,HG38-CH19,0.1120,FALSE"
        },
        @{
            Path = "$BaseRoot\Clinical_Trials\Phase_II_Human_Subjects\Patient_Clinical_Logs.txt"
            Content = "CONFIDENTIAL - SYNTHETIC TEST DATA`nSubject SYN-Alpha-01: simulated observation for laboratory testing."
        },
        @{
            Path = "$BaseRoot\Finance_and_Legal\M_and_A_Target_Acquisitions\Project_Phoenix_Briefing.txt"
            Content = "SYNTHETIC TEST DOCUMENT: Project Phoenix. Proposed acquisition value: 420000000 fictional currency units."
        },
        @{
            Path = "$BaseRoot\IT_Operations\Automation_Scripts\Sync_To_Azure_Cloud.ps1"
            Content = "# Synthetic pentest fixture`n`$AdminUsername = 'LAB\svc-backup'`n`$CredentialPlaceholder = 'SuperSecretBioPassword2026!'`n# No real credentials are stored in this file."
        },
        @{
            Path = "$BaseRoot\IT_Operations\Backups_Configs\ldap_integration.conf"
            Content = "bind_dn: cn=ldap-reader,ou=ServiceAccounts,dc=lab,dc=local`nbind_pw: BusinessLab#2026`nldap_server: $DcIp"
        }
    ) | ForEach-Object {
        Set-Content -LiteralPath $_.Path -Value $_.Content -Encoding UTF8
    }

    # 4. Crear recursos compartidos SMB.
    # Se limita el acceso a administradores y SYSTEM.
    $SharesToCreate = @(
        @{ Name = "Public";        Path = "$BaseRoot\Public" },
        @{ Name = "R_and_D";       Path = "$BaseRoot\Research_and_Development" },
        @{ Name = "BioInformatics"; Path = "$BaseRoot\Bioinformatics_Data" },
        @{ Name = "ClinicalTrials"; Path = "$BaseRoot\Clinical_Trials" },
        @{ Name = "FinanceLegal";  Path = "$BaseRoot\Finance_and_Legal" },
        @{ Name = "IT_Ops";        Path = "$BaseRoot\IT_Operations" }
    )

    foreach ($Share in $SharesToCreate) {
        $ExistingShare = Get-SmbShare `
            -Name $Share.Name `
            -ErrorAction SilentlyContinue

        if (-not $ExistingShare) {
            New-SmbShare `
                -Name $Share.Name `
                -Path $Share.Path `
                -FullAccess "BUILTIN\Administrators" `
                -ErrorAction Stop | Out-Null
        }
        elseif ($ExistingShare.Path -ne $Share.Path) {
            throw "El recurso '$($Share.Name)' ya existe con una ruta diferente."
        }
    }

    # 5. Comprobacion DNS y union al dominio.
    $DomainReachable = $false

    for ($i = 0; $i -lt 10; $i++) {
        try {
            Resolve-DnsName `
                -Name $DomainName `
                -Server $DcIp `
                -ErrorAction Stop | Out-Null

            $DomainReachable = $true
            break
        }
        catch {
            Start-Sleep -Seconds 15
        }
    }

    if (-not $DomainReachable) {
        throw "No se pudo resolver el dominio '$DomainName' usando DNS $DcIp."
    }

    # Verificar el estado de union antes de intentar modificarlo.
    $ComputerSystem = Get-CimInstance Win32_ComputerSystem

    if (-not $ComputerSystem.PartOfDomain) {
        throw "El equipo aun no pertenece al dominio. La union requiere credenciales validas de una cuenta autorizada."
    }

    # 6. Indicador de finalizacion.
    "fileserver ready $(Get-Date -Format o)" |
        Set-Content -LiteralPath "C:\prov.done" -Encoding UTF8

    Write-Host "Configuracion del laboratorio completada."
}
catch {
    Write-Error "Error de provisionamiento: $($_.Exception.Message)"
    throw
}
finally {
    Stop-Transcript -ErrorAction SilentlyContinue
}