#!/usr/bin/env bash
# 01-criar-ca.sh - cria a CA raiz da VNES (executar na vnes-infra)
# Uso: sudo ./01-criar-ca.sh      (VNES_CA_DIR muda o diretorio base; padrao /opt/vnes-ca)
set -euo pipefail

BASE="${VNES_CA_DIR:-/opt/vnes-ca}"
CNF_DIR="$(cd "$(dirname "$0")" && pwd)"
CNF="$CNF_DIR/openssl-ca.cnf"
KEY="$BASE/private/vnes-root-ca.key"
CRT="$BASE/certs/vnes-root-ca.crt"

echo "==> [1/3] Criando estrutura de diretorios em $BASE ..."
mkdir -p "$BASE/private" "$BASE/certs" "$BASE/csr"
chmod 700 "$BASE/private"

echo "==> [2/3] Chave privada da CA raiz (RSA 4096) ..."
if [ -f "$KEY" ]; then
  echo "    Chave ja existe, mantendo: $KEY"
else
  openssl genrsa -out "$KEY" 4096
  # Chave SEM senha para simplificar o laboratorio. Em producao, proteja com
  # -aes256 e guarde a CA raiz offline.
  chmod 600 "$KEY"
fi

echo "==> [3/3] Certificado raiz autoassinado (10 anos) ..."
if [ -f "$CRT" ]; then
  echo "    Certificado ja existe, mantendo: $CRT"
else
  openssl req -x509 -new -sha256 -key "$KEY" -days 3650 \
    -subj "/C=BR/O=VNES/CN=VNES Root CA" \
    -config "$CNF" -extensions v3_root_ca \
    -out "$CRT"
  chmod 644 "$CRT"
fi

echo ""
openssl x509 -in "$CRT" -noout -subject -issuer -dates -ext basicConstraints,keyUsage
echo ""
echo "CA pronta. Certificado publico: $CRT"
echo "Proximo passo: ./02-emitir-curinga.sh"
