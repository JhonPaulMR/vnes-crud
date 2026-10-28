#cloud-config
# =====================================================================
# cloud-init da instancia vnes-web (Apache + PHP) - Ubuntu 24.04
# Os marcadores entre sublinhados duplos sao substituidos por render.sh.
# =====================================================================
hostname: vnes-web
fqdn: www.vnes.com.br
manage_etc_hosts: true

package_update: true
packages:
  - apache2
  - php
  - libapache2-mod-php
  - php-mysql
  - git
  - mariadb-client

write_files:
  # Certificado curinga (cadeia completa) e chave privada da CA VNES
  - path: /etc/ssl/vnes/vnes.fullchain.crt
    permissions: '0644'
    owner: root:root
    content: |
      __CERT_FULLCHAIN__

  - path: /etc/ssl/vnes/vnes.key
    permissions: '0600'
    owner: root:root
    content: |
      __CERT_KEY__

  # Virtual hosts (gravados apos a instalacao do apache2: defer)
  - path: /etc/apache2/sites-available/vnes.conf
    permissions: '0600'
    owner: root:root
    defer: true
    content: |
      <VirtualHost *:80>
          ServerName www.vnes.com.br
          ServerAlias vnes.com.br
          RewriteEngine On
          RewriteRule ^/?(.*)$ https://www.vnes.com.br/$1 [R=301,L]
      </VirtualHost>

      <VirtualHost *:443>
          ServerName www.vnes.com.br
          ServerAlias vnes.com.br
          DocumentRoot /var/www/vnes

          SSLEngine on
          SSLCertificateFile /etc/ssl/vnes/vnes.fullchain.crt
          SSLCertificateKeyFile /etc/ssl/vnes/vnes.key

          # Variaveis lidas pelo app via getenv() (mod_php)
          SetEnv DB_HOST db.vnes.com.br
          SetEnv DB_DATABASE vnes_db
          SetEnv DB_USERNAME vnes
          SetEnv DB_PASSWORD __DB_PASSWORD__

          <Directory /var/www/vnes>
              AllowOverride All
              Require all granted
          </Directory>

          ErrorLog ${APACHE_LOG_DIR}/vnes_error.log
          CustomLog ${APACHE_LOG_DIR}/vnes_access.log combined
      </VirtualHost>

  # Limites de upload do PHP (ROMs e capas)
  - path: /etc/php/mods-available/vnes.ini
    permissions: '0644'
    owner: root:root
    defer: true
    content: |
      upload_max_filesize = 16M
      post_max_size = 20M

  # Script de configuracao (executado pelo runcmd)
  - path: /usr/local/sbin/vnes-web-setup.sh
    permissions: '0700'
    owner: root:root
    content: |
      #!/usr/bin/env bash
      set -uo pipefail
      LOG=/var/log/vnes-cloud-init.log
      log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

      log "VNES-WEB iniciando configuracao"
      git clone --branch cloud-openstack https://github.com/JhonPaulMR/vnes-crud.git /var/www/vnes \
        || { log "VNES-WEB ERRO: git clone falhou"; exit 1; }
      mkdir -p /var/www/vnes/uploads/covers /var/www/vnes/uploads/roms
      chown -R www-data:www-data /var/www/vnes/uploads
      chmod -R 775 /var/www/vnes/uploads

      phpenmod vnes
      a2enmod ssl rewrite headers
      a2dissite 000-default
      a2ensite vnes
      apache2ctl configtest || { log "VNES-WEB ERRO: configtest do Apache"; exit 1; }
      systemctl restart apache2
      log "VNES-WEB Apache no ar; aguardando o banco db.vnes.com.br"

      # Espera o banco (ate ~10 min, 60 tentativas de 10 s)
      for i in $(seq 1 60); do
        if MYSQL_PWD='__DB_PASSWORD__' mysql -h db.vnes.com.br -u vnes vnes_db -e 'SELECT 1 FROM cartridges LIMIT 1' >/dev/null 2>&1; then
          log "VNES-WEB banco acessivel (tentativa $i)"
          log "VNES-WEB PRONTO"
          exit 0
        fi
        sleep 10
      done
      log "VNES-WEB AVISO: banco nao respondeu; confira o DNS de db.vnes.com.br e o sg-db"
      exit 0

runcmd:
  - [ /usr/local/sbin/vnes-web-setup.sh ]
