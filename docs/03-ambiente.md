# Passo III - Ambiente: rede, DNS, CA e nuvem privada (REQ10, REQ11, REQ12)

Convenções: 🪟 Windows (PowerShell **como Administrador** nos scripts do Hyper-V) | 🖥️ `vnes-infra` | ☁️ `vnes-cloud`.
Todos os valores (IPs, nomes, caminhos) estão em `infra/VARIAVEIS.md`. Usuário Linux das VMs: `ubuntu` (os scripts usam `ubuntu@...` nos exemplos).

Tempo total estimado: 2h30 a 3h30 (o `stack.sh` leva 40 a 70 min).

## 0. Pré-requisitos

- Windows 11 Pro com **Hyper-V** habilitado (`Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All`).
- ISO **Ubuntu Server 24.04 LTS** (ex.: `E:\ISOs\ubuntu-24.04-live-server-amd64.iso`).
- Docker Desktop e WSL parados (RAM; ver `docs/README.md`).
- Repositório na máquina Windows em `E:\Codes\Trabalho Cloud\vnes-crud` (pasta `infra/` presente).

🪟 Se a política de execução bloquear scripts:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

## 1. Rede e VMs no Hyper-V (REQ09)

🪟

```powershell
cd "E:\Codes\Trabalho Cloud\vnes-crud\infra\hyperv"
.\01-criar-rede.ps1
.\02-criar-vms.ps1 -IsoPath "E:\ISOs\ubuntu-24.04-live-server-amd64.iso"
# opcional: -CaminhoVMs "D:\HyperV\VNES" (padrão E:\HyperV\VNES)
```

O que faz: vSwitch interno `VNES-NET`, IP `192.168.50.1/24` no Windows, NAT `VNES-NAT`; VMs Gen2 `vnes-infra` (2 vCPU, 1 GB, 20 GB) e `vnes-cloud` (4 vCPU, 11 GB estática, 100 GB, virtualização aninhada + MAC spoofing).

**Checkpoint 1**

```powershell
Get-VMSwitch VNES-NET
Get-NetIPAddress -InterfaceAlias "vEthernet (VNES-NET)" -AddressFamily IPv4
Get-NetNat VNES-NAT
Get-VM vnes-infra, vnes-cloud | Select Name, State, ProcessorCount, @{N='MemGB';E={$_.MemoryStartup/1GB}}
(Get-VMProcessor vnes-cloud).ExposeVirtualizationExtensions   # True
```

## 2. Instalar o Ubuntu Server na `vnes-infra`

🪟

```powershell
Start-VM vnes-infra; vmconnect localhost vnes-infra
```

No instalador:

| Tela | Valor |
|---|---|
| Rede (eth0) | **Edit IPv4 -> Manual**: subnet `192.168.50.0/24`, address `192.168.50.10`, gateway `192.168.50.1`, DNS `1.1.1.1` (o NAT do Hyper-V não tem DHCP; sem isso o instalador fica sem internet) |
| Mirror / proxy | padrão |
| Storage | disco inteiro, padrão |
| Profile | nome do servidor `ns1`, usuário `ubuntu`, senha à sua escolha |
| **SSH** | marque **Install OpenSSH server** |
| Snaps | não marque nada |

Ao terminar, remova o ISO (reinicia sozinho; se voltar ao instalador: `Set-VMFirmware vnes-infra -FirstBootDevice (Get-VMHardDiskDrive vnes-infra)`).

### 2.1 Copiar `infra/` e aplicar o netplan

🪟 Copie a pasta `infra` do Windows para a VM:

```powershell
cd "E:\Codes\Trabalho Cloud\vnes-crud"
scp -r infra ubuntu@192.168.50.10:~/
ssh ubuntu@192.168.50.10
```

🖥️ Dentro da VM:

```bash
cd ~/infra
chmod +x dns/*.sh ca/*.sh cloud-init/*.sh        # scp do Windows perde o bit de execução
sudo hostnamectl set-hostname ns1
sudo mkdir -p /root/netplan-bak && sudo mv /etc/netplan/*.yaml /root/netplan-bak/
sudo cp netplan/vnes-infra.yaml /etc/netplan/50-vnes.yaml
sudo chmod 600 /etc/netplan/50-vnes.yaml
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
sudo netplan apply
```

**Checkpoint 2** (🖥️)

```bash
ip -br a                          # eth0 192.168.50.10/24
ip route                          # default via 192.168.50.1 e 172.24.4.0/24 via 192.168.50.20
ping -c2 1.1.1.1 && ping -c2 google.com
hostname                          # ns1
```

> Se a interface não se chamar `eth0` (`ip -br a`), ajuste o nome em `infra/netplan/*.yaml` antes de aplicar.

## 3. DNS - Bind9 (REQ10)

🖥️

```bash
cd ~/infra/dns
sudo ./instalar-bind.sh
```

O script instala o Bind, copia as zonas (`/etc/bind/zones/db.vnes.com.br` e `db.192.168.50`), valida (`named-checkconf`, `named-checkzone`), reinicia o serviço `named` e roda testes com `dig`. Os registros `www`, `@` e `db` ficam com valores de exemplo até as instâncias existirem.

**Checkpoint 3**

🖥️

```bash
dig @127.0.0.1 +short cloud.vnes.com.br        # 192.168.50.20
dig @127.0.0.1 +short ns1.vnes.com.br          # 192.168.50.10
dig @127.0.0.1 +short -x 192.168.50.20         # cloud.vnes.com.br.
dig @127.0.0.1 +short qualquer.vnes.com.br     # CNAME www + IP (curinga)
dig @127.0.0.1 +short google.com               # forwarders funcionando
sudo systemctl status named --no-pager | head -n 5
```

🪟 (o Windows ainda não tem a regra NRPT; consulte o servidor direto)

```powershell
Resolve-DnsName cloud.vnes.com.br -Server 192.168.50.10
nslookup cloud.vnes.com.br 192.168.50.10
```

## 4. CA e certificado curinga (REQ11)

🖥️

```bash
cd ~/infra/ca
sudo ./01-criar-ca.sh          # CA raiz RSA 4096, 10 anos, em /opt/vnes-ca
sudo ./02-emitir-curinga.sh    # *.vnes.com.br + vnes.com.br, 397 dias, assinado pela CA
```

Resultado em `/opt/vnes-ca`:

| Arquivo | Uso |
|---|---|
| `certs/vnes-root-ca.crt` | CA raiz pública (instalar no cliente) |
| `certs/wildcard.vnes.com.br.fullchain.crt` | curinga + raiz (servidores) |
| `private/wildcard.vnes.com.br.key` | chave do curinga (nunca sai da infra, exceto para os servidores) |

**Checkpoint 4**

🖥️

```bash
sudo openssl verify -CAfile /opt/vnes-ca/certs/vnes-root-ca.crt /opt/vnes-ca/certs/wildcard.vnes.com.br.crt   # OK
sudo openssl x509 -in /opt/vnes-ca/certs/wildcard.vnes.com.br.crt -noout -subject -dates -ext subjectAltName
# esperado: DNS:*.vnes.com.br, DNS:vnes.com.br
```

## 5. Cliente Windows: rota, DNS e CA (REQ10, REQ11)

🪟 Pegue a CA raiz pública e rode o script de configuração:

```powershell
scp ubuntu@192.168.50.10:/opt/vnes-ca/certs/vnes-root-ca.crt "$HOME\vnes-root-ca.crt"
cd "E:\Codes\Trabalho Cloud\vnes-crud\infra\hyperv"
.\03-configurar-cliente.ps1 -CaminhoCA "$HOME\vnes-root-ca.crt"
```

O script cria: rota persistente `172.24.4.0/24 via 192.168.50.20`, regra NRPT `.vnes.com.br -> 192.168.50.10` e importa a CA em `Cert:\LocalMachine\Root`. O teste `Test-NetConnection 192.168.50.20 -Port 443` falha por enquanto (a nuvem ainda não existe); repita no passo 7.

**Firefox:** usa repositório próprio. Em `about:config` defina `security.enterprise_roots.enabled = true`. Chrome e Edge usam o Windows. Para a gravação, prefira Edge/Chrome.

**Checkpoint 5**

🪟

```powershell
Get-NetRoute -DestinationPrefix 172.24.4.0/24
Get-DnsClientNrptRule | Where-Object Namespace -contains '.vnes.com.br'
Resolve-DnsName cloud.vnes.com.br               # sem -Server: usa a regra NRPT
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*VNES Root CA*'
```

## 6. Instalar a `vnes-cloud` e o DevStack (REQ12)

### 6.1 Ubuntu e rede

🪟

```powershell
Start-VM vnes-cloud; vmconnect localhost vnes-cloud
```

Instalador igual ao da seção 2, trocando: servidor `cloud`, IP `192.168.50.20`, DNS `192.168.50.10`, disco inteiro (100 GB), **OpenSSH server** marcado.

🪟

```powershell
cd "E:\Codes\Trabalho Cloud\vnes-crud"
scp -r infra ubuntu@192.168.50.20:~/
ssh ubuntu@192.168.50.20
```

☁️ Aplique o netplan **antes** do `stack.sh` (depois o DevStack mexe no `eth0`/`br-ex`). A `vnes-infra` deve estar ligada (é o DNS).

```bash
cd ~/infra
chmod +x devstack/*.sh
sudo hostnamectl set-hostname cloud
sudo mkdir -p /root/netplan-bak && sudo mv /etc/netplan/*.yaml /root/netplan-bak/
sudo cp netplan/vnes-cloud.yaml /etc/netplan/50-vnes.yaml
sudo chmod 600 /etc/netplan/50-vnes.yaml
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
sudo netplan apply
```

```bash
ip -br a                                     # eth0 192.168.50.20/24
resolvectl status | grep -i "DNS Servers"    # 192.168.50.10
ping -c2 cloud.vnes.com.br && ping -c2 github.com
```

### 6.2 Preparar o host

☁️

```bash
cd ~/infra/devstack
./01-preparar-host.sh
```

Pede a senha do `admin` do OpenStack (só letras e números, mínimo 8; é a senha do Horizon como admin e também do banco/RabbitMQ do DevStack). O script atualiza o sistema, **valida `/dev/kvm`** (`kvm-ok`), cria swap de 4 GB se faltar, cria o usuário `stack`, clona o DevStack (branch `stable/2026.2`; para outra: `DEVSTACK_BRANCH=stable/2026.1 ./01-preparar-host.sh`) e gera `/opt/stack/devstack/local.conf`.

Se faltar `/dev/kvm`: veja "Solução de problemas -> KVM".

### 6.3 Rodar o `stack.sh`

☁️

```bash
sudo apt-get install -y tmux
sudo -u stack -i
tmux new -s stack
cd devstack && ./stack.sh
```

- Duração: **40 a 70 minutos**. Se a conexão SSH cair: `sudo -u stack -i` e `tmux attach -t stack`.
- Acompanhe em outra sessão: `tail -f /opt/stack/logs/stack.sh.log`.
- Sucesso: o final mostra `Horizon is now available at http://192.168.50.20/dashboard`, `Keystone is serving at http://192.168.50.20/identity/`, as contas `admin` e `demo`, e `stack.sh completed in NNNN seconds.`

**Checkpoint 6** (☁️, como `stack`)

```bash
source ~/devstack/openrc admin admin
openstack service list                  # keystone, nova, neutron, glance, placement...
openstack compute service list          # nova-compute e nova-scheduler "up"
openstack network list                  # public (e shared/private do DevStack)
openstack hypervisor list               # 1 hypervisor
ip -br a show br-ex                     # 172.24.4.1/24
sudo iptables -t nat -S POSTROUTING | grep 172.24.4.0   # MASQUERADE
free -h
```

🪟 Navegador: `http://192.168.50.20/dashboard` (login `admin`, domínio `Default`, a senha escolhida).

> Dica: com o DevStack funcionando, desligue a VM (`sudo shutdown -h now`) e crie um checkpoint offline: `Checkpoint-VM -Name vnes-cloud -SnapshotName stack-ok`. Se algo der errado depois, `Restore-VMCheckpoint` poupa uma hora. Depois de restaurar/reiniciar, use os comandos de "Depois de reiniciar a vnes-cloud".

## 7. HTTPS no Horizon com o certificado da CA (REQ11, REQ12)

🖥️ Envie o certificado e a chave da CA para a `vnes-cloud`:

```bash
cd ~/infra/ca
sudo ./03-distribuir.sh ubuntu@192.168.50.20
```

(Pede a senha do `ubuntu` na `vnes-cloud` algumas vezes; instala em `/etc/ssl/vnes/vnes.fullchain.crt` e `vnes.key`. Com `sudo` o `scp` usa o `known_hosts` do root: responda `yes` na primeira vez.)

☁️ Habilite o HTTPS (como `ubuntu`, não como `stack` nem root):

```bash
cd ~/infra/devstack
./02-horizon-https.sh
```

Cria o site Apache `zz-vnes-cloud-ssl` (443 e redirecionamento do nome `cloud.vnes.com.br` na 80), ajusta o `local_settings.py` do Horizon (cookies `secure`, `CSRF_TRUSTED_ORIGINS`) e testa com `curl`. As APIs continuam em `http://192.168.50.20/identity`, `/compute` etc.

**Checkpoint 7**

🪟

```powershell
cd "E:\Codes\Trabalho Cloud\vnes-crud\infra\hyperv"
.\03-configurar-cliente.ps1 -CaminhoCA "$HOME\vnes-root-ca.crt"    # o teste da porta 443 agora passa
curl.exe -I https://cloud.vnes.com.br/dashboard         # HTTP/1.1 302, sem erro de certificado
curl.exe -I http://cloud.vnes.com.br/dashboard          # 301 -> https://cloud.vnes.com.br/dashboard
```

Navegador: `https://cloud.vnes.com.br/dashboard` abre com **cadeado válido** (clique no cadeado -> certificado: emitido por `VNES Root CA`, SAN `*.vnes.com.br`). Login como `admin` / domínio `Default`.
Com cookies `secure`, login em `http://192.168.50.20/dashboard` deixa de funcionar; use sempre o nome HTTPS.

## 8. Preparação de admin: imagem, flavor, projeto e usuário

Escolha **um** caminho. Para o vídeo, o Horizon mostra o conceito; o script é mais rápido e sem erro.

### 8.1 Via script (recomendado para preparar)

☁️ O script roda como `stack` e precisa ser legível por ele (a home do `ubuntu` não é):

```bash
sudo install -o stack -g stack -m 755 ~/infra/devstack/03-preparar-admin.sh /opt/stack/
sudo -u stack -i
./03-preparar-admin.sh          # pede a senha do usuário vnes-devops (ou VNES_DEVOPS_PASSWORD=...)
```

Baixa a imagem `noble-server-cloudimg-amd64.img` (~600 MB), cria a imagem pública `ubuntu-24.04`, o flavor `vnes.small` (1 vCPU, 1024 MB, 10 GB), o projeto `vnes` e o usuário `vnes-devops` com papel `member`. É idempotente.

### 8.2 Via Horizon (caminho gráfico, como `admin`)

Entre em `https://cloud.vnes.com.br/dashboard` como `admin` (domínio `Default`).

1. **Imagem:** baixe `https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img` no Windows. **Admin -> Compute -> Images -> Create Image**: Name `ubuntu-24.04`; File = o `.img`; Format `QCOW2 - QEMU Emulator`; Visibility *Public*; **Create Image**. Aguarde o status `Active`.
2. **Flavor:** **Admin -> Compute -> Flavors -> Create Flavor**: Name `vnes.small`, VCPUs `1`, RAM (MB) `1024`, Root Disk (GB) `10`, Ephemeral/Swap `0`; **Create Flavor**.
3. **Projeto:** **Identity -> Projects -> Create Project**: Name `vnes`, Enabled; **Create Project**.
4. **Usuário:** **Identity -> Users -> Create User**: User Name `vnes-devops`, senha, Primary Project `vnes`, Role `member`; **Create User**.

**Checkpoint 8**

☁️ (como `stack`, depois de `source ~/devstack/openrc admin admin`)

```bash
openstack image list                          # ubuntu-24.04 active
openstack flavor show vnes.small -c vcpus -c ram -c disk
openstack role assignment list --project vnes --user vnes-devops --names
```

🪟 Faça logout e entre no Horizon como `vnes-devops` (domínio `Default`); o projeto ativo deve ser `vnes`.

## 9. Checklist final do Passo III

- [ ] **REQ10:** `Resolve-DnsName cloud.vnes.com.br` (sem `-Server`) retorna `192.168.50.20`; qualquer `*.vnes.com.br` resolve.
- [ ] **REQ11:** CA raiz importada no Windows; cadeado válido em `https://cloud.vnes.com.br/dashboard`; SAN `*.vnes.com.br`.
- [ ] **REQ12:** Horizon acessível em `https://cloud.vnes.com.br/dashboard`; `openstack compute service list` com serviços `up`.
- [ ] Imagem `ubuntu-24.04`, flavor `vnes.small`, projeto `vnes` e usuário `vnes-devops` existem.

## Solução de problemas

### Console da instância em branco no Horizon

O console noVNC é servido em `http://192.168.50.20:6080` (HTTP). Dentro do Horizon em HTTPS, o navegador bloqueia o iframe por conteúdo misto. Clique em **"Click here to show only console"** para abrir o console em uma aba própria, ou use `openstack console log show <instância>` para ver o boot.

### KVM / virtualização aninhada

Sintoma: `/dev/kvm` não existe ou `kvm-ok` diz "KVM acceleration can NOT be used".
🪟 Desligue a VM e rode:

```powershell
Stop-VM vnes-cloud
Set-VMProcessor -VMName vnes-cloud -ExposeVirtualizationExtensions $true
Set-VMNetworkAdapter -VMName vnes-cloud -MacAddressSpoofing On
Get-VMMemory vnes-cloud | Select DynamicMemoryEnabled     # deve ser False
Start-VM vnes-cloud
```

☁️ `sudo kvm-ok` e `ls -l /dev/kvm`. Se ainda falhar, confirme que a virtualização está ligada na BIOS e que não há outro hipervisor em conflito.

### `stack.sh` falhou

1. Leia o erro: `less +G /opt/stack/logs/stack.sh.log` (ou a saída do tmux). Causas comuns: sem internet/DNS (ver abaixo), falta de RAM (`free -h`; feche programas no Windows), falha de download (rode de novo).
2. Recomeçar sem reinstalar o SO (☁️ como `stack`):

```bash
cd ~/devstack
./unstack.sh
./clean.sh
./stack.sh
```

3. Se continuar quebrando, tente outra branch: `DEVSTACK_BRANCH=stable/2026.1` no passo 6.2 (apague `/opt/stack/devstack` antes). Último recurso: `Restore-VMCheckpoint` do checkpoint feito antes do `stack.sh`.

### Depois de reiniciar a `vnes-cloud` (não rode `stack.sh` de novo)

☁️ Comandos de `infra/devstack/README.md`:

```bash
sudo systemctl restart 'devstack@*'
sudo systemctl status 'devstack@*' --no-pager | head -n 40

sudo systemctl restart ovn-controller ovn-northd ovs-vswitchd ovsdb-server 2>/dev/null || true
sudo ip addr show br-ex
sudo ip addr add 172.24.4.1/24 dev br-ex 2>/dev/null || true
sudo ip link set br-ex up
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -C POSTROUTING -o eth0 -s 172.24.4.0/24 -j MASQUERADE 2>/dev/null \
  || sudo iptables -t nat -A POSTROUTING -o eth0 -s 172.24.4.0/24 -j MASQUERADE
sudo systemctl restart apache2
```

Para tornar permanente: `sudo apt install iptables-persistent`, `sudo netfilter-persistent save` e `net.ipv4.ip_forward=1` em `/etc/sysctl.d/99-vnes.conf`. Sintoma típico de NAT perdido: instâncias sem internet/DNS (o cloud-init da `vnes-web` não instala pacotes).
Não use `unstack.sh`/`clean.sh` se não precisar refazer tudo.
Ordem de ligar após desligar tudo: `vnes-infra` primeiro, depois `vnes-cloud`.

### DNS não resolve

| Onde | Teste | Se falhar |
|---|---|---|
| 🖥️ | `dig @127.0.0.1 cloud.vnes.com.br` | `sudo named-checkconf`; `sudo systemctl status named`; `sudo journalctl -u named -n 30` |
| 🪟 | `Resolve-DnsName cloud.vnes.com.br -Server 192.168.50.10` | `Test-NetConnection 192.168.50.10 -Port 53`; VM ligada? IP correto (`ip -br a`)? |
| 🪟 | `Resolve-DnsName cloud.vnes.com.br` (sem `-Server`) | `Get-DnsClientNrptRule`; `Clear-DnsClientCache`; reexecute `03-configurar-cliente.ps1` |
| ☁️ | `dig cloud.vnes.com.br` | `resolvectl status`; confira `nameservers` no netplan |

Registro antigo em cache (TTL 300 s): `Clear-DnsClientCache`. Para editar a zona use sempre `atualizar-registro.sh` (incrementa o serial e recarrega).

### Aviso de certificado

- Confirme a CA no Windows: `Get-ChildItem Cert:\LocalMachine\Root | Where Subject -like '*VNES*'`. Se faltar, rode o `03-configurar-cliente.ps1` como Administrador.
- Acesse pelo **nome** (`https://cloud.vnes.com.br`), não pelo IP (o certificado cobre `*.vnes.com.br` e `vnes.com.br`).
- Firefox: `security.enterprise_roots.enabled = true` em `about:config`.
- Feche e reabra o navegador depois de importar a CA.
- Veja o certificado entregue (🖥️): `echo | openssl s_client -connect cloud.vnes.com.br:443 -servername cloud.vnes.com.br 2>/dev/null | openssl x509 -noout -subject -issuer -dates`.

### Horizon não abre / erro de login

☁️ `sudo apachectl configtest`, `sudo tail -n 40 /var/log/apache2/horizon_ssl_error.log`, `sudo systemctl restart apache2`. O login só funciona pelo HTTPS (cookies `secure`).
