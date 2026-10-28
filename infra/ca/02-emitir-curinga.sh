#!/usr/bin/env bash
# 02-emitir-curinga.sh - emite o certificado curinga *.vnes.com.br assinado pela CA raiz
# Uso: sudo ./02-emitir-curinga.sh      (VNES_CA_DIR muda o diretorio base)
set -euo pipefail

BASE="${VNES_CA_DIR:-/opt/vnes-ca}"
CNF_DIR="$(cd "$(dirname "$0")" && pwd)"
CNF="$CNF_DIR/openssl-ca.cnf"

CA_KEY="$BASE/private/vnes-root-ca.key"
CA_CRT="$BASE/certs/vnes-root-ca.crt"
KEY="$BASE/private/wildcard.vnes.com.br.key"
CSR="$BASE/csr/wildcard.vnes.com.br.csr"
CRT="$BASE/certs/wildcard.vnes.com.br.crt"
FULL="$BASE/certs/wildcard.vnes.com.br.fullchain.crt"

[ -f "$CA_KEY" ] && [ -f "$CA_CRT" ] || { echo "CA nao encontrada. Rode antes ./01-criar-ca.sh" >&2; exit 1; }
mkdir -p "$BASE/csr"

echo "==> [1/4] Chave privada do curinga (RSA 2048) ..."
if [ -f "$KEY" ]; then
  echo "    Chave ja existe, reutilizando."
else
  openssl genrsa -out "$KEY" 2048
  chmod 600 "$KEY"
fi

echo "==> [2/4] CSR para CN=*.vnes.com.br ..."
openssl req -new -sha256 -key "$KEY" -subj "/C=BR/O=VNES/CN=*.vnes.com.br" -out "$CSR"

echo "==> [3/4] Assinando com a CA raiz (397 dias, limite aceito pelos navegadores) ..."
openssl x509 -req -sha256 -in "$CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" \
  -CAcreateserial -days 397 \
  -extfile "$CNF" -extensions v3_wildcard \
  -out "$CRT"
chmod 644 "$CRT"

echo "==> [4/4] Montando cadeia completa (curinga + raiz) ..."
cat "$CRT" "$CA_CRT" > "$FULL"
chmod 644 "$FULL"

echo ""
echo "-- Verificacao:"
openssl verify -CAfile "$CA_CRT" "$CRT"
echo "-- SAN e validade:"
openssl x509 -in "$CRT" -noout -subject -dates -ext subjectAltName,extendedKeyUsage,basicConstraints
echo ""
echo "Arquivos:"
echo "  cadeia completa: $FULL"
echo "  chave privada:   $KEY"
echo "Proximo passo: sudo ./03-distribuir.sh ubuntu@192.168.50.20"
