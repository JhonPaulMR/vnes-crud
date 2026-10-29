# ============================================================
# 05-desligar-nuvem.ps1  -  Desliga a nuvem VNES com seguranca
# Executar como Administrador (PowerShell 5.1)
#
# Ordem: 1) para as instancias do OpenStack (vnes-web, vnes-db)
#        2) desliga a VM vnes-cloud (shutdown gracioso)
#        3) desliga a VM vnes-infra
# ============================================================
#Requires -RunAsAdministrator

param(
    [string]$IpCloud   = '192.168.50.20',
    [string]$ChaveSsh  = "$HOME\.ssh\vnes-admin",
    [int]$TimeoutVmSeg = 300
)

$ErrorActionPreference = 'Stop'
$sshOpts = @('-i', $ChaveSsh, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=8')

function Passo($t) { Write-Host "==> $t" -ForegroundColor Cyan }

# Executa um script bash na vnes-cloud. Vai em base64 para evitar BOM/CRLF do pipe do PS 5.1.
function Invoke-Remoto($script) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
    & ssh @sshOpts "ubuntu@$IpCloud" "echo $b64 | base64 -d | bash"
}

function Esperar-VmDesligada($nome, $timeout) {
    $fim = (Get-Date).AddSeconds($timeout)
    while ((Get-VM -Name $nome).State -ne 'Off') {
        if ((Get-Date) -gt $fim) { return $false }
        Start-Sleep -Seconds 3
    }
    return $true
}

$vmCloud = Get-VM -Name 'vnes-cloud' -ErrorAction SilentlyContinue
$vmInfra = Get-VM -Name 'vnes-infra' -ErrorAction SilentlyContinue
if (-not $vmCloud -or -not $vmInfra) { throw 'VMs vnes-cloud/vnes-infra nao encontradas no Hyper-V.' }

# --- 1) Instancias do OpenStack ---------------------------------------
if ($vmCloud.State -eq 'Running') {
    Passo 'Parando as instancias do OpenStack (vnes-web, vnes-db)'
    $remoto = @'
os() { sudo -u stack -i bash -c "source ~/devstack/openrc admin admin; $*" </dev/null; }
for i in $(seq 1 30); do os "openstack token issue -f value -c id" >/dev/null 2>&1 && break; sleep 5; done
ids=$(os "openstack server list --all-projects -f value -c ID -c Status" | awk '$2=="ACTIVE"{print $1}')
if [ -n "$ids" ]; then os "openstack server stop $(echo $ids)"; fi
for i in $(seq 1 60); do
  n=$(os "openstack server list --all-projects -f value -c Status" | grep -vc SHUTOFF)
  [ "$n" = "0" ] && echo "Instancias: SHUTOFF" && exit 0
  sleep 5
done
echo "AVISO: instancias nao chegaram a SHUTOFF no tempo previsto"; exit 0
'@
    $remoto = $remoto -replace "`r", ''
    try {
        Invoke-Remoto $remoto
    } catch {
        Write-Host "AVISO: nao foi possivel parar as instancias via SSH: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "vnes-cloud ja esta $($vmCloud.State); pulando parada das instancias."
}

# --- 2) vnes-cloud ----------------------------------------------------
if ((Get-VM -Name 'vnes-cloud').State -ne 'Off') {
    Passo 'Desligando a VM vnes-cloud (shutdown gracioso)'
    Stop-VM -Name 'vnes-cloud'
    if (-not (Esperar-VmDesligada 'vnes-cloud' $TimeoutVmSeg)) {
        Write-Host 'vnes-cloud nao desligou a tempo; forcando (Stop-VM -TurnOff).' -ForegroundColor Yellow
        Stop-VM -Name 'vnes-cloud' -TurnOff -Force
    }
}

# --- 3) vnes-infra ----------------------------------------------------
if ((Get-VM -Name 'vnes-infra').State -ne 'Off') {
    Passo 'Desligando a VM vnes-infra'
    Stop-VM -Name 'vnes-infra'
    if (-not (Esperar-VmDesligada 'vnes-infra' $TimeoutVmSeg)) {
        Write-Host 'vnes-infra nao desligou a tempo; forcando (Stop-VM -TurnOff).' -ForegroundColor Yellow
        Stop-VM -Name 'vnes-infra' -TurnOff -Force
    }
}

Get-VM -Name 'vnes-infra', 'vnes-cloud' | Format-Table Name, State -AutoSize
Write-Host 'Nuvem desligada. Para religar: .\06-ligar-nuvem.ps1' -ForegroundColor Green
