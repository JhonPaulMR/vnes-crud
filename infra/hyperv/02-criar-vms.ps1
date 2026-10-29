# ============================================================
# 02-criar-vms.ps1  -  Cria as VMs vnes-infra e vnes-cloud (Gen2)
# Executar como Administrador (PowerShell 5.1)
#
# Uso:
#   .\02-criar-vms.ps1 -IsoPath "E:\ISOs\ubuntu-24.04-live-server-amd64.iso"
#   .\02-criar-vms.ps1 -IsoPath "..." -CaminhoVMs "D:\HyperV\VNES"
#
# Idempotente: VMs que ja existem sao puladas.
# ============================================================
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [string]$CaminhoVMs = 'E:\HyperV\VNES',

    [string]$NomeSwitch = 'VNES-NET'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $IsoPath)) { throw "ISO nao encontrado: $IsoPath" }
if (-not (Get-VMSwitch -Name $NomeSwitch -ErrorAction SilentlyContinue)) {
    throw "vSwitch $NomeSwitch nao existe. Execute antes o 01-criar-rede.ps1"
}
if (-not (Test-Path $CaminhoVMs)) {
    New-Item -ItemType Directory -Path $CaminhoVMs -Force | Out-Null
}

function Novo-VnesVM {
    param(
        [string]$Nome,
        [int]$VCpu,
        [long]$Memoria,
        [long]$Disco,
        [bool]$Nested
    )

    Write-Host "==> Criando VM $Nome ..." -ForegroundColor Cyan
    if (Get-VM -Name $Nome -ErrorAction SilentlyContinue) {
        Write-Host "    VM $Nome ja existe. Pulando." -ForegroundColor Yellow
        return
    }

    $vhdx = Join-Path $CaminhoVMs "$Nome\$Nome.vhdx"
    New-VM -Name $Nome -Generation 2 -MemoryStartupBytes $Memoria `
           -NewVHDPath $vhdx -NewVHDSizeBytes $Disco `
           -Path $CaminhoVMs -SwitchName $NomeSwitch | Out-Null

    # Memoria estatica (obrigatorio para virtualizacao aninhada)
    Set-VMMemory -VMName $Nome -DynamicMemoryEnabled $false
    Set-VMProcessor -VMName $Nome -Count $VCpu

    # Secure Boot com template que aceita o Ubuntu
    Set-VMFirmware -VMName $Nome -EnableSecureBoot On `
                   -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'

    # Sem checkpoints automaticos (consomem disco e atrapalham o DevStack)
    Set-VM -Name $Nome -AutomaticCheckpointsEnabled $false

    # DVD com o ISO e boot por ele primeiro
    $dvd = Add-VMDvdDrive -VMName $Nome -Path $IsoPath -Passthru
    Set-VMFirmware -VMName $Nome -FirstBootDevice $dvd

    if ($Nested) {
        Write-Host "    Habilitando virtualizacao aninhada e MAC spoofing ..." -ForegroundColor Cyan
        Set-VMProcessor -VMName $Nome -ExposeVirtualizationExtensions $true
        Set-VMNetworkAdapter -VMName $Nome -MacAddressSpoofing On
    }

    Write-Host "    VM $Nome criada." -ForegroundColor Green
}

Novo-VnesVM -Nome 'vnes-infra' -VCpu 2 -Memoria 1GB  -Disco 20GB  -Nested $false
Novo-VnesVM -Nome 'vnes-cloud' -VCpu 4 -Memoria 6GB -Disco 100GB -Nested $true

Write-Host ""
Write-Host "Resumo das VMs:" -ForegroundColor Green
Get-VM -Name 'vnes-infra', 'vnes-cloud' |
    Select-Object Name, State, ProcessorCount,
        @{N = 'MemoriaGB'; E = { $_.MemoryStartup / 1GB } },
        @{N = 'MemDinamica'; E = { $_.DynamicMemoryEnabled } } |
    Format-Table -AutoSize
Get-VMNetworkAdapter -VMName 'vnes-infra', 'vnes-cloud' |
    Select-Object VMName, SwitchName, MacAddressSpoofing | Format-Table -AutoSize

Write-Host "Proximos passos:"
Write-Host "  Start-VM vnes-infra ; vmconnect localhost vnes-infra"
Write-Host "  Instale o Ubuntu Server 24.04 (ative OpenSSH) e depois aplique o netplan de infra\netplan\."
