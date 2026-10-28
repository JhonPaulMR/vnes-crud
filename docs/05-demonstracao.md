# Passo V - Demonstração e gravação (REQ17, REQ18)

Convenções: 🪟 Windows | 🖥️ `vnes-infra` | ☁️ `vnes-cloud` | 🌐 `vnes-web` | 🗄️ `vnes-db`.
Vídeo final: **5 a 7 minutos**, sem acelerar (não use *speed up*). **Cortes** na edição são permitidos: grave o ambiente em tempo real e corte as esperas. Alvo: **6:30**.

Este documento cobre só o roteiro e a preparação da gravação. Edição, publicação e entrega do vídeo (passos VI e VII do enunciado) ficam no fim.

## 1. Roteiro cronometrado (REQ17)

Cenário (REQ17): uma pessoa **DevOps** prepara o ambiente da VNES na nuvem privada e, em seguida, um **Cliente** usa a aplicação. Fale curto: uma frase por requisito, citando o REQ.

| Tempo | Persona | Tela | O que mostrar / fazer | O que dizer (resumo) | REQ |
|---|---|---|---|---|---|
| 0:00-0:40 | DevOps | VS Code (repo) + navegador local ou página já aberta | `includes/header.php` (logo), `includes/footer.php` (vnes.com.br), `init.sql` (tabela `cartridges`, 5 colunas), `config/database.php` (`getenv`), pasta sem frameworks | "VNES, loja de cartuchos virtuais NES, domínio vnes.com.br. PHP + HTML/CSS, sem framework (JSNES é só a biblioteca do emulador). Uma tabela com 5 colunas, banco MariaDB via rede. CRUD; o Play é uma forma de READ aprovada pelo professor." | 01-08 |
| 0:40-1:20 | DevOps | Diagrama do `docs/02-topologia.md` (renderizado) + Hyper-V Manager | Diagrama Mermaid; Hyper-V com `vnes-infra` e `vnes-cloud` rodando (RAM/CPU) | "Topologia Ideal: Windows cliente, vnes-infra com DNS e CA, vnes-cloud com DevStack; dentro dela vnes-web e vnes-db. 15 GB de RAM no host." | 09 |
| 1:20-2:20 | DevOps | 🪟 PowerShell + 🖥️ SSH `vnes-infra` | `Resolve-DnsName cloud.vnes.com.br`; 🖥️ `cat /etc/bind/zones/db.vnes.com.br`; 🖥️ `sudo openssl x509 -in /opt/vnes-ca/certs/wildcard.vnes.com.br.crt -noout -subject -issuer -ext subjectAltName`; mostrar certmgr/`Get-ChildItem Cert:\LocalMachine\Root \| ? Subject -like '*VNES*'` | "Bind responde `*.vnes.com.br`. A CA própria assinou o certificado curinga; o Windows confia na CA raiz." | 10, 11 |
| 2:20-2:50 | DevOps | Navegador: `https://cloud.vnes.com.br/dashboard` | Cadeado válido (clicar e mostrar emissor), login `vnes-devops` / `Default` | "Nuvem privada OpenStack no FQDN cloud.vnes.com.br com certificado válido." | 12 |
| 2:50-3:20 | DevOps | Horizon: Network Topology, Security Groups | Rede `vnes-net`, roteador, `sg-web` e `sg-db` (regra com *remote = sg-web*), keypair (já criados) | "Projeto vnes com rede privada 10.10.10.0/24, roteador e grupos de segurança; o banco só aceita a web." | 13 |
| 3:20-4:20 | DevOps | Horizon + 🖥️ | **Ao vivo:** lançar `vnes-db` (aba Configuration com `db.yaml`) -> pegar IP privado -> 🖥️ `sudo ./atualizar-registro.sh db <IP>`. Lançar `vnes-web` (`web.yaml`). Associar floating IP -> 🖥️ `sudo ./atualizar-registro.sh www <FIP>` e `@`. | "O banco sobe primeiro, sem IP público; atualizo o DNS; sobe o web, associo a floating IP e aponto www e a raiz." | 14, 15, 16 |
| 4:20-4:50 | DevOps | 🪟 `ssh vnes-web` | **CORTE** da espera do cloud-init (vídeo continua após a conclusão). Mostrar `cat /var/log/vnes-cloud-init.log` com `VNES-DB PRONTO` / `VNES-WEB PRONTO`; `mysql -h db.vnes.com.br ...` | "O cloud-init instalou Apache/PHP, clonou a app do GitHub e testou o banco por db.vnes.com.br." | 16 |
| 4:50-5:00 | - | Transição | "Agora, o cliente." | - | 17 |
| 5:00-6:20 | Cliente | Navegador `http://www.vnes.com.br` | Redireciona para HTTPS (cadeado). **Create** (cartucho 1 com capa e ROM), lista (**Read**), **Play** por ~10 s, **Edit** (renomear), **Delete** (cartucho 2) | "Cliente acessa www.vnes.com.br, que vai para HTTPS; cria, lista, joga, edita e exclui." | 16, 04 |
| 6:20-6:40 | DevOps | 🗄️ via `ssh vnes-db` (salto) | `sudo mysql -e 'SELECT id,name FROM vnes_db.cartridges;'` mostrando o dado do cliente | "Os dados estão no MariaDB da vnes-db, que só é acessível pela web." | 15 |
| 6:40-6:50 | - | Slide/README | Fechamento com checklist REQ | - | - |

Dicas:

- Se estourar 7 min, corte antes: 0:00-0:40 (mostre só `init.sql` e o logo) e 2:50-3:20 (Network Topology em 10 s).
- Narrar enquanto o cursor mostra: ninguém lê a tela em 20 s; destaque o que importa (cursor ou zoom na edição).
- Ensaie o roteiro com cronômetro (seção 4).

### O que deixar pronto antes (não fazer ao vivo)

- Passo III inteiro (Hyper-V, DNS, CA, DevStack, HTTPS, imagem/flavor/projeto/usuário).
- Rede `vnes-net`, roteador, `sg-web`, `sg-db`, keypair `vnes-key` (mostrar em 30 s).
- `db.yaml` e `web.yaml` já renderizados e salvos em `%TEMP%\vnes\` (ver `docs/04-implantacao.md`, seção 5). **Nunca mostre o conteúdo na tela** (chave privada e senha). Apague-os depois.
- Arquivos de teste (ROMs e capas) prontos em uma pasta (seção 3).
- `~/.ssh/config` com `vnes-web` e `vnes-db`, mas **só crie as entradas com os IPs reais após o lançamento** (ou edite antes do corte).
- Janelas e abas abertas na ordem do roteiro.

### O que fazer ao vivo

- Lançar `vnes-db` e `vnes-web` no Horizon, atualizar DNS (`atualizar-registro.sh`), floating IP.
- Verificações (`dig`/`Resolve-DnsName`, logs) e o uso do cliente.

### Onde cortar (gravação contínua, edição corta)

| Espera | Duração real | Corte |
|---|---|---|
| `vnes-db` ficar `Active` | 30 a 60 s | corte ou mantenha 5 s |
| Boot + cloud-init do `vnes-db` | 3 a 6 min | cortar; continue quando `VNES-DB PRONTO` aparecer |
| `vnes-web` boot + cloud-init | 4 a 8 min | cortar, mas **deixe visível** o `tail` do log até `VNES-WEB PRONTO` |
| Login do Horizon / carregamentos | alguns s | pode manter |

Não grave "em fast-forward". Se alguma etapa for muito longa, corte e diga "(corte)" na narração ou coloque um cartão de texto "cloud-init concluído".

## 2. Preparar a gravação (REQ18)

Checklist (marque antes de gravar):

**Tela**

- [ ] Resolução **1920x1080**, escala do Windows 100% (ou 125% no máximo).
- [ ] Área de trabalho limpa, papel de parede neutro, barra de tarefas sem ícones pessoais.
- [ ] Notificações desligadas: **Win+N** -> *Não incomodar*, ou **Configurações -> Sistema -> Foco** ativado. Feche chat, e-mail, antivírus pop-ups.
- [ ] Apenas as janelas do roteiro abertas; fechar abas e programas não relacionados.

**Fontes grandes**

- [ ] **Windows Terminal**: *Configurações -> Perfis -> Padrões -> Aparência -> Tamanho da fonte* = **20** (ou `Ctrl + roda do mouse`). Tema de alto contraste, janela maximizada. Aplica a todos os perfis; SSH usa a mesma fonte.
- [ ] **VS Code** (`Ctrl+Shift+P` -> *Open User Settings (JSON)*):

```json
{
  "editor.fontSize": 20,
  "terminal.integrated.fontSize": 20,
  "window.zoomLevel": 1,
  "editor.minimap.enabled": false,
  "breadcrumbs.enabled": false,
  "workbench.statusBar.visible": false
}
```

- [ ] **Navegador**: zoom **125% a 150%** (`Ctrl +`; confira com `Ctrl 0` para voltar a 100%). Faça isso no domínio `vnes.com.br` e no `cloud.vnes.com.br` (o zoom é por site).
- [ ] **Perfil limpo do navegador**: perfil novo (convidado) ou barra de favoritos oculta (`Ctrl+Shift+B`), sem extensões visíveis, sem sincronização, sem abas pessoais. Prefira Edge/Chrome (usam a CA do Windows; Firefox exige `security.enterprise_roots.enabled`).
- [ ] **Terminais**: prompts curtos; `clear` antes de cada bloco; comandos preparados em um arquivo de apoio (fora da tela) para colar.

**Áudio e captura**

- [ ] Microfone testado (gravar 10 s e ouvir); ambiente silencioso.
- [ ] Gravador: OBS Studio (captura de tela inteira, 1920x1080, 30 fps, MP4/MKV) ou Win+Alt+R (Game Bar, captura só uma janela por vez; prefira OBS para trocar entre apps).
- [ ] Cursor visível e de bom tamanho (*Configurações -> Acessibilidade -> Ponteiro do mouse*).
- [ ] Energia do notebook conectada; plano de energia "Alto desempenho" (VMs aninhadas ficam lentas na economia).
- [ ] Disco com 10 GB livres (vídeo + VMs).

**Ambiente**

- [ ] `vnes-infra` e `vnes-cloud` ligadas e estáveis há pelo menos 10 min (RAM: `free -h` na `vnes-cloud` com folga).
- [ ] Docker Desktop e WSL parados, apps pesados fechados.
- [ ] Windows com relógio correto (o certificado tem validade; relógio errado gera aviso).

## 3. Dados de teste do CRUD

Use ROMs de domínio público/homebrew para **evitar problemas de direitos autorais** (não use ROMs comerciais). O JSNES já traz duas no repositório:

| Cartucho | ROM | Origem |
|---|---|---|
| Croom | `node_modules\jsnes\roms\croom\croom.nes` | demo homebrew distribuída com o JSNES (`README.html` na mesma pasta) |
| LJ65 | `node_modules\jsnes\roms\lj65\lj65.nes` | jogo homebrew distribuído com o JSNES (`README.txt` na mesma pasta) |

Leia os `README` das pastas para confirmar a licença/autoria e citar a fonte se quiser.

**Capas:** crie suas próprias imagens (Paint, Canva ou captura de tela do emulador em execução), `.png` ou `.jpg` de ~256x256, p. ex. `capa-croom.png` e `capa-lj65.png`. Tamanho total do upload deve ficar abaixo de 16 MB.

Sequência do cliente no vídeo:

| Ação | Dados |
|---|---|
| Create 1 | Nome `Croom`, capa `capa-croom.png`, ROM `croom.nes` |
| Create 2 | Nome `LJ65`, capa `capa-lj65.png`, ROM `lj65.nes` |
| Read | listagem com as duas capas |
| Play | `Croom` (teclas: setas, Z, X, Enter, Shift) |
| Update | `LJ65` -> `LJ65 (Homebrew)` |
| Delete | excluir `LJ65 (Homebrew)` (a banca vê o Delete) |

Deixe os arquivos em uma pasta curta (ex.: `C:\vnes-demo\`) para o seletor de arquivos abrir rápido. Se o Play abrir sem som/imagem, clique na área do emulador para focar o teclado.

## 4. Ensaio completo (dry-run)

Faça **duas vezes** antes da gravação final, com cronômetro:

- [ ] Reset do ambiente (seção 5) para o estado "antes do Passo IV".
- [ ] Rodar o roteiro (seção 1) do início ao fim, sem cortar, anotando tempos reais de cada espera.
- [ ] Total com os cortes planejados fica entre **5:00 e 7:00**; senão, reduzir.
- [ ] Todos os comandos funcionaram na primeira tentativa (anote os que falharam e o erro).
- [ ] Texto legível a 1080p: assista um trecho no player em tela cheia; se tiver de esforçar a vista, aumente fontes.
- [ ] Nenhuma senha, chave, `db.yaml`/`web.yaml` ou dado pessoal apareceu na tela (inclusive histórico do terminal: `clear` e `history -c`).
- [ ] Voz clara, sem dizer "hum"; consegue explicar cada REQ em uma frase.
- [ ] Roteiro cobre REQ01 a REQ18 (use a tabela de `docs/README.md`).
- [ ] Notificações não apareceram durante o ensaio.

## 5. Reset do ambiente (regravar do zero)

Objetivo: voltar ao estado "Passo III pronto; rede/SG/keypair podem permanecer". DNS, CA, DevStack e o projeto ficam.

### 5.1 Remover instâncias e floating IP (mínimo para regravar)

Horizon (`vnes-devops`): **Project -> Compute -> Instances** -> selecione `vnes-web` e `vnes-db` -> **Delete Instances**. **Project -> Network -> Floating IPs** -> **Release Floating IP**.

Ou ☁️ por CLI:

```bash
source ~/infra/openstack/vnes-devops-openrc.sh
openstack server delete vnes-web vnes-db
openstack floating ip list
openstack floating ip delete <FIP>        # ou: openstack floating ip delete $(openstack floating ip list -f value -c ID)
```

DNS de volta aos valores de exemplo (🖥️):

```bash
cd ~/infra/dns
sudo ./atualizar-registro.sh www 172.24.4.100
sudo ./atualizar-registro.sh @   172.24.4.100
sudo ./atualizar-registro.sh db  10.10.10.100
```

Limpeza no Windows:

```powershell
Clear-DnsClientCache
ssh-keygen -R <floating-ip>               # host key antigo (e o IP privado do db)
ssh-keygen -R <ip-privado-do-db>
Remove-Item "$env:TEMP\vnes\*" -Force -ErrorAction SilentlyContinue
```

Regenerar os cloud-init (se apagou): `docs/04-implantacao.md`, seção 5.

### 5.2 Reset completo do projeto (rede, grupos, chave)

☁️ como `vnes-devops` (ordem importa):

```bash
source ~/infra/openstack/vnes-devops-openrc.sh
openstack server delete vnes-web vnes-db 2>/dev/null
openstack floating ip delete $(openstack floating ip list -f value -c ID) 2>/dev/null
openstack router remove subnet vnes-router vnes-subnet
openstack router unset --external-gateway vnes-router
openstack router delete vnes-router
openstack network delete vnes-net            # remove também a sub-rede
openstack security group delete sg-db sg-web  # sg-db antes: referencia sg-web
openstack keypair delete vnes-key
```

Se quiser refazer também o projeto/usuário: como `admin` (☁️ `source ~/devstack/openrc admin admin`): `openstack user delete vnes-devops --domain Default`, `openstack project delete vnes --domain Default`, depois rode o `03-preparar-admin.sh` de novo (`docs/03-ambiente.md`, seção 8). A imagem e o flavor podem ficar.

### 5.3 Acelerar re-gravações

Faça um checkpoint de `vnes-cloud` (desligada) e de `vnes-infra` com o ambiente no estado "Passo III pronto":

```powershell
Stop-VM vnes-cloud; Stop-VM vnes-infra
Checkpoint-VM -Name vnes-infra -SnapshotName passo3-ok
Checkpoint-VM -Name vnes-cloud -SnapshotName passo3-ok
Start-VM vnes-infra; Start-VM vnes-cloud
```

Para voltar: desligue as VMs, `Restore-VMCheckpoint -Name vnes-cloud -SnapshotName passo3-ok` (idem `vnes-infra`) e ligue (infra primeiro). Depois do boot, se as instâncias ou o NAT falharem, rode os comandos de "Depois de reiniciar a vnes-cloud" do `docs/03-ambiente.md`.

## Próximos passos (fora deste guia)

Passos VI e VII do enunciado (edição do vídeo, publicação e entrega): consulte o enunciado do Trabalho 1. Cuidados mínimos: duração 5 a 7 min, sem acelerar, e o vídeo precisa mostrar claramente cada requisito.
