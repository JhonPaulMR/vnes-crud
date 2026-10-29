# ============================================================
# 03-configurar-cliente.ps1  -  Configura o Windows como cliente da nuvem VNES
# Executar como Administrador (PowerShell 5.1)
#
# Faz:
#   1) Rota persistente 172.24.4.0/24 via 192.168.50.20 (rede publica do DevStack)
#   2) Regra NRPT: so *.vnes.com.br usa o Bind (192.168.50.10)
#   3) Importa a CA raiz da VNES nas Autoridades Raiz Confiaveis
#   4) Limpa cache DNS e roda testes
#
# Uso:
#   .\03-configurar-cliente.ps1
#   .\03-configurar-cliente.ps1 -CaminhoCA "C:\Users\voce\vnes-root-ca.crt"
# ============================================================
#Requires -RunAsAdministrator

param(
    [string]$CaminhoCA = '.\vnes-root-ca.crt'
)

$ErrorActionPreference = 'Stop'

$Alias   = 'vEthernet (VNES-NET)'
$Destino = '172.24.4.0/24'
$Gateway = '192.168.50.20'
$Dns     = '192.168.50.10'

Write-Host "==> [1/4] Rota $Destino via $Gateway ..." -ForegroundColor Cyan
$rota = Get-NetRoute -DestinationPrefix $Destino -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -eq $Gateway }
if ($rota) {
    Write-Host "    Rota ja existe. Pulando." -ForegroundColor Yellow
} else {
    # Sem -PolicyStore a rota vai para o ActiveStore e o PersistentStore (sobrevive a reinicios)
    New-NetRoute -DestinationPrefix $Destino -InterfaceAlias $Alias -NextHop $Gateway `
                 -ErrorAction Stop | Out-Null
    Write-Host "    Rota criada (persistente)." -ForegroundColor Green
}

Write-Host "==> [2/4] Regra NRPT .vnes.com.br -> $Dns ..." -ForegroundColor Cyan
$nrpt = Get-DnsClientNrptRule | Where-Object { $_.Namespace -contains '.vnes.com.br' }
if ($nrpt) {
    Write-Host "    Regra NRPT ja existe. Pulando." -ForegroundColor Yellow
} else {
    Add-DnsClientNrptRule -Namespace '.vnes.com.br' -NameServers $Dns | Out-Null
    Write-Host "    Regra NRPT criada." -ForegroundColor Green
}

Write-Host "==> [3/4] Importando CA raiz em Cert:\LocalMachine\Root ..." -ForegroundColor Cyan
if (Test-Path $CaminhoCA) {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (Resolve-Path $CaminhoCA).Path
    $jaExiste = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
    if ($jaExiste) {
        Write-Host "    CA ja instalada ($($cert.Subject)). Pulando." -ForegroundColor Yellow
    } else {
        Import-Certificate -FilePath $CaminhoCA -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
        Write-Host "    CA importada: $($cert.Subject)" -ForegroundColor Green
    }
} else {
    Write-Host "    Arquivo $CaminhoCA nao encontrado. Copie-o da vnes-infra:" -ForegroundColor Red
    Write-Host "      scp ubuntu@192.168.50.10:/opt/vnes-ca/certs/vnes-root-ca.crt ."
}

Write-Host "==> [4/4] Limpando cache DNS ..." -ForegroundColor Cyan
Clear-DnsClientCache

Write-Host ""
Write-Host "==== Testes ====" -ForegroundColor Green
Write-Host "-- Resolve-DnsName cloud.vnes.com.br"
try { Resolve-DnsName cloud.vnes.com.br -ErrorAction Stop | Format-Table Name, Type, IPAddress -AutoSize }
catch { Write-Host "   Falhou: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "-- Test-NetConnection 192.168.50.20 -Port 443"
Test-NetConnection 192.168.50.20 -Port 443 | Format-List ComputerName, RemotePort, TcpTestSucceeded

Write-Host ""
Write-Host "NOTA - Firefox: ele usa o repositorio de certificados proprio." -ForegroundColor Yellow
Write-Host "  Abra about:config e defina  security.enterprise_roots.enabled = true"
Write-Host "  (assim ele passa a confiar na CA importada no Windows). Chrome/Edge ja usam o Windows."
