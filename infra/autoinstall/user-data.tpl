#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: br
  network:
    version: 2
    ethernets:
      lan:
        match:
          driver: hv_netvsc
        set-name: eth0
        addresses: [__IP__/24]
        routes:
          - to: default
            via: 192.168.50.1
        nameservers:
          addresses: [1.1.1.1, 8.8.8.8]
          search: [vnes.com.br]
  storage:
    layout:
      name: direct
  identity:
    hostname: __HOSTNAME__
    username: ubuntu
    realname: ubuntu
    password: '__SENHA_HASH__'
  ssh:
    install-server: true
    allow-pw: true
    authorized-keys:
      - __CHAVE_SSH_PUBLICA__
  updates: security
  late-commands:
    - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/90-vnes
    - chmod 440 /target/etc/sudoers.d/90-vnes
  shutdown: poweroff
