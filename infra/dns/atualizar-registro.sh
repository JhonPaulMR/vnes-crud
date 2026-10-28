#!/usr/bin/env bash
# atualizar-registro.sh <nome> <ip> - atualiza um registro A na zona vnes.com.br
# Exemplos:
#   sudo ./atualizar-registro.sh www 172.24.4.123
#   sudo ./atualizar-registro.sh @   172.24.4.123
#   sudo ./atualizar-registro.sh db  10.10.10.45
# Variavel opcional: ZONA_ARQ (padrao /etc/bind/zones/db.vnes.com.br)
set -euo pipefail

ZONA="vnes.com.br"
ARQ="${ZONA_ARQ:-/etc/bind/zones/db.vnes.com.br}"

if [ $# -ne 2 ]; then
  echo "Uso: $0 <nome> <ip>   (ex.: $0 www 172.24.4.123)" >&2
  exit 1
fi
NOME="$1"
IP="$2"

if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "IP invalido: $IP" >&2
  exit 1
fi
if ! [[ "$NOME" =~ ^(@|[A-Za-z0-9-]+)$ ]]; then
  echo "Nome invalido: $NOME" >&2
  exit 1
fi
[ -f "$ARQ" ] || { echo "Arquivo de zona nao encontrado: $ARQ" >&2; exit 1; }

echo "==> [1/4] Atualizando registro A '$NOME' -> $IP em $ARQ ..."
# Escapa o nome para uso no sed ("@" nao precisa, "-" tambem nao)
if ! grep -Eq "^${NOME}[[:space:]]+IN[[:space:]]+A[[:space:]]" "$ARQ"; then
  echo "Registro A '$NOME' nao existe na zona." >&2
  exit 1
fi
sed -i -E "s/^(${NOME}[[:space:]]+IN[[:space:]]+A[[:space:]]+)[0-9.]+/\1${IP}/" "$ARQ"

echo "==> [2/4] Incrementando o serial ..."
HOJE="$(date +%Y%m%d)"
ATUAL="$(grep -E '^[[:space:]]+[0-9]{10}[[:space:]]*;[[:space:]]*serial' "$ARQ" | head -n1 | awk '{print $1}')"
if [ -z "$ATUAL" ]; then
  echo "Nao encontrei a linha de serial na zona." >&2
  exit 1
fi
if [ "${ATUAL:0:8}" = "$HOJE" ]; then
  NOVO=$((ATUAL + 1))
else
  NOVO="${HOJE}01"
fi
sed -i -E "s/${ATUAL}([[:space:]]*;[[:space:]]*serial)/${NOVO}\1/" "$ARQ"
echo "    serial: $ATUAL -> $NOVO"

echo "==> [3/4] Validando zona ..."
named-checkzone "$ZONA" "$ARQ"

echo "==> [4/4] Recarregando zona e testando ..."
rndc reload "$ZONA"
sleep 1
if [ "$NOME" = "@" ]; then FQDN="$ZONA"; else FQDN="${NOME}.${ZONA}"; fi
echo -n "dig +short $FQDN  =>  "
dig @127.0.0.1 +short "$FQDN"
