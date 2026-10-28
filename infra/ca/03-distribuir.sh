#!/usr/bin/env bash
# 03-distribuir.sh <usuario@host> - copia o certificado curinga para um servidor
# Destino:  /etc/ssl/vnes/vnes.fullchain.crt  e  /etc/ssl/vnes/vnes.key
# Exemplos (a partir da vnes-infra):
#   sudo ./03-distribuir.sh ubuntu@192.168.50.20        # Horizon (vnes-cloud)
#   sudo ./03-distribuir.sh ubuntu@172.24.4.123         # Apache (vnes-web, floating IP)
#
# Para levar a CA raiz ao Windows (rodar no PowerShell do Windows):
#   scp ubuntu@192.168.50.10:/opt/vnes-ca/certs/vnes-root-ca.crt .
# e depois executar infra\hyperv\03-configurar-cliente.ps1
set -euo pipefail

BASE="${VNES_CA_DIR:-/opt/vnes-ca}"
FULL="$BASE/certs/wildcard.vnes.com.br.fullchain.crt"
KEY="$BASE/private/wildcard.vnes.com.br.key"
ROOT="$BASE/certs/vnes-root-ca.crt"

if [ $# -ne 1 ]; then
  echo "Uso: $0 usuario@host" >&2
  exit 1
fi
ALVO="$1"

[ -f "$FULL" ] && [ -f "$KEY" ] || { echo "Certificado nao encontrado. Rode antes ./02-emitir-curinga.sh" >&2; exit 1; }

echo "==> [1/3] Enviando arquivos para $ALVO:/tmp ..."
scp "$FULL" "$ALVO:/tmp/vnes.fullchain.crt"
scp "$KEY"  "$ALVO:/tmp/vnes.key"
scp "$ROOT" "$ALVO:/tmp/vnes-root-ca.crt"

echo "==> [2/3] Instalando em /etc/ssl/vnes com as permissoes corretas ..."
# Chave: root:root 640 (o Apache e o Horizon leem a chave como root ao iniciar).
ssh -t "$ALVO" 'sudo mkdir -p /etc/ssl/vnes &&
  sudo install -m 644 -o root -g root /tmp/vnes.fullchain.crt /etc/ssl/vnes/vnes.fullchain.crt &&
  sudo install -m 640 -o root -g root /tmp/vnes.key /etc/ssl/vnes/vnes.key &&
  sudo install -m 644 -o root -g root /tmp/vnes-root-ca.crt /etc/ssl/vnes/vnes-root-ca.crt &&
  rm -f /tmp/vnes.fullchain.crt /tmp/vnes.key /tmp/vnes-root-ca.crt &&
  ls -l /etc/ssl/vnes'

echo "==> [3/3] Concluido. Reinicie o servico que usa o certificado (apache2) em $ALVO."
