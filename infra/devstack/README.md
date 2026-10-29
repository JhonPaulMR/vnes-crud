# DevStack na `vnes-cloud` (192.168.50.20)

Branch usada: `stable/2026.2` (OpenStack Hibiscus, lançado em 2026-09-30), que tem Ubuntu 24.04 como distro testada.
Se der problema, rode o passo 1 com `DEVSTACK_BRANCH=stable/2026.1` (Gazpacho).

## Ordem

1. Copie esta pasta para a VM (ou clone o repositório) e rode como usuário com sudo:
   `./01-preparar-host.sh` (atualiza o sistema, valida KVM, cria o usuário `stack`, clona o DevStack, gera o `local.conf` com a senha).
2. `sudo -u stack -i` e depois `cd devstack && ./stack.sh` (40 a 70 minutos; use `tmux`).
3. Copie da `vnes-infra` o certificado e a chave para `/etc/ssl/vnes/` (nomes em `infra/VARIAVEIS.md`) e rode `./02-horizon-https.sh`.
4. Como `stack`: `./03-preparar-admin.sh` (imagem `ubuntu-24.04`, flavor `vnes.small`, projeto `vnes`, usuário `vnes-devops`).
5. `sudo ./04-persistir-nat.sh`: torna permanentes o `ip_forward`, o IP do `br-ex` e a regra de NAT (ver abaixo).
6. Siga para `infra/openstack/` (Horizon como `vnes-devops`, ou o script de plano B).

## Memória (VM com 6 GB + 4 GB de swap; o host tem 15 GB e não sobra mais)

- Desligados no `local.conf`: Tempest, Cinder e Swift. Mantidos: Keystone, Glance, Placement, Nova, Neutron (OVN), Horizon.
- Sem imagem cirros (`DOWNLOAD_DEFAULT_IMAGES=False`); a única imagem é a Ubuntu 24.04.
- O DevStack ocupa cerca de 5 a 6 GB; cada instância `vnes.small` usa 1 GB. Duas instâncias cabem com folga.
- O `01-preparar-host.sh` cria 4 GB de swap se não houver.

## Depois de reiniciar a VM

O DevStack usa systemd, então os serviços sobem sozinhos (`devstack@*`). Se algo não voltar:

```bash
sudo systemctl restart 'devstack@*'
sudo systemctl status 'devstack@*' --no-pager | head -n 40
```

Quirks conhecidos do OVN / `br-ex` / NAT após reboot (`stack.sh` não deve ser rodado de novo):

```bash
# 1) Serviços do OVN e do Open vSwitch
sudo systemctl restart ovn-controller ovn-northd ovs-vswitchd ovsdb-server 2>/dev/null || true

# 2) O br-ex precisa ter 172.24.4.1/24 e estar ativo
sudo ip addr show br-ex
sudo ip addr add 172.24.4.1/24 dev br-ex 2>/dev/null || true
sudo ip link set br-ex up

# 3) Encaminhamento e NAT (a regra MASQUERADE criada pelo stack.sh NÃO persiste)
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -C POSTROUTING -o eth0 -s 172.24.4.0/24 -j MASQUERADE 2>/dev/null \
  || sudo iptables -t nat -A POSTROUTING -o eth0 -s 172.24.4.0/24 -j MASQUERADE

# 4) Se o Apache/Horizon não subir
sudo systemctl restart apache2
```

Para tornar permanente use `./04-persistir-nat.sh` (instala `99-vnes-ipforward.conf` em `/etc/sysctl.d/` e a unidade `vnes-nat.service`, que no boot reaplica o IP do `br-ex` e a regra MASQUERADE; sem `iptables-persistent`, que poderia gravar as regras do DevStack).
Não use `unstack.sh`/`clean.sh` se não for preciso refazer tudo.

## Observações sobre HTTPS

O `02-horizon-https.sh` cria o site Apache `zz-vnes-cloud-ssl` (porta 443 e redirecionamento do nome `cloud.vnes.com.br` na 80), sem mexer no `horizon.conf` do DevStack. As APIs continuam em `http://192.168.50.20/identity`, `/compute` etc. Backups `*.bak-<data>` ficam ao lado dos arquivos alterados.
Como os cookies ficam `secure`, o login no Horizon só funciona pelo endereço HTTPS.
