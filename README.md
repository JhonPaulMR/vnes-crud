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
