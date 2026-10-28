#!/usr/bin/env bash
# instalar-bind.sh - instala e configura o Bind9 na vnes-infra (Ubuntu 24.04)
# Executar na pasta infra/dns:   sudo ./instalar-bind.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo $0" >&2
  exit 1
fi

echo "==> [1/7] Instalando bind9 e bind9-utils ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 bind9-utils dnsutils

echo "==> [2/7] Copiando arquivos de configuracao ..."
install -m 644 "$DIR/named.conf.options" /etc/bind/named.conf.options
install -m 644 "$DIR/named.conf.local"   /etc/bind/named.conf.local
mkdir -p /etc/bind/zones
install -m 644 -o bind -g bind "$DIR/db.vnes.com.br" /etc/bind/zones/db.vnes.com.br
install -m 644 -o bind -g bind "$DIR/db.192.168.50"  /etc/bind/zones/db.192.168.50

echo "==> [3/7] Validando configuracao (named-checkconf) ..."
named-checkconf

echo "==> [4/7] Validando zonas (named-checkzone) ..."
named-checkzone vnes.com.br /etc/bind/zones/db.vnes.com.br
named-checkzone 50.168.192.in-addr.arpa /etc/bind/zones/db.192.168.50

echo "==> [5/7] Reiniciando e habilitando o servico ..."
# No Ubuntu 24.04 o servico se chama 'named' (alias bind9)
systemctl enable named
systemctl restart named
systemctl --no-pager --lines=0 status named || true

echo "==> [6/7] Firewall ..."
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 53
  echo "    ufw: porta 53 liberada."
else
  echo "    ufw inativo, nada a fazer."
fi

echo "==> [7/7] Testes com dig ..."
echo "-- cloud.vnes.com.br (esperado 192.168.50.20)"
dig @127.0.0.1 +short cloud.vnes.com.br
echo "-- ns1.vnes.com.br (esperado 192.168.50.10)"
dig @127.0.0.1 +short ns1.vnes.com.br
echo "-- www.vnes.com.br (placeholder ate a instancia existir)"
dig @127.0.0.1 +short www.vnes.com.br
echo "-- PTR 192.168.50.20 (esperado cloud.vnes.com.br.)"
dig @127.0.0.1 +short -x 192.168.50.20
echo "-- Encaminhamento (google.com)"
dig @127.0.0.1 +short google.com | head -n 2

echo ""
echo "Bind9 pronto. Depois de criar as instancias use ./atualizar-registro.sh <nome> <ip>"
