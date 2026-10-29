# VNES - Guias do Trabalho 1 (Projeto de Nuvem para Aplicação Web)

Aplicação CRUD da **VNES** (loja de cartuchos virtuais NES) hospedada em uma **nuvem privada OpenStack (DevStack)** rodando em VMs Hyper-V no próprio notebook, com DNS (Bind) e CA próprios para `*.vnes.com.br`.
Valores (IPs, nomes, caminhos): `infra/VARIAVEIS.md` (fonte única). Scripts: pasta `infra/`.

## Índice

| Guia | Passo | Conteúdo |
|---|---|---|
| [`01-aplicacao.md`](01-aplicacao.md) | I | Aplicação personalizada, teste local, `git push` |
| [`02-topologia.md`](02-topologia.md) | II | Topologia "Ideal", diagrama, IPs, fluxos |
| [`03-ambiente.md`](03-ambiente.md) | III | Hyper-V, Ubuntu, Bind, CA, cliente Windows, DevStack, Horizon HTTPS, preparação de admin |
| [`04-implantacao.md`](04-implantacao.md) | IV | Projeto no Horizon, `vnes-db`, `vnes-web`, DNS, floating IP, testes, plano B por CLI |
| [`05-demonstracao.md`](05-demonstracao.md) | V | Roteiro de 5 a 7 min, preparação da gravação, dados de teste, reset |

Legenda nos comandos: 🪟 Windows | 🖥️ `vnes-infra` | ☁️ `vnes-cloud` | 🌐 `vnes-web` | 🗄️ `vnes-db`.

## Ordem recomendada e tempo estimado

| # | Etapa | Guia | Tempo |
|---|---|---|---|
| 1 | Testar a app local e dar `git push origin cloud-openstack` | 01 | 30 min |
| 2 | Ler a topologia | 02 | 15 min |
| 3 | Rede Hyper-V + criar VMs | 03 §1 | 15 min |
| 4 | Instalar Ubuntu + netplan na `vnes-infra` | 03 §2 | 25 min |
| 5 | Bind (DNS) | 03 §3 | 10 min |
| 6 | CA + certificado curinga | 03 §4 | 10 min |
| 7 | Configurar o cliente Windows | 03 §5 | 10 min |
| 8 | Instalar Ubuntu + netplan na `vnes-cloud` | 03 §6.1 | 25 min |
| 9 | Preparar host + `stack.sh` | 03 §6.2-6.3 | 15 min + 40 a 70 min de espera |
| 10 | Horizon HTTPS | 03 §7 | 10 min |
| 11 | Imagem, flavor, projeto e usuário | 03 §8 | 15 min |
| 12 | Rede, SGs, chave no Horizon; render; lançar `vnes-db` e `vnes-web`; DNS; testes | 04 | 40 a 60 min |
| 13 | Ensaios (2x) | 05 §4 | 1 h |
| 14 | Gravação | 05 | 30 min |

Total: **cerca de 6 a 8 horas** (boa parte é espera). Faça o item 9 em um horário em que possa deixar o notebook ocioso.

## Checklist de requisitos

| REQ | Requisito | Status | Onde é atendido | O que mostrar no vídeo |
|---|---|---|---|---|
| REQ01 | Nome da empresa (VNES) | Pronto (código) | `includes/header.php`, `README.md`; `01-aplicacao.md` | Título/cabeçalho "VNES" |
| REQ02 | Logo em todas as páginas | Pronto (código) | `assets/images/logo.png` via `includes/header.php` | Logo no topo em 2 ou 3 páginas |
| REQ03 | Domínio `vnes.com.br` | Pronto + executar DNS | `includes/footer.php`; `infra/dns/*`; `03` §3 | Rodapé; `Resolve-DnsName`; URL `www.vnes.com.br` |
| REQ04 | Somente CRUD | Pronto (código) | `create.php`, `index.php`, `edit.php`, `delete.php`; `play.php` = forma de READ aprovada pelo professor (cursos anteriores); `01` | Os 4 do CRUD; citar a justificativa do Play |
| REQ05 | 1 tabela, 3 a 10 colunas | Pronto | `init.sql` (`cartridges`, 5 colunas) | `init.sql` ou `SHOW TABLES` / `DESCRIBE cartridges` |
| REQ06 | PHP + HTML/CSS | Pronto | `*.php`, `assets/css/style.css`; `01` | Arquivos no editor |
| REQ07 | Sem frameworks | Pronto | JSNES é biblioteca de emulação só do Play; `01` | Frase curta citando o JSNES |
| REQ08 | MySQL/MariaDB pela rede | Executar (`04`) | `config/database.php`; `infra/cloud-init/db.yaml.tpl`; `04` §6 | `getenv` no código; `db.vnes.com.br` -> `vnes-db` |
| REQ09 | Topologia | Pronto (doc) + executar | `02-topologia.md`; `infra/hyperv/*`, `infra/netplan/*`; `03` §1-2 | Diagrama e Hyper-V Manager |
| REQ10 | DNS `*.vnes.com.br` | Executar (`03` §3, §5) | `infra/dns/*`; regra NRPT em `infra/hyperv/03-configurar-cliente.ps1` | `Resolve-DnsName`/`dig`, zona |
| REQ11 | CA + certificados válidos | Executar (`03` §4, §5, §7) | `infra/ca/*` | Emissor `VNES Root CA`, SAN `*.vnes.com.br`, cadeado |
| REQ12 | Nuvem privada em `cloud.vnes.com.br` com certificado | Executar (`03` §6-7) | `infra/devstack/*` | `https://cloud.vnes.com.br/dashboard` com cadeado |
| REQ13 | Projeto na nuvem | Executar (`03` §8, `04` §1-4) | `infra/devstack/03-preparar-admin.sh`; Horizon | Projeto `vnes`, rede, roteador, SGs |
| REQ14 | VM web | Executar (`04` §7) | `infra/cloud-init/web.yaml.tpl` | Instância `vnes-web` + floating IP |
| REQ15 | VM de banco | Executar (`04` §6) | `infra/cloud-init/db.yaml.tpl` | Instância `vnes-db` sem floating IP; `sg-db` |
| REQ16 | Deploy, integração com DB, HTTP/HTTPS | Executar (`04` §7-9) | `web.yaml.tpl`; `infra/dns/atualizar-registro.sh` | HTTP->HTTPS e CRUD no navegador |
| REQ17 | Cenário DevOps + cliente | Roteiro pronto (`05` §1) | `05-demonstracao.md` | Duas personas no vídeo |
| REQ18 | Gravação clara | Checklist pronto (`05` §2) | `05-demonstracao.md` | Fontes grandes, zoom, 1080p |

Critérios de avaliação: **CRIT01** (todos os requisitos) -> tabela acima; **CRIT02** (originalidade e funcionamento) -> ambiente próprio e CRUD funcionando em ponta a ponta; **CRIT03** (compreensão) -> explique em uma frase por que cada peça existe (ver "Por que a topologia Ideal" no `02`).

## Orçamento de hardware (host com 15 GB de RAM)

| Consumidor | RAM |
|---|---|
| `vnes-cloud` (DevStack, estática) | 6 GB (+ 4 GB swap no Linux) |
| `vnes-infra` (Bind + CA) | 1 GB |
| Windows 11 + navegador + gravador (sobra) | ~3 GB |

O DevStack ocupa 5 a 6 GB; cada instância `vnes.small` usa 1 GB. A sobra do Windows é apertada, então:

- Antes de ligar as VMs: **feche Docker Desktop** (sair pelo ícone da bandeja) e rode `wsl --shutdown`.
- Feche Teams, Slack, IDEs pesadas, abas de navegador em excesso e jogos.
- Durante a gravação use só: Windows Terminal, navegador e (se necessário) VS Code. Se o gravador pesar, reduza para 30 fps.
- Memória das VMs é **estática** (obrigatório para virtualização aninhada); não altere para dinâmica.
- Disco: ~130 GB de VHDX dinâmico em `E:\HyperV\VNES` (padrão) + 10 GB para vídeo.
- Notebook ligado na tomada, plano "Alto desempenho". Evite hibernar com as VMs rodando.
- Ordem de ligar: `vnes-infra`, depois `vnes-cloud`. Ordem de desligar: `sudo shutdown -h now` na `vnes-cloud`, depois na `vnes-infra`.

## Avisos importantes

- A branch `cloud-openstack` **precisa estar no GitHub** (público) antes de criar a `vnes-web`.
- `infra/cloud-init/out/*.yaml` contêm **chave privada e senha do banco**: nunca versionar, nunca mostrar no vídeo, apagar depois de usar.
- Passos VI e VII do enunciado (edição, publicação e entrega do vídeo) estão fora destes guias; veja o ponto final de `05-demonstracao.md`.
