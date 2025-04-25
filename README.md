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

* Servidor Web com suporte a PHP (Ex: Apache, Nginx)
* PHP
* Banco de Dados MySQL
* Biblioteca JavaScript [JSNES](https://github.com/bfirsh/jsnes) (o arquivo `jsnes.min.js` deve estar em `node_modules/jsnes/dist/`)

## Instruções de Configuração

1.  **Clone o Repositório:**
    ```bash
    git clone https://github.com/JhonPaulMR/vnes-crud
    ```

2.  **Configure o Banco de Dados:**
    * Crie um banco de dados MySQL (`cartridges`).
    * Importe a estrutura da tabela. Você precisará de uma tabela chamada `cartridges` com colunas como:
        * `id` (INT, Primary Key, Auto Increment)
        * `name` (VARCHAR)
        * `cover_image` (VARCHAR - caminho para a imagem)
        * `rom_path` (VARCHAR - caminho para a ROM)
        * `created_at` (TIMESTAMP, default CURRENT_TIMESTAMP)
    * Edite o arquivo `config/database.php` com as suas credenciais do banco de dados (host, usuário, senha, nome do banco). **Certifique-se de preencher o `DB_HOST`**.

3.  **Crie os Diretórios de Upload:**
    * Crie os diretórios `uploads/covers/` e `uploads/roms/` na raiz do projeto.
    * Certifique-se de que o servidor web tenha permissão de escrita nesses diretórios.
    ```bash
    chmod -R 755 crud
    chown www-data:www-data crud
    ```

4.  **Dependências (JSNES):**
    * Certifique-se que o arquivo `jsnes.min.js` esteja acessível no caminho `node_modules/jsnes/dist/jsnes.min.js` conforme esperado pelo `play.php`.

5.  **Acesse a Aplicação:**
    * Aponte seu navegador para o diretório onde você configurou o projeto no seu servidor web (ex: `http://localhost/crud/`).

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
