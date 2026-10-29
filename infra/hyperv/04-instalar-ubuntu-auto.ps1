# ============================================================
# 04-instalar-ubuntu-auto.ps1  -  Instala o Ubuntu Server 24.04 sem
# interacao (autoinstall) nas VMs criadas pelo 02-criar-vms.ps1
# Executar como Administrador (PowerShell 5.1)
#
# Uso:
#   .\04-instalar-ubuntu-auto.ps1 -VmName vnes-infra -Hostname ns1   -Ip 192.168.50.10 -ChavePublica "$HOME\.ssh\vnes-admin.pub" -SenhaHash '<hash>'
#   .\04-instalar-ubuntu-auto.ps1 -VmName vnes-cloud -Hostname cloud -Ip 192.168.50.20 -ChavePublica "$HOME\.ssh\vnes-admin.pub" -SenhaHash '<hash>'
#
# Hash da senha (Git Bash ou Linux):  openssl passwd -6 'MinhaSenha'
#
# Como funciona: cria um disco CIDATA (FAT32) com o user-data gerado a
# partir de ..\autoinstall\user-data.tpl, sobe a RAM para 2 GB durante a
# instalacao (o instalador trava com 1 GB), da boot pela ISO, responde
# "yes" na confirmacao do autoinstall pelo teclado virtual e, quando a VM
# desliga sozinha, remove ISO e CIDATA e volta a RAM ao valor final.
# ============================================================
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $true)] [string]$VmName,
    [Parameter(Mandatory = $true)] [string]$Hostname,
    [Parameter(Mandatory = $true)] [string]$Ip,
    [Parameter(Mandatory = $true)] [string]$ChavePublica,
    [Parameter(Mandatory = $true)] [string]$SenhaHash,
    [string]$CaminhoVMs = 'E:\HyperV\VNES',
    [long]$MemoriaInstalacao = 2GB
)

$ErrorActionPreference = 'Stop'

$vm = Get-VM -Name $VmName
if ($vm.State -ne 'Off') { throw "Desligue a VM $VmName antes (Stop-VM $VmName -TurnOff)." }
if (-not (Get-VMDvdDrive $VmName).Path) { throw "A VM $VmName nao tem a ISO no DVD." }
$memoriaFinal = (Get-VMMemory $VmName).Startup

Write-Host "==> [1/6] Gerando o user-data do autoinstall" -ForegroundColor Cyan
$tpl = Get-Content (Join-Path $PSScriptRoot '..\autoinstall\user-data.tpl') -Raw
$userData = $tpl.Replace('__HOSTNAME__', $Hostname).Replace('__IP__', $Ip).
    Replace('__CHAVE_SSH_PUBLICA__', (Get-Content $ChavePublica -Raw).Trim()).
    Replace('__SENHA_HASH__', $SenhaHash)

Write-Host "==> [2/6] Criando o disco CIDATA" -ForegroundColor Cyan
$seed = Join-Path $CaminhoVMs "$VmName-cidata.vhdx"
if (Test-Path $seed) { Remove-Item $seed -Force }
New-VHD -Path $seed -SizeBytes 64MB -Dynamic | Out-Null
$disco = Mount-VHD $seed -Passthru | Get-Disk
Initialize-Disk -Number $disco.Number -PartitionStyle MBR
$part = New-Partition -DiskNumber $disco.Number -UseMaximumSize -AssignDriveLetter
Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel CIDATA -Confirm:$false | Out-Null
$letra = (Get-Partition -DiskNumber $disco.Number | Where-Object DriveLetter).DriveLetter
[IO.File]::WriteAllText("$($letra):\user-data", $userData.Replace("`r`n", "`n"))
[IO.File]::WriteAllText("$($letra):\meta-data", '')
Dismount-VHD $seed

Write-Host "==> [3/6] Ligando a VM pela ISO ($([math]::Round($MemoriaInstalacao/1GB)) GB de RAM durante a instalacao)" -ForegroundColor Cyan
Set-VMMemory $VmName -StartupBytes $MemoriaInstalacao
Add-VMHardDiskDrive -VMName $VmName -Path $seed
Set-VMFirmware $VmName -FirstBootDevice (Get-VMDvdDrive $VmName)
Start-VM $VmName

Write-Host "==> [4/6] Aguardando o instalador e confirmando o autoinstall" -ForegroundColor Cyan
Start-Sleep -Seconds 120
$cs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_ComputerSystem -Filter "ElementName='$VmName'"
$teclado = Get-CimAssociatedInstance -InputObject $cs -ResultClassName Msvm_Keyboard
foreach ($tecla in 0x59, 0x45, 0x53, 0x0D) {   # y, e, s, Enter
    Invoke-CimMethod -InputObject $teclado -MethodName TypeKey -Arguments @{ keyCode = [uint32]$tecla } | Out-Null
    Start-Sleep -Milliseconds 200
}
Write-Host "    Acompanhe em: vmconnect localhost $VmName  (nao digite nada)"

Write-Host "==> [5/6] Instalando... a VM desliga sozinha ao terminar (10 a 20 min)" -ForegroundColor Cyan
while ((Get-VM $VmName).State -ne 'Off') { Start-Sleep -Seconds 20 }

Write-Host "==> [6/6] Removendo ISO e CIDATA, boot pelo disco, RAM final" -ForegroundColor Cyan
Get-VMHardDiskDrive $VmName | Where-Object Path -like '*cidata*' | Remove-VMHardDiskDrive
Set-VMDvdDrive -VMName $VmName -Path $null
Set-VMFirmware $VmName -FirstBootDevice (Get-VMHardDiskDrive $VmName | Select-Object -First 1)
Set-VMMemory $VmName -StartupBytes $memoriaFinal

Write-Host ""
Write-Host "Pronto. Ligue com: Start-VM $VmName ; depois: ssh -i `$HOME\.ssh\vnes-admin ubuntu@$Ip" -ForegroundColor Green
