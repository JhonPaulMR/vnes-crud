# ============================================================
# 06-ligar-nuvem.ps1  -  Liga a nuvem VNES e espera o site voltar
# Executar como Administrador (PowerShell 5.1)
#
# Ordem: 1) vnes-infra (DNS + CA)  2) vnes-cloud (DevStack, 6 GB)
#        3) espera Keystone/Horizon  4) liga instancias se preciso
#        5) espera https://www.vnes.com.br/ responder 200
# O DevStack pode levar varios minutos para subir; o script faz polling.
# ============================================================
#Requires -RunAsAdministrator

param(
    [string]$IpInfra   = '192.168.50.10',
    [string]$IpCloud   = '192.168.50.20',
    [string]$ChaveSsh  = "$HOME\.ssh\vnes-admin",
    [int]$TimeoutCloudSeg = 900,
    [int]$TimeoutSiteSeg  = 600
)

$ErrorActionPreference = 'Stop'
$sshOpts = @('-i', $ChaveSsh, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=8')
$t0 = Get-Date

function Passo($t) { Write-Host "==> $t" -ForegroundColor Cyan }

# Executa um script bash na vnes-cloud. Vai em base64 para evitar BOM/CRLF do pipe do PS 5.1.
function Invoke-Remoto($script) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
    & ssh @sshOpts "ubuntu@$IpCloud" "echo $b64 | base64 -d | bash"
}

# Retorna o codigo HTTP (0 se falhou a conexao/TLS). Nao segue redirecionamentos.
function Get-HttpCodigo($url) {
    try {
        $req = [Net.HttpWebRequest]::Create($url)
        $req.Timeout = 8000
        $req.AllowAutoRedirect = $false
        $resp = $req.GetResponse()
        $c = [int]$resp.StatusCode
        $resp.Close()
        return $c
    } catch [Net.WebException] {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return 0
    } catch { return 0 }
}

function Esperar($descricao, [scriptblock]$teste, $timeout) {
    $fim = (Get-Date).AddSeconds($timeout)
    while ($true) {
        if (& $teste) { Write-Host "    OK: $descricao" -ForegroundColor Green; return }
        if ((Get-Date) -gt $fim) { throw "Tempo esgotado esperando: $descricao" }
        Start-Sleep -Seconds 5
    }
}

function Porta-Aberta($ip, $porta) {
    try {
        $c = New-Object Net.Sockets.TcpClient
        $ar = $c.BeginConnect($ip, $porta, $null, $null)
        $ok = $ar.AsyncWaitHandle.WaitOne(2000) -and $c.Connected
        $c.Close()
        return $ok
    } catch { return $false }
}

$vmInfra = Get-VM -Name 'vnes-infra' -ErrorAction SilentlyContinue
$vmCloud = Get-VM -Name 'vnes-cloud' -ErrorAction SilentlyContinue
if (-not $vmInfra -or -not $vmCloud) { throw 'VMs vnes-cloud/vnes-infra nao encontradas no Hyper-V.' }

# --- 1) vnes-infra ----------------------------------------------------
if ($vmInfra.State -ne 'Running') {
    Passo 'Ligando a VM vnes-infra'
    Start-VM -Name 'vnes-infra'
}
Passo 'Esperando DNS (porta 53) e SSH da vnes-infra'
Esperar "DNS/SSH em $IpInfra" { (Porta-Aberta $IpInfra 53) -and (Porta-Aberta $IpInfra 22) } 300

# --- 2) vnes-cloud ----------------------------------------------------
if ($vmCloud.State -ne 'Running') {
    Passo 'Ligando a VM vnes-cloud (6 GB de RAM)'
    try {
        Start-VM -Name 'vnes-cloud'
    } catch {
        Write-Host ''
        Write-Host 'ERRO: nao foi possivel ligar a vnes-cloud (provavelmente falta de RAM livre no Windows).' -ForegroundColor Red
        Write-Host 'Feche Docker Desktop (e rode "wsl --shutdown"), Teams, IDEs e navegadores pesados e execute de novo.' -ForegroundColor Red
        Write-Host "Detalhe: $($_.Exception.Message)" -ForegroundColor DarkGray
        exit 1
    }
}
Passo 'Esperando o DevStack (Keystone e Horizon HTTPS) - pode levar varios minutos'
Esperar 'SSH da vnes-cloud' { Porta-Aberta $IpCloud 22 } 300
Esperar 'Keystone http://192.168.50.20/identity/v3/ (200)' { (Get-HttpCodigo "http://$IpCloud/identity/v3/") -eq 200 } $TimeoutCloudSeg
Esperar 'Horizon https://cloud.vnes.com.br/dashboard/' { $c = Get-HttpCodigo 'https://cloud.vnes.com.br/dashboard/'; ($c -eq 200) -or ($c -eq 302) } $TimeoutCloudSeg

# --- 3) instancias ----------------------------------------------------
Passo 'Garantindo que as instancias (vnes-db, vnes-web) estejam ACTIVE'
$remoto = @'
os() { sudo -u stack -i bash -c "source ~/devstack/openrc admin admin; $*" </dev/null; }
# espera o nova-compute ficar "up"
for i in $(seq 1 60); do
  os "openstack compute service list --service nova-compute -f value -c State" 2>/dev/null | grep -q up && break
  sleep 5
done
ids=$(os "openstack server list --all-projects -f value -c ID -c Status" | awk '$2=="SHUTOFF"{print $1}')
if [ -n "$ids" ]; then echo "Iniciando instancias desligadas..."; os "openstack server start $(echo $ids)"; fi
os "openstack server list --all-projects -c Name -c Status -c Networks"
echo "VNES_WEB=$(os "openstack server list --all-projects --name vnes-web -f value -c ID" | grep -c .)"
'@
$remoto = $remoto -replace "`r", ''
$saida = Invoke-Remoto $remoto
$saida | Where-Object { $_ -notlike 'VNES_WEB=*' } | ForEach-Object { Write-Host $_ }
$temWeb = ($saida | Where-Object { $_ -like 'VNES_WEB=*' }) -ne 'VNES_WEB=0'

# --- 4) site ----------------------------------------------------------
if ($temWeb) {
    Passo 'Esperando https://www.vnes.com.br/ (200)'
    Esperar 'https://www.vnes.com.br/ respondendo 200' { (Get-HttpCodigo 'https://www.vnes.com.br/') -eq 200 } $TimeoutSiteSeg
} else {
    Passo 'Instancia vnes-web nao existe (ambiente pronto para criar ao vivo). Pulando a espera do site.'
}

# --- 5) checagens finais ----------------------------------------------
Passo 'Checagens finais'
$remoto = @'
echo "br-ex: $(ip -4 -o addr show br-ex | awk '{print $4}')"
echo "MASQUERADE: $(sudo iptables -t nat -S POSTROUTING | grep -c '172.24.4.0/24.*MASQUERADE') regra(s)"
'@
$remoto = $remoto -replace "`r", ''
Invoke-Remoto $remoto
Write-Host ("www.vnes.com.br   -> HTTP {0}" -f (Get-HttpCodigo 'https://www.vnes.com.br/'))
Write-Host ("cloud.vnes.com.br -> HTTP {0}" -f (Get-HttpCodigo 'https://cloud.vnes.com.br/dashboard/'))

$min = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
Write-Host ''
Write-Host "Nuvem no ar em $min min. Abra:" -ForegroundColor Green
Write-Host '  Site (CRUD):  https://www.vnes.com.br/'
Write-Host '  Horizon:      https://cloud.vnes.com.br/dashboard/'
