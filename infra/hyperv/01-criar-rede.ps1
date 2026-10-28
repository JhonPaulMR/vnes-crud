# ============================================================
# 01-criar-rede.ps1  -  Rede do laboratorio VNES no Hyper-V
# Executar como Administrador (PowerShell 5.1)
#
# Cria:
#   - vSwitch interno  VNES-NET
#   - IP 192.168.50.1/24 no host (gateway das VMs)
#   - NAT VNES-NAT para 192.168.50.0/24 (saida para a internet)
# Idempotente: se ja existir, apenas informa e segue.
# ============================================================
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$NomeSwitch = 'VNES-NET'
$NomeNat    = 'VNES-NAT'
$IpHost     = '192.168.50.1'
$Prefixo    = 24
$Rede       = '192.168.50.0/24'
$Alias      = "vEthernet ($NomeSwitch)"

Write-Host "==> [1/3] Verificando vSwitch interno $NomeSwitch ..." -ForegroundColor Cyan
if (Get-VMSwitch -Name $NomeSwitch -ErrorAction SilentlyContinue) {
    Write-Host "    vSwitch $NomeSwitch ja existe. Pulando." -ForegroundColor Yellow
} else {
    New-VMSwitch -Name $NomeSwitch -SwitchType Internal | Out-Null
    Write-Host "    vSwitch $NomeSwitch criado." -ForegroundColor Green
}

Write-Host "==> [2/3] Configurando IP $IpHost/$Prefixo em '$Alias' ..." -ForegroundColor Cyan
$adaptador = Get-NetAdapter -Name $Alias -ErrorAction SilentlyContinue
if (-not $adaptador) {
    throw "Adaptador '$Alias' nao encontrado. Verifique se o vSwitch foi criado."
}
$ipAtual = Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
           Where-Object { $_.IPAddress -eq $IpHost }
if ($ipAtual) {
    Write-Host "    IP $IpHost ja configurado. Pulando." -ForegroundColor Yellow
} else {
    # Remove IPs antigos (ex.: APIPA 169.254.x.x) antes de definir o correto
    Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceAlias $Alias -IPAddress $IpHost -PrefixLength $Prefixo | Out-Null
    Write-Host "    IP $IpHost/$Prefixo configurado." -ForegroundColor Green
}

Write-Host "==> [3/3] Verificando NAT $NomeNat ($Rede) ..." -ForegroundColor Cyan
if (Get-NetNat -Name $NomeNat -ErrorAction SilentlyContinue) {
    Write-Host "    NAT $NomeNat ja existe. Pulando." -ForegroundColor Yellow
} else {
    New-NetNat -Name $NomeNat -InternalIPInterfaceAddressPrefix $Rede | Out-Null
    Write-Host "    NAT $NomeNat criado." -ForegroundColor Green
}

Write-Host ""
Write-Host "Rede pronta. Resumo:" -ForegroundColor Green
Get-VMSwitch -Name $NomeSwitch | Format-Table Name, SwitchType -AutoSize
Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength -AutoSize
Get-NetNat -Name $NomeNat | Format-Table Name, InternalIPInterfaceAddressPrefix -AutoSize
Write-Host "Proximo passo: .\02-criar-vms.ps1 -IsoPath <caminho do ISO>"
