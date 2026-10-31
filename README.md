# vnes-crud


# VNes CRUD - Gerenciador de Cartuchos NES

Está é uma aplicação web de um crud simples para gerenciar e jogar ROMs de jogos do Nintendo Entertainment System (NES) diretamente no seu navegador. Ele permite fazer upload, visualizar, editar, excluir e jogar seus cartuchos digitais.

## Funcionalidades

* **Listar Cartuchos:** Exibe todos os cartuchos NES adicionados com suas capas.
* **Adicionar Novo Cartucho:** Faz upload de um arquivo ROM `.nes` e uma imagem de capa (`.jpg`, `.jpeg`, `.png`, `.gif`) para adicionar um novo jogo à coleção.
* **Editar Cartucho:** Atualiza o nome, a imagem da capa ou o arquivo ROM de um cartucho existente.
* **Excluir Cartucho:** Remove um cartucho da coleção e apaga os arquivos associados do servidor.
* **Jogar:** Emula e joga o jogo NES selecionado diretamente no navegador usando a biblioteca JSNES.

## Requisitos

* Ter Instalado Docker e Docker-Compose

## Instruções de Configuração

1.  **Clone o Repositório:**
    ```bash
    git clone https://github.com/JhonPaulMR/vnes-crud
    ```

2.  **Execute o docker-compose:**
    ```bash
    docker-compose up -d --build
    ```

3.  **Acesse a Aplicação:**
    * Aponte seu navegador para o diretório onde você configurou o projeto no seu servidor web (ex: `http://<IP Da máquina/VM>:8080`).
    * Ou se preferir configure o arquivo hosts de sua máquina para acessar a aplicação com um domínio personalizado>
    * ex: 192.0.0.0 crud.com

## Como Usar

1.  Acesse a página inicial (`index.php`) para ver a lista de cartuchos.
2.  Clique em "Add New Cartridge" para ir ao formulário de adição (`create.php`).
3.  Preencha o nome, selecione a imagem da capa e o arquivo ROM `.nes` e envie o formulário.
4.  Na lista de cartuchos, você terá as opções:
    * **Play:** Abre o emulador (`play.php`) com o jogo selecionado.
    * **Edit:** Abre o formulário de edição (`edit.php`) para o cartucho selecionado.
    * **Delete:** Remove o cartucho após confirmação.

## Controles do Emulador (Padrão JSNES)

* **Setas Direcionais:** D-Pad
* **Z:** Botão B
* **X:** Botão A
* **Enter:** Start
* **Shift:** Select

## Implantação na nuvem privada (OpenStack)

A branch `cloud-openstack` contém a implantação da aplicação em uma nuvem privada OpenStack (domínio `vnes.com.br`). A documentação está em `docs/` e os arquivos de infraestrutura (provisionamento e configuração) estão em `infra/`.

Para desenvolvimento local, continue usando o docker-compose descrito acima. As variáveis de ambiente ficam em `.env`: copie `.env.example` para `.env` e ajuste os valores (o `.env` não é versionado):

```bash
cp .env.example .env
docker-compose up -d --build
```

### Reproduzir a nuvem do zero

Os valores (IPs, nomes, caminhos) estão em [`infra/VARIAVEIS.md`](infra/VARIAVEIS.md). O passo a passo detalhado está em [`docs/`](docs/README.md). Abaixo, a ordem que funcionou na prática.

**Pré-requisitos**
- Windows 11 Pro com Hyper-V e virtualização ativada na BIOS (AMD ou Intel; a VM da nuvem usa virtualização aninhada).
- 15 GB de RAM ou mais. A `vnes-cloud` usa **6 GB fixos** + 4 GB de swap, a `vnes-infra` usa 1 GB. Feche IDEs, navegadores pesados e Docker antes de ligar.
- ~130 GB livres em disco.
- ISO do Ubuntu Server 24.04 (`ubuntu-24.04.x-live-server-amd64.iso`).
- Uma chave SSH só para o projeto: `ssh-keygen -t ed25519 -f $HOME\.ssh\vnes-admin`.
- Repositório público no GitHub com a branch `cloud-openstack` (a VM web clona daqui).

**1. Windows (PowerShell como administrador, em `infra\hyperv`)**

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\01-criar-rede.ps1                                        # switch VNES-NET 192.168.50.0/24 + NAT
.\02-criar-vms.ps1 -IsoPath "E:\HyperV\ISO\ubuntu-24.04.5-live-server-amd64.iso"
$hash = & "C:\Program Files\Git\usr\bin\openssl.exe" passwd -6 'SuaSenha'
.\04-instalar-ubuntu-auto.ps1 -VmName vnes-infra -Hostname ns1   -Ip 192.168.50.10 -ChavePublica "$HOME\.ssh\vnes-admin.pub" -SenhaHash $hash
.\04-instalar-ubuntu-auto.ps1 -VmName vnes-cloud -Hostname cloud -Ip 192.168.50.20 -ChavePublica "$HOME\.ssh\vnes-admin.pub" -SenhaHash $hash
Start-VM vnes-infra, vnes-cloud
```

O `04` instala o Ubuntu sem interação (autoinstall): IP fixo, usuário `ubuntu`, chave SSH e sudo sem senha. Ele sobe a RAM para 2 GB só durante a instalação, porque o instalador trava com 1 GB.

**2. `vnes-infra` (DNS e CA)**: copie `infra/` para a VM (`scp -r infra ubuntu@192.168.50.10:~`) e rode:

```bash
cd ~/infra && sudo sed -i 's/\r$//' $(find . -name '*.sh') && chmod +x */*.sh
sudo cp netplan/vnes-infra.yaml /etc/netplan/50-vnes.yaml && sudo chmod 600 /etc/netplan/50-vnes.yaml
sudo ./dns/instalar-bind.sh
sudo netplan apply
sudo ./ca/01-criar-ca.sh && sudo ./ca/02-emitir-curinga.sh
```

**3. `vnes-cloud` (DevStack)**: copie `infra/` também e rode:

```bash
cd ~/infra && sudo cp netplan/vnes-cloud.yaml /etc/netplan/50-vnes.yaml && sudo netplan apply
./devstack/01-preparar-host.sh                             # usuário stack, swap, clone do DevStack
sudo -u stack -i bash -c 'cd ~/devstack && ./stack.sh'     # 30 a 90 min
```

Na `vnes-infra`, mande o certificado para a nuvem: `sudo ./ca/03-distribuir.sh ubuntu@192.168.50.20`. Depois, de volta na `vnes-cloud`:

```bash
./devstack/02-horizon-https.sh                             # Horizon em https://cloud.vnes.com.br
sudo -u stack -i bash /caminho/para/devstack/03-preparar-admin.sh   # imagem, flavor, projeto vnes, usuário vnes-devops
sudo ./devstack/04-persistir-nat.sh && sudo ./devstack/05-autostart.sh   # sobreviver a reboot
```

**4. Cliente Windows** (como administrador): `.\03-configurar-cliente.ps1 -CaminhoCA vnes-root-ca.crt` adiciona a rota `172.24.4.0/24 → 192.168.50.20`, a regra NRPT de `*.vnes.com.br` e a CA raiz como confiável. Antes, copie a CA com `scp ubuntu@192.168.50.10:/opt/vnes-ca/certs/vnes-root-ca.crt .`.

**5. Aplicação**: na `vnes-infra`, gere os cloud-init com `sudo DB_PASSWORD=... ~/infra/cloud-init/render.sh`. No Horizon, como `vnes-devops`, crie:
1. a `vnes-db` (imagem `ubuntu-24.04`, flavor `vnes.small`, **Criar Novo Volume: Não**, rede `vnes-net`, grupo `sg-db`, script `db.yaml`);
2. aponte o DNS: `sudo ~/infra/dns/atualizar-registro.sh db <IP privado>`;
3. a `vnes-web` (grupo `sg-web`, script `web.yaml`), associe um IP flutuante e rode `atualizar-registro.sh www <IP>` e `@ <IP>`.

A rede, o roteador e os grupos de segurança podem ser criados pelo Horizon ou pelo script `infra/openstack/criar-projeto-vnes.sh`, que também sobe as duas instâncias. Em 3 a 5 minutos o log `/var/log/vnes-cloud-init.log` da web mostra `VNES-WEB PRONTO`, e o site abre em `https://www.vnes.com.br`.

**Ligar e desligar depois**: `.\06-ligar-nuvem.ps1` e `.\05-desligar-nuvem.ps1` (como administrador).

**Armadilhas conhecidas**
- O instalador do Ubuntu 24.04 trava com 1 GB de RAM: use o `04-instalar-ubuntu-auto.ps1`.
- Com o Cinder desligado, instância criada com "Criar Novo Volume: Sim" dá erro.
- O DNS do `db` precisa apontar para a `vnes-db` antes da web terminar o boot (ela tenta por 10 minutos).
- O `ssh -J` do Windows não repassa a chave ao salto: use `ProxyJump` no `~/.ssh/config`.
- Instâncias recriadas mudam a chave de host: rode `ssh-keygen -R www.vnes.com.br` antes de conectar.

### Desmontar tudo

```powershell
# PowerShell como administrador
Stop-VM vnes-cloud, vnes-infra -TurnOff -Force
Get-VMSnapshot -VMName vnes-cloud, vnes-infra | Remove-VMSnapshot
Remove-VM vnes-cloud, vnes-infra -Force
Remove-Item -Recurse -Force E:\HyperV\VNES                # discos das VMs
Remove-NetNat VNES-NAT -Confirm:$false
Remove-VMSwitch VNES-NET -Force
Remove-NetRoute -DestinationPrefix 172.24.4.0/24 -Confirm:$false
Get-DnsClientNrptRule | ? Namespace -eq '.vnes.com.br' | Remove-DnsClientNrptRule -Force
Get-ChildItem Cert:\LocalMachine\Root | ? Subject -like '*VNES Root CA*' | Remove-Item
```
