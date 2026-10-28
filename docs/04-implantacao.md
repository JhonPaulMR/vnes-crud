# Passo IV - Implantação da aplicação na nuvem (REQ13 a REQ16)

Convenções: 🪟 Windows | 🖥️ `vnes-infra` | ☁️ `vnes-cloud` | 🌐 `vnes-web` | 🗄️ `vnes-db`.
Caminho principal: **Horizon** (interface gráfica) como `vnes-devops` no projeto `vnes`. O plano B por CLI está na seção 10.

Tempo estimado: 40 a 60 min (a maior parte é espera do cloud-init).

## Pré-requisitos

- Passo III concluído (DNS, CA, Horizon HTTPS, imagem `ubuntu-24.04`, flavor `vnes.small`, projeto `vnes`, usuário `vnes-devops`).
- Branch `cloud-openstack` publicada no GitHub (ver `docs/01-aplicacao.md`). O `vnes-web` clona de lá no primeiro boot.
- `vnes-infra` e `vnes-cloud` ligadas (e, se a `vnes-cloud` foi reiniciada, os comandos de recuperação do `docs/03-ambiente.md` aplicados).

Valores usados: rede `vnes-net` / sub-rede `vnes-subnet` `10.10.10.0/24` com DNS `192.168.50.10`; roteador `vnes-router`; grupos `sg-web` e `sg-db`; keypair `vnes-key`; imagem `ubuntu-24.04`; flavor `vnes.small` (fonte: `infra/VARIAVEIS.md`).

## 1. Entrar no Horizon (REQ13)

🪟 `https://cloud.vnes.com.br/dashboard` -> Domain `Default`, User `vnes-devops`, senha definida no passo III. Confirme no topo que o projeto ativo é **vnes**.

## 2. Rede, sub-rede e roteador

**Project -> Network -> Networks -> Create Network**

1. Aba *Network*: Network Name `vnes-net`; mantenha *Create Subnet* marcado.
2. Aba *Subnet*: Subnet Name `vnes-subnet`; Network Address `10.10.10.0/24`; IP Version IPv4; Gateway IP em branco (assume `10.10.10.1`).
3. Aba *Subnet Details*: **DNS Name Servers** `192.168.50.10`; *Enable DHCP* marcado.
4. **Create**.

**Project -> Network -> Routers -> Create Router**

1. Router Name `vnes-router`; **External Network** `public`; **Create Router**.
2. Clique em `vnes-router` -> aba **Interfaces** -> **Add Interface** -> Subnet `vnes-net: 10.10.10.0/24 (vnes-subnet)` -> **Submit**.

Conferência: **Project -> Network -> Network Topology** mostra `public` -- `vnes-router` -- `vnes-net`.

## 3. Grupos de segurança

**Project -> Network -> Security Groups -> Create Security Group**

**`sg-web`** (Name `sg-web`, Description `Web VNES`). Em **Manage Rules -> Add Rule** crie 4 regras de entrada (Direction *Ingress*):

| Rule | Port | Remote | CIDR |
|---|---|---|---|
| Custom TCP Rule | 22 | CIDR | `0.0.0.0/0` |
| Custom TCP Rule | 80 | CIDR | `0.0.0.0/0` |
| Custom TCP Rule | 443 | CIDR | `0.0.0.0/0` |
| All ICMP | - | CIDR | `0.0.0.0/0` |

**`sg-db`** (Name `sg-db`, Description `Banco VNES`). Regras de entrada com **Remote = Security Group** e Security Group = **`sg-web`**:

| Rule | Port | Remote |
|---|---|---|
| Custom TCP Rule | 3306 | Security Group `sg-web` |
| Custom TCP Rule | 22 | Security Group `sg-web` |
| All ICMP | - | Security Group `sg-web` |

Resultado: o banco só aceita conexões vindas de instâncias do `sg-web`. Nenhuma regra de entrada vem da internet ou do Windows. (As regras de saída *Egress* padrão permanecem: o banco precisa baixar pacotes.)

## 4. Par de chaves

**Project -> Compute -> Key Pairs -> Create Key Pair**: Name `vnes-key`, Key Type *SSH Key* -> **Create**. O navegador baixa `vnes-key.pem` (única chance de pegar a chave privada).

🪟 Guarde e proteja o arquivo:

```powershell
New-Item -ItemType Directory -Force "$HOME\.ssh" | Out-Null
Move-Item "$HOME\Downloads\vnes-key.pem" "$HOME\.ssh\vnes-key.pem"
icacls "$HOME\.ssh\vnes-key.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

## 5. Renderizar os cloud-init (na `vnes-infra`)

Os modelos `infra/cloud-init/db.yaml.tpl` e `web.yaml.tpl` recebem a senha do banco e (no web) o certificado curinga e a chave. O `render.sh` precisa ler a chave da CA (root), por isso `sudo`.

🖥️

```bash
cd ~/infra/cloud-init
sudo ./render.sh                    # pede a senha do usuário 'vnes' do MariaDB (2x)
sudo chown -R "$USER:$USER" out     # senão o scp (usuário ubuntu) não lê os arquivos
ls -l out/
```

A senha aceita letras, números, `_`, `.` e `-` (mínimo 8 caracteres). Anote-a: é a senha do banco (`DB_PASSWORD`). Alternativa sem prompt: `sudo DB_PASSWORD='MinhaSenha123' ./render.sh`.

Resultado: `out/db.yaml` e `out/web.yaml` (permissão 600). O `web.yaml` contém a **chave privada do certificado e a senha do banco**; o `db.yaml`, a senha do banco. Nunca versione (`out/` está no `.gitignore`) nem mostre no vídeo.

### Levar os arquivos para o Windows

Horizon aceita colar texto ou carregar um arquivo no campo *Customization Script* (limite de 16 KB; o `web.yaml` tem ~8 KB).

🪟

```powershell
New-Item -ItemType Directory -Force "$env:TEMP\vnes" | Out-Null
scp ubuntu@192.168.50.10:infra/cloud-init/out/db.yaml  "$env:TEMP\vnes\db.yaml"
scp ubuntu@192.168.50.10:infra/cloud-init/out/web.yaml "$env:TEMP\vnes\web.yaml"
```

**Apague tudo depois de lançar as instâncias** (seção 7). Se o repositório do Windows tiver `infra/cloud-init/out/`, ele também não vai para o Git, mas mantenha os arquivos fora da pasta do projeto.

## 6. Lançar `vnes-db` PRIMEIRO

**Project -> Compute -> Instances -> Launch Instance**

| Aba | Valor |
|---|---|
| Details | Instance Name `vnes-db`, Count `1` |
| Source | Select Boot Source *Image*; *Create New Volume* **No**; mova `ubuntu-24.04` para *Allocated* |
| Flavor | `vnes.small` |
| Networks | `vnes-net` |
| Security Groups | somente `sg-db` (remova `default` de *Allocated*) |
| Key Pair | `vnes-key` |
| Configuration | **Load Customization Script from a file** -> `%TEMP%\vnes\db.yaml` (ou cole o conteúdo; deve começar com `#cloud-config`) |

**Launch Instance**. Aguarde `Power State: Running` e anote o **IP privado** (`10.10.10.z`) na lista de instâncias (coluna *IP Address*).

O `vnes-db` configura sozinho: instala MariaDB, aceita conexões da rede privada, cria `vnes_db`, o usuário `vnes@10.10.10.%` e a tabela `cartridges` (mesmo schema do `init.sql`). Leva 3 a 6 minutos.

### Atualizar o DNS do `db` ANTES de lançar o `vnes-web`

O app conecta em `db.vnes.com.br`; o nome precisa apontar para o IP real do `vnes-db`.

🖥️

```bash
cd ~/infra/dns
sudo ./atualizar-registro.sh db 10.10.10.z          # troque pelo IP real
```

Saída esperada: serial incrementado, `named-checkzone` OK e `dig +short db.vnes.com.br => 10.10.10.z`.

## 7. Lançar `vnes-web`

Mesma tela (**Launch Instance**), com:

| Aba | Valor |
|---|---|
| Details | Instance Name `vnes-web` |
| Source | `ubuntu-24.04`, *Create New Volume* **No** |
| Flavor | `vnes.small` |
| Networks | `vnes-net` |
| Security Groups | somente `sg-web` |
| Key Pair | `vnes-key` |
| Configuration | arquivo `%TEMP%\vnes\web.yaml` |

Depois do `Launch`, apague os arquivos sensíveis:

🪟

```powershell
Remove-Item "$env:TEMP\vnes\*.yaml" -Force
```

🖥️

```bash
shred -u ~/infra/cloud-init/out/*.yaml
```

### Floating IP e DNS de `www` e `@`

1. **Project -> Compute -> Instances** -> menu `v` do `vnes-web` -> **Associate Floating IP**.
2. Em *IP Address* clique em **+** -> Pool `public` -> **Allocate IP**; confira que a porta é a do `vnes-web` -> **Associate**.
3. Anote a floating IP (`172.24.4.y`).

🖥️

```bash
cd ~/infra/dns
sudo ./atualizar-registro.sh www 172.24.4.y
sudo ./atualizar-registro.sh @   172.24.4.y
```

🪟

```powershell
Clear-DnsClientCache
Resolve-DnsName www.vnes.com.br      # 172.24.4.y
Resolve-DnsName vnes.com.br
Test-NetConnection www.vnes.com.br -Port 443
ping 172.24.4.y
```

## 8. Acompanhar o cloud-init e acessar por SSH

Para não digitar chave e salto sempre, crie o arquivo `~/.ssh/config` no Windows (`notepad $HOME\.ssh\config`) com os IPs reais:

```text
Host vnes-web
    HostName 172.24.4.y
    User ubuntu
    IdentityFile ~/.ssh/vnes-key.pem

Host vnes-db
    HostName 10.10.10.z
    User ubuntu
    IdentityFile ~/.ssh/vnes-key.pem
    ProxyJump vnes-web
```

O `vnes-db` não tem floating IP nem regra `sg-db` para o Windows: só se chega nele **saltando pela `vnes-web`** (`ssh -J`, aqui via `ProxyJump`).

🪟 -> 🌐

```powershell
ssh vnes-web
```

🌐 Dentro do `vnes-web`:

```bash
sudo tail -f /var/log/cloud-init-output.log      # progresso da instalação (Ctrl+C para sair)
cloud-init status --wait                          # espera terminar: status: done
cat /var/log/vnes-cloud-init.log                  # marcadores do projeto
```

Esperado em `/var/log/vnes-cloud-init.log` (`vnes-web`): `VNES-WEB iniciando configuracao` -> `VNES-WEB Apache no ar; aguardando o banco db.vnes.com.br` -> `VNES-WEB banco acessivel (tentativa N)` -> **`VNES-WEB PRONTO`**.
Se aparecer `VNES-WEB AVISO: banco nao respondeu`, confira o DNS do `db` e o `sg-db` (Solução de problemas).

Testes no próprio `vnes-web`:

```bash
getent hosts db.vnes.com.br                       # 10.10.10.z (DNS do Bind)
mysql -h db.vnes.com.br -u vnes -p vnes_db -e 'SHOW TABLES;'     # senha do render.sh; lista cartridges
sudo apache2ctl -S | head                         # vhosts 80 e 443 de vnes.com.br
ls /var/www/vnes                                  # app clonada da branch cloud-openstack
```

🪟 -> 🗄️ (salto pela web)

```powershell
ssh vnes-db
# ou sem o arquivo de config:  ssh -J ubuntu@172.24.4.y ubuntu@10.10.10.z   (adicione -i na chave se não usar o agente)
```

🗄️ Dentro do `vnes-db`:

```bash
sudo tail -n 20 /var/log/vnes-cloud-init.log      # ... VNES-DB PRONTO
sudo tail -f /var/log/cloud-init-output.log
sudo mysql -e "SHOW DATABASES; USE vnes_db; SHOW TABLES; SELECT id, name FROM cartridges;"
ss -ltn | grep 3306                               # 0.0.0.0:3306
```

> Ao refazer o ambiente, o host key do mesmo IP muda: `ssh-keygen -R 172.24.4.y` e `ssh-keygen -R 10.10.10.z`.

## 9. Testar HTTP, HTTPS e o CRUD (REQ16)

🪟

```powershell
curl.exe -I http://www.vnes.com.br       # 301 Moved Permanently, Location: https://www.vnes.com.br/
curl.exe -I https://www.vnes.com.br      # 200 OK, sem erro de certificado
curl.exe -I https://vnes.com.br
```

Navegador (Edge/Chrome): `http://www.vnes.com.br` redireciona para `https://www.vnes.com.br` com **cadeado válido** (certificado `*.vnes.com.br`, emitido por `VNES Root CA`). Teste o CRUD:

1. **Create:** *Add New Cartridge* -> nome, capa (imagem) e ROM `.nes` -> enviar.
2. **Read:** o cartucho aparece na lista com a capa.
3. **Play:** abre o emulador e roda a ROM.
4. **Update:** *Edit* -> mude o nome -> salvar.
5. **Delete:** *Delete* -> confirmar.

Dados sugeridos: ver `docs/05-demonstracao.md`. Prova de que o banco é o da `vnes-db`: 🗄️ `sudo mysql -e 'SELECT id,name,created_at FROM vnes_db.cartridges;'` mostra o registro criado pelo navegador.

## 10. Plano B - tudo via CLI

Use se o Horizon der problema ou para recriar rápido. O script `infra/openstack/criar-projeto-vnes.sh` cria rede, roteador, grupos, keypair, as duas instâncias e a floating IP. É idempotente.

Pré-requisitos (☁️ `vnes-cloud`, usuário `ubuntu`):

```bash
sudo apt-get install -y python3-openstackclient
mkdir -p ~/infra/cloud-init/out
```

🖥️ Gere e envie os cloud-init:

```bash
cd ~/infra/cloud-init && sudo ./render.sh && sudo chown -R "$USER:$USER" out
scp out/db.yaml out/web.yaml ubuntu@192.168.50.20:~/infra/cloud-init/out/
```

☁️ Rode (pede a senha do `vnes-devops`; a chave `~/.ssh/vnes-key` é gerada se não existir, se a keypair `vnes-key` ainda não existir no OpenStack):

```bash
cd ~/infra/openstack
chmod +x criar-projeto-vnes.sh
./criar-projeto-vnes.sh
```

O script **pausa** depois de criar o `vnes-db` e mostra o IP: em outro terminal 🖥️ execute `sudo ~/infra/dns/atualizar-registro.sh db <IP>` e volte a ☁️ para pressionar ENTER (crie o `vnes-web` só depois). No final ele imprime as IPs; atualize `www` e `@` com a floating IP como na seção 7. Variáveis opcionais: `DB_USERDATA`, `WEB_USERDATA`, `KEY_FILE`.

Observação: se criou a keypair pelo script, a chave privada está em `~/.ssh/vnes-key` na `vnes-cloud`; copie para o Windows (`scp ubuntu@192.168.50.20:.ssh/vnes-key "$HOME\.ssh\vnes-key.pem"`) para usar o `~/.ssh/config` acima. Use `openstack console log show vnes-web | tail` para ver o boot sem SSH.

## Solução de problemas

| Sintoma | Verificar |
|---|---|
| Instância em `ERROR` | **Instances -> nome -> Overview** (campo *Fault*): flavor/imagem inexistente? RAM insuficiente na `vnes-cloud` (`free -h`)? |
| Instância sem internet/DNS (cloud-init sem instalar pacotes) | NAT da `vnes-cloud` (`sudo iptables -t nat -S POSTROUTING`), `ip_forward`; ver recuperação em `docs/03-ambiente.md`. DNS da sub-rede deve ser `192.168.50.10` |
| `VNES-WEB AVISO: banco nao respondeu` | `getent hosts db.vnes.com.br` retorna o IP real? (DNS atualizado?) `sg-db` com 3306 vindo de `sg-web`? `vnes-db` concluiu (`VNES-DB PRONTO`)? Depois de corrigir o DNS, o app volta sem reiniciar (TTL 300 s) |
| `Connection failed` na página | `DB_PASSWORD`: reexecute o render com a mesma senha usada no db; confira `SetEnv` em `/etc/apache2/sites-available/vnes.conf` (🌐 `sudo grep SetEnv`); lembre que mudar o DNS não corrige senha diferente |
| `git clone falhou` | Repositório público? Branch `cloud-openstack` enviada? 🌐 `sudo tail /var/log/cloud-init-output.log` |
| Não alcança `172.24.4.y` do Windows | `Get-NetRoute 172.24.4.0/24`; floating IP associada? `sg-web` com ICMP/443; ☁️ `ip -br a show br-ex`; recuperação pós-reboot |
| SSH `Permission denied (publickey)` | usuário é `ubuntu`; chave `vnes-key.pem` correta e com permissão restrita (`icacls`) |
| Upload de ROM falha | limite 16 MB no `vnes.ini`; permissões de `/var/www/vnes/uploads` (🌐 `ls -ld`) |

## Checklist de verificação (REQ13 a REQ16)

- [ ] **REQ13:** Horizon logado como `vnes-devops`, projeto `vnes`; rede, roteador, grupos e keypair existem (Network Topology).
- [ ] **REQ14:** instância `vnes-web` ativa (Apache + PHP), floating IP associada, `www.vnes.com.br` resolve para ela.
- [ ] **REQ15:** instância `vnes-db` ativa (MariaDB), **sem** floating IP, `sg-db` restrito a `sg-web`, `db.vnes.com.br` -> `10.10.10.z`.
- [ ] **REQ16:** app clonada em `/var/www/vnes`, conectando em `db.vnes.com.br`; HTTP redireciona para HTTPS com certificado válido; CRUD completo funcionando e registro visível no banco.
