# Roteiro do vídeo – Projeto de Nuvem VNES

Duração alvo: **6:15 a 6:30** (limite 5 a 7 min, REQ21). Sem acelerar; esperas são **cortadas** na edição.
Ritmo de fala de referência: ~145 palavras/min. As falas abaixo somam ~830 palavras, o que dá ~5:45 de fala + ~40 s de telas sem fala.

Formato: grave a tela sem áudio seguindo as cenas, depois narre por cima e coloque o rosto (webcam) num canto (REQ19, REQ20). A ordem segue os requisitos, como o professor sugeriu.

---

## 1. Auditoria dos requisitos

| Req | O que pede | Como o projeto cumpre | Onde aparece no vídeo |
|---|---|---|---|
| REQ01 | Nome fictício | **VNES**, loja de cartuchos virtuais de NES | Cena 1 |
| REQ02 | Logo em todas as páginas | `includes/header.php` é incluído em `index`, `create`, `edit` e `play` | Cena 1 e 9 |
| REQ03 | Domínio | `vnes.com.br` (www, cloud, db, ns1, ca) | Cena 1 e 4 |
| REQ04 | Só CRUD | Create, Read, Update, Delete; o **Play** é a forma de Read (já aprovado pelo professor) | Cena 1 e 9 |
| REQ05 | 1 tabela, 3 a 10 campos | `cartridges` com 5 campos | Cena 1 |
| REQ06 | PHP + HTML/CSS | PHP 8, HTML e CSS puros; JS só no emulador | Cena 1 |
| REQ07 | Sem framework | Nenhum; JSNES é só a biblioteca do emulador | Cena 1 |
| REQ08 | Banco via rede | MariaDB na VM `vnes-db`, acessado pela rede por `db.vnes.com.br` | Cena 1 e 10 |
| REQ09 | Topologia | **Ideal**: cliente Windows + `vnes-infra` (DNS e CA) + `vnes-cloud` (OpenStack) com VMs web e db | Cena 2 |
| REQ10 | DNS `*.vnes.com.br` | Bind9 na `vnes-infra`, zona `vnes.com.br` com curinga | Cena 3 |
| REQ11 | CA + certificados | CA própria "VNES Root CA" e certificado curinga `*.vnes.com.br` | Cena 3 |
| REQ12 | Nuvem com FQDN (+ cert opcional) | DevStack em `https://cloud.vnes.com.br` com o certificado da CA | Cena 4 |
| REQ13 | Projeto na nuvem | Projeto `vnes` + usuário `vnes-devops` (papel member) | Cena 5 |
| REQ14 | VM web | `vnes-web` (Apache + PHP), floating IP | Cena 6 e 7 |
| REQ15 | VM banco | `vnes-db` (MariaDB), só IP privado | Cena 6 e 10 |
| REQ16 | Deploy + HTTP/HTTPS | cloud-init clona a app do GitHub; HTTP redireciona para HTTPS | Cena 7 e 9 |
| REQ17 | Cenário DevOps × Cliente | Cenas 2 a 7 (DevOps) e 8 a 10 (Cliente) | Todo o vídeo |
| REQ18 | Gravação nítida | Checklist da seção 3 | Preparação |
| REQ19 | Rosto | Webcam no canto durante todo o vídeo | Edição |
| REQ20 | Voz nítida | Microfone de headset, ambiente sem eco | Edição |
| REQ21 | 5 a 7 min, sem acelerar | ~6:20, só cortes | Edição |
| REQ22 | YouTube não listado ou Drive + acesso ao professor | Compartilhar com `hermanopereira@professores.utfpr.edu.br` | Após gravar |
| REQ23 | Link válido | Testar em aba anônima, sem encurtador, sem pasta | Após gravar |
| REQ24 | Postar de verdade no Moodle | Clicar em "Enviar" (não deixar rascunho) | Após gravar |

**Critérios**
- **CRIT01 (todos os requisitos):** a tabela acima vira o roteiro; cada cena cita o REQ que cobre.
- **CRIT02 (originalidade, funciona):** tudo roda na sua máquina, com a aplicação sendo usada ao vivo.
- **CRIT03 (competência):** explicar o *porquê* em uma frase: banco sem IP público, DNS antes da web, curinga para todos os subdomínios.

**Pontos de atenção**
- O REQ04 é o único ponto discutível (o Play). Fale da justificativa logo na Cena 1, com uma frase.
- O REQ01 pede criatividade "para evitar nomes repetidos". VNES é seu nome desde a disciplina anterior, então não há problema.

---

## 2. Preparação antes de gravar

1. **Ligar a nuvem:** feche VS Code, Chrome, WhatsApp e Docker e rode `infra\hyperv\06-ligar-nuvem.ps1` como administrador.
2. **Decidir as instâncias (recomendado: criar ao vivo).** Antes de gravar, apague `vnes-web`, `vnes-db` e a floating IP (seção 5 de `05-demonstracao.md`). Mantenha a rede, o roteador, os grupos de segurança e a keypair. Renderize de novo os cloud-init (`render.sh`) e deixe `db.yaml` e `web.yaml` num local que você **não** vai mostrar na tela.
   - Se preferir não recriar, pule a Cena 6 e mostre as instâncias já rodando no Horizon. O vídeo fica mais curto (~5:30) e com menos impacto.
   - Ao recriar as instâncias, elas ganham chaves SSH novas e a floating IP pode mudar. Antes das Cenas 7 e 10, limpe as chaves antigas no PowerShell: `ssh-keygen -R www.vnes.com.br; ssh-keygen -R db.vnes.com.br`. Também troque o `~/.ssh/vnes-key.pem` se a keypair for recriada.
3. **Abrir as janelas na ordem:** Hyper-V Manager, `docs/02-topologia.md` renderizado, terminal 1 (SSH `vnes-infra`), terminal 2 (PowerShell local) e o navegador com duas abas (Horizon e site).
4. **Separar os arquivos do cliente:** capas (PNG ou JPG feitas por você) e as ROMs `croom.nes` e `lj65.nes` (de `node_modules\jsnes\roms\`).
5. **Fazer um ensaio completo com cronômetro.**

---

## 3. Checklist de gravação (REQ18)

- Resolução 1920×1080, notificações desligadas (modo Foco), área de trabalho limpa.
- Terminal com fonte tamanho 20 ou maior.
- Navegador com zoom de 125% a 150%.
- VS Code com `editor.fontSize` 20 ou maior.
- Nada de senhas ou chaves na tela. **Não abra** `credenciais-vms.txt`, `db.yaml` nem `web.yaml`.
- Webcam e microfone testados (grave 10 segundos e ouça).

---

## 4. Roteiro cena a cena

> As falas estão no seu jeito de falar: leia como base e não decore palavra por palavra. Onde está **[CORTE]**, pare de narrar e corte a espera na edição.

### Cena 0 – Abertura (0:00 – 0:15)
**Tela:** site `https://www.vnes.com.br` aberto, com o logo.

> "Sejam bem-vindos aí ao vídeo de apresentação do trabalho de Computação em Nuvem. Aqui eu vou tá mostrando como eu montei uma nuvem privada com OpenStack na minha máquina e hospedei aí a aplicação da VNES, seguindo aí cada requisito do enunciado."

### Cena 1 – Aplicação, REQ01 a REQ08 (0:15 – 1:05)
**Tela:** VS Code com `init.sql`, depois `includes/header.php`, depois `config/database.php`.

> "Começando pelos primeiros requisitos aí. O nome da empresa é a VNES, uma loja de cartuchos virtuais de NES, é a mesma aplicação que eu já usei nas disciplinas anteriores, só que repaginei o visual dela, tudo só no CSS. O domínio escolhido foi o vnes.com.br. O logotipo tá aqui no header, que é incluído em todas as páginas, tanto na listagem quanto na criação, edição e na tela de jogar.
> Sobre o banco, aqui no init.sql tem uma única tabela, a cartridges, com cinco campos: o ID, o nome do cartucho, o caminho da imagem de capa, o caminho da ROM e a data de criação.
> A aplicação é só um CRUD: criar, ler, editar e deletar o cartucho. O Play é só uma forma diferente de ler o cartucho, como eu já tinha comentado nas disciplinas passadas. Tô usando PHP, HTML e CSS puro, sem nenhum framework, o JavaScript ali é só a biblioteca do emulador. E o banco é MariaDB, acessado pela rede, que aqui no database.php pega o host e a senha por variável de ambiente."

### Cena 2 – Topologia, REQ09 (1:05 – 1:45)
**Tela:** diagrama de `docs/02-topologia.md`, depois o Hyper-V Manager com as duas VMs rodando.

> "Agora falando aí sobre a topologia. Eu usei a topologia ideal: aqui a minha máquina Windows é o cliente, de onde eu acesso o site e faço SSH. No Hyper-V eu tenho duas máquinas virtuais: a vnes-infra, que roda o DNS e a autoridade certificadora, e a vnes-cloud, que roda o OpenStack pelo DevStack. E dentro do OpenStack eu tenho as duas VMs da aplicação: a vnes-web, com Apache e PHP, e a vnes-db, com o MariaDB. As VMs do Hyper-V eu instalei de forma automática com autoinstall do Ubuntu, que já sobe com IP fixo e chave SSH."

### Cena 3 – DNS e CA, REQ10 e REQ11 (1:45 – 2:35)
**Tela:** terminal SSH na `vnes-infra`.

```bash
cat /etc/bind/zones/db.vnes.com.br
dig +short cloud.vnes.com.br @127.0.0.1
sudo openssl x509 -in /opt/vnes-ca/certs/wildcard.vnes.com.br.crt -noout -subject -issuer -ext subjectAltName
```

> "Aqui na vnes-infra tá rodando o bind9, que é o servidor DNS da zona vnes.com.br. Aqui ó, tem o cloud apontando pra nuvem, o www e o domínio raiz apontando pro IP público da VM web, o db pro IP privado do banco e um curinga, então qualquer subdomínio do vnes.com.br resolve.
> Sobre a autoridade certificadora, eu criei a VNES Root CA com o OpenSSL, e com ela assinei um certificado curinga, que vale pra asterisco ponto vnes.com.br e pro vnes.com.br. Então um único certificado serve tanto pra nuvem quanto pro site. E no Windows eu importei a CA raiz como confiável, por isso o navegador mostra o cadeado sem aviso."

### Cena 4 – Nuvem com FQDN, REQ12 (2:35 – 2:55)
**Tela:** navegador em `https://cloud.vnes.com.br/dashboard`. Clique no cadeado e mostre o emissor "VNES Root CA". Faça login como `vnes-devops`.

> "Aqui a nuvem privada já tá de pé, acessível pelo FQDN cloud.vnes.com.br, com HTTPS e o certificado da nossa CA, olha aqui o emissor. Vou entrar com o usuário vnes-devops, que é o DevOps da empresa."

### Cena 5 – Projeto, permissões e rede, REQ13 (2:55 – 3:25)
**Tela:** Horizon: Identity → Projects (mostre o `vnes`), depois Network → Network Topology, depois Security Groups → regras do `sg-db`.

> "Como admin eu criei o projeto vnes e o usuário vnes-devops com o papel de membro só nesse projeto. Dentro do projeto tem a rede privada vnes-net, 10.10.10.0/24, com o roteador saindo pra rede pública. E os grupos de segurança: o sg-web libera SSH, HTTP e HTTPS, e o sg-db só libera a porta 3306 pra quem tá no grupo da web, então o banco não fica exposto pra ninguém de fora."

### Cena 6 – Criar as VMs, REQ14 e REQ15 (3:25 – 4:20)
**Tela:** Horizon, Launch Instance para `vnes-db` (flavor `vnes.small`, imagem `ubuntu-24.04`, rede `vnes-net`, `sg-db`, keypair, Configuration com o `db.yaml`). Pegue o IP privado e rode no terminal da `vnes-infra`:

```bash
sudo ~/infra/dns/atualizar-registro.sh db <IP-privado>
```

Depois, Launch Instance para `vnes-web` (com `sg-web` e `web.yaml`), Associate Floating IP, e no terminal:

```bash
sudo ~/infra/dns/atualizar-registro.sh www <floating-IP>
sudo ~/infra/dns/atualizar-registro.sh @ <floating-IP>
```

> "Agora a parte do deploy. Primeiro eu subo a VM do banco, a vnes-db, com o flavor vnes.small, a imagem do Ubuntu, a rede privada e o grupo do banco. Aqui na configuração eu passo o script do cloud-init, que instala o MariaDB e já cria a tabela. [CORTE]
> Ela pegou esse IP privado, então eu atualizo o DNS pro db.vnes.com.br apontar pra ele, isso antes de subir a web, porque a web acessa o banco pelo nome.
> Agora a vnes-web, mesma coisa, só que com o grupo da web e o cloud-init da web. [CORTE] Associo um IP flutuante e aponto o www e o domínio raiz pra ele."

### Cena 7 – Deploy automático, REQ16 (4:20 – 4:45)
**Tela:** PowerShell no Windows.

```powershell
ssh vnes-web "tail -3 /var/log/vnes-cloud-init.log"
```

> "[CORTE na espera do cloud-init] Aqui no log da web dá pra ver: o cloud-init instalou o Apache e o PHP, clonou a aplicação direto do meu GitHub, configurou o HTTPS com o certificado curinga e testou a conexão com o banco pelo db.vnes.com.br. VNES-WEB PRONTO."

### Cena 8 – Troca de papel, REQ17 (4:45 – 4:50)
> "Agora saindo do papel do DevOps e indo pro papel do cliente usando a aplicação."

### Cena 9 – Cliente usando o CRUD, REQ16, REQ02 e REQ04 (4:50 – 5:55)
**Tela:** navegador. Digite `http://www.vnes.com.br` e mostre que vira `https` com cadeado. Depois:
- **Create:** "Croom" com capa e `croom.nes`, e "LJ65" com `lj65.nes`;
- **Read:** a listagem;
- **Play:** "Croom" por uns 10 segundos;
- **Edit:** renomear "LJ65" para "LJ65 Tetris";
- **Delete:** apagar "LJ65 Tetris".

> "O cliente digita www.vnes.com.br, mesmo em HTTP ele é redirecionado pro HTTPS, com o cadeado válido. Vou criar um cartucho novo, coloco o nome, a capa e a ROM, pá, criado. Vou criar mais um. Aqui na listagem já aparecem os dois, isso é o read, e aqui no play eu consigo jogar o cartucho direto no navegador. Agora editando o nome desse aqui, atualizou. E se eu quiser apagar, apaga normalmente. Repara que o logo da VNES aparece em todas as telas."

### Cena 10 – Dados no banco, REQ08 e REQ15 (5:55 – 6:10)
**Tela:** PowerShell.

```powershell
ssh vnes-db "sudo mysql -e 'SELECT id,name FROM vnes_db.cartridges;'"
```

> "E pra fechar o fluxo, aqui no banco, que só dá pra acessar passando pela VM web, tá o cartucho que o cliente acabou de cadastrar."

> `vnes-web` e `vnes-db` são entradas do seu `~/.ssh/config`. O `vnes-db` usa `ProxyJump vnes-web`, porque o `ssh -J` do Windows não repassa a chave para o salto.

### Cena 11 – Encerramento (6:10 – 6:25)
**Tela:** a tabela de requisitos (seção 1) ou o site.

> "Creio que foram demonstrados aí todos os requisitos: a aplicação personalizada, a topologia, o DNS, a autoridade certificadora, a nuvem privada com o OpenStack, o projeto, as VMs da web e do banco e a aplicação funcionando com HTTPS. Espero que tenha ficado claro aí como ficou a nuvem da VNES. Até mais."

---

## 5. Se o tempo estourar

| Passou de | O que cortar primeiro |
|---|---|
| 7:00 | Cena 5 em 15 s (só a topologia de rede) e Cena 10 inteira |
| 6:45 | Na Cena 9, crie só um cartucho |
| Abaixo de 5:00 | Na Cena 3, mostre também o `Resolve-DnsName www.vnes.com.br` do Windows |

---

## 6. Depois de gravar (REQ22 a REQ24)

- Publique no YouTube como **não listado**, ou no Drive com acesso para `hermanopereira@professores.utfpr.edu.br`.
- Teste o link numa aba anônima. Nada de link encurtado, link de pasta ou link sem permissão.
- No Moodle, cole o link e clique em **Enviar tarefa**. Confira se o status ficou "Enviado para avaliação", e não "Rascunho".
