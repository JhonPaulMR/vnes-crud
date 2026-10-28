# Hyper-V (host Windows)

Execute no PowerShell **como Administrador**, nesta ordem:

1. `.\01-criar-rede.ps1` - vSwitch `VNES-NET`, IP `192.168.50.1/24`, NAT `VNES-NAT`.
2. `.\02-criar-vms.ps1 -IsoPath "E:\ISOs\ubuntu-24.04-live-server-amd64.iso"` - cria `vnes-infra` e `vnes-cloud`.
   Depois instale o Ubuntu em cada VM e aplique o netplan de `infra/netplan/`.
3. (Depois que a `vnes-infra` estiver com Bind e CA prontos)
   `scp ubuntu@192.168.50.10:/opt/vnes-ca/certs/vnes-root-ca.crt .` e então
   `.\03-configurar-cliente.ps1` - rota, regra NRPT, importação da CA.

Se a política de execução bloquear: `Set-ExecutionPolicy -Scope Process Bypass`.
