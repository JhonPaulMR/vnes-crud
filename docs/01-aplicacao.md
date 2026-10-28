# Passo I - Aplicação web (REQ01 a REQ08)

Objetivo: ter a aplicação personalizada, testada localmente e **publicada no GitHub** (a nuvem clona dali).

## O que foi personalizado

| Item | Onde | REQ |
|---|---|---|
| Nome da empresa **VNES** (loja de cartuchos virtuais NES) | `includes/header.php` (título e `alt` do logo), `README.md` | REQ01 |
| Logo em todas as páginas | `assets/images/logo.png`, incluído por `includes/header.php` (todas as páginas fazem `include "includes/header.php"`) | REQ02 |
| Domínio `vnes.com.br` no rodapé | `includes/footer.php` | REQ03 |
| Redesign visual | `assets/css/style.css` (versão `?v=2.0` no header para furar cache) | REQ06 |
| Tabela única `cartridges` | `init.sql` | REQ05 |

Correções feitas na aplicação:

- `.htaccess`: `RewriteBase /` (a app roda na raiz do domínio, não em subpasta).
- `edit.php`: XSS corrigido (`htmlspecialchars($message)` e `(int)$id` no `action` do formulário).
- `.env` removido do Git; criado `.env.example` e `.gitignore` (`.env`, `uploads/`, `*.swp`). Credenciais nunca vão para o repositório.
- Removido `includes/.functions.php.swp` (arquivo de swap do editor).

## Requisitos de aplicação (o que falar/mostrar)

- **REQ04 (só CRUD):** Create (`create.php`), Read (`index.php`), Update (`edit.php`), Delete (`delete.php`). A tela **Play** (`play.php`, emulador) é uma forma diferente de **READ** do mesmo cartucho: em vez de só listar, "lê" a ROM e a executa. Essa funcionalidade foi **aprovada pelo professor em disciplinas anteriores** como variação de READ. Cite isso no vídeo em uma frase.
- **REQ05 (uma tabela, 3 a 10 colunas):** `cartridges` com 5 colunas: `id`, `name`, `cover_image`, `rom_path`, `created_at`.
- **REQ06 (PHP + HTML/CSS):** páginas `.php`, estilos em `assets/css/style.css`. `assets/js/` tem JS auxiliar (`main.js`) e o integrador do emulador (`emulator.js`).
- **REQ07 (sem frameworks):** não há Laravel, Bootstrap, jQuery etc. O **JSNES** (`node_modules/jsnes`) é uma *biblioteca de emulação* de NES usada **apenas na tela Play**; não é framework de aplicação nem de interface. Os arquivos necessários estão versionados, então o servidor não precisa de `npm`.
- **REQ08 (MySQL/MariaDB pela rede):** `config/database.php` lê `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` de variáveis de ambiente. Localmente `DB_HOST=db` (container MySQL); na nuvem `DB_HOST=db.vnes.com.br` (MariaDB na instância `vnes-db`, acessada pela rede privada).

## Testar localmente (docker-compose)

Requer Docker Desktop. 🪟 Windows, na raiz do projeto:

```powershell
cd "E:\Codes\Trabalho Cloud\vnes-crud"
Copy-Item .env.example .env
# edite .env se quiser (APP_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD)
docker-compose up -d --build
```

Abra `http://localhost:8080` (ou o `APP_PORT` do `.env`). Confira:

- [ ] Logo no topo e `vnes.com.br` no rodapé em todas as páginas.
- [ ] Criar cartucho (capa + ROM `.nes`), listar, editar, jogar (Play), excluir.

Para encerrar e limpar:

```powershell
docker-compose down        # mantém dados
docker-compose down -v     # apaga banco e uploads locais
```

> Pare o Docker Desktop (e `wsl --shutdown`) antes de subir as VMs do Hyper-V: ele consome RAM que a `vnes-cloud` precisa (ver `docs/README.md`).

## Publicar no GitHub (obrigatório antes do deploy)

O cloud-init da `vnes-web` executa `git clone --branch cloud-openstack https://github.com/JhonPaulMR/vnes-crud.git /var/www/vnes` **sem credenciais**. Portanto:

1. O repositório precisa ser **público**.
2. A branch `cloud-openstack` precisa estar atualizada no GitHub, com a app, `infra/` e `docs/`.

🪟 Windows:

```powershell
git status                      # confira: .env NÃO deve aparecer como arquivo a ser enviado
git add .
git commit -m "Aplicação VNES e infraestrutura OpenStack"
git push origin cloud-openstack
```

Valide abrindo `https://github.com/JhonPaulMR/vnes-crud/tree/cloud-openstack` no navegador (logo, `includes/footer.php` com `vnes.com.br`, pasta `infra/`).

> Sempre que alterar a aplicação depois, faça `git push origin cloud-openstack` **antes** de criar a `vnes-web` (o clone acontece só no primeiro boot).

## Checkpoint do Passo I

- [ ] App local funcionando com logo, rodapé e CRUD completo.
- [ ] `git push origin cloud-openstack` feito e branch visível no GitHub.
- [ ] `.env` fora do repositório.
