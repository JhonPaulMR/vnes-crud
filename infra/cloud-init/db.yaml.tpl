#cloud-config
# =====================================================================
# cloud-init da instancia vnes-db (MariaDB) - Ubuntu 24.04
# =====================================================================
hostname: vnes-db
fqdn: db.vnes.com.br
manage_etc_hosts: true

package_update: true
packages:
  - mariadb-server

write_files:
  # Schema da aplicacao (copia exata do init.sql do repositorio)
  - path: /root/vnes-init.sql
    permissions: '0600'
    owner: root:root
    content: |
      CREATE TABLE IF NOT EXISTS `cartridges` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(255) NOT NULL,
        `cover_image` VARCHAR(255) NOT NULL,
        `rom_path` VARCHAR(255) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

  # Banco e usuario da aplicacao
  - path: /root/vnes-usuario.sql
    permissions: '0600'
    owner: root:root
    content: |
      CREATE DATABASE IF NOT EXISTS vnes_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
      CREATE USER IF NOT EXISTS 'vnes'@'10.10.10.%' IDENTIFIED BY '__DB_PASSWORD__';
      ALTER USER 'vnes'@'10.10.10.%' IDENTIFIED BY '__DB_PASSWORD__';
      GRANT ALL PRIVILEGES ON vnes_db.* TO 'vnes'@'10.10.10.%';
      FLUSH PRIVILEGES;

runcmd:
  - [ bash, -c, "echo \"$(date '+%F %T') VNES-DB iniciando configuracao\" >> /var/log/vnes-cloud-init.log" ]
  # Aceita conexoes de outras maquinas (a restricao fica no usuario @10.10.10.% e no sg-db)
  - sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
  - systemctl enable mariadb
  - systemctl restart mariadb
  - [ bash, -c, "mysql < /root/vnes-usuario.sql" ]
  - [ bash, -c, "mysql vnes_db < /root/vnes-init.sql" ]
  - [ bash, -c, "rm -f /root/vnes-usuario.sql" ]
  - [ bash, -c, "echo \"$(date '+%F %T') VNES-DB PRONTO\" >> /var/log/vnes-cloud-init.log" ]
