#!/usr/bin/env bash
# =====================================================================
# render.sh - gera out/db.yaml e out/web.yaml a partir dos modelos .tpl
# Executar na vnes-infra (onde esta a CA):  ./render.sh
#
# !!! ATENCAO: os arquivos em out/ contem a CHAVE PRIVADA do certificado e a
# !!! SENHA DO BANCO. Nunca versione (ja esta no .gitignore) nem compartilhe.
#
# Variaveis opcionais: DB_PASSWORD, CERT_FULLCHAIN, CERT_KEY
# =====================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT_DIR:-${DIR}/out}"
CERT_FULLCHAIN="${CERT_FULLCHAIN:-/opt/vnes-ca/certs/wildcard.vnes.com.br.fullchain.crt}"
CERT_KEY="${CERT_KEY:-/opt/vnes-ca/private/wildcard.vnes.com.br.key}"

echo "==> [1/5] Conferindo arquivos"
for f in "$CERT_FULLCHAIN" "$CERT_KEY" "$DIR/db.yaml.tpl" "$DIR/web.yaml.tpl"; do
  [[ -r "$f" ]] || { echo "ERRO: nao consigo ler $f (use sudo ou ajuste CERT_FULLCHAIN / CERT_KEY)" >&2; exit 1; }
done

echo "==> [2/5] Senha do banco"
if [[ -z "${DB_PASSWORD:-}" ]]; then
  read -r -s -p "Senha do usuario 'vnes' no MariaDB: " DB_PASSWORD; echo
  read -r -s -p "Repita a senha: " CONFIRMA; echo
  [[ "$DB_PASSWORD" == "$CONFIRMA" ]] || { echo "As senhas nao conferem." >&2; exit 1; }
fi
if [[ ! "$DB_PASSWORD" =~ ^[A-Za-z0-9_.-]{8,}$ ]]; then
  echo "Senha invalida: use letras, numeros, '_', '.' ou '-' (minimo 8 caracteres)." >&2
  echo "(Restricao para nao quebrar SQL, Apache, shell e YAML.)" >&2
  exit 1
fi

umask 077
mkdir -p "$OUT"

# Substitui uma linha "<indentacao>__MARCADOR__" pelo conteudo do arquivo, com a mesma indentacao
injetar() {
  local marcador="$1" arquivo="$2" linha indent
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    if [[ "$linha" =~ ^([[:space:]]*)${marcador}[[:space:]]*$ ]]; then
      indent="${BASH_REMATCH[1]}"
      while IFS= read -r l || [[ -n "$l" ]]; do
        printf '%s%s\n' "$indent" "${l%$'\r'}"
      done < "$arquivo"
    else
      printf '%s\n' "${linha%$'\r'}"
    fi
  done
}

echo "==> [3/5] Gerando out/db.yaml"
while IFS= read -r linha || [[ -n "$linha" ]]; do
  printf '%s\n' "${linha//__DB_PASSWORD__/$DB_PASSWORD}"
done < "$DIR/db.yaml.tpl" > "$OUT/db.yaml"

echo "==> [4/5] Gerando out/web.yaml (certificado + chave + senha)"
injetar "__CERT_FULLCHAIN__" "$CERT_FULLCHAIN" < "$DIR/web.yaml.tpl" \
  | injetar "__CERT_KEY__" "$CERT_KEY" \
  | while IFS= read -r linha || [[ -n "$linha" ]]; do printf '%s\n' "${linha//__DB_PASSWORD__/$DB_PASSWORD}"; done \
  > "$OUT/web.yaml"
chmod 600 "$OUT/db.yaml" "$OUT/web.yaml"
# Executado com sudo: devolve os arquivos ao usuario que chamou (para o scp funcionar)
if [[ -n "${SUDO_USER:-}" ]]; then
  chown -R "$SUDO_USER:$SUDO_USER" "$OUT"
fi

if grep -q '__[A-Z_]*__' "$OUT/db.yaml" "$OUT/web.yaml"; then
  echo "ERRO: sobrou algum marcador sem substituir:" >&2
  grep -n '__[A-Z_]*__' "$OUT/db.yaml" "$OUT/web.yaml" >&2
  exit 1
fi

echo "==> [5/5] Validando"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  for y in db web; do
    python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1])); print("    YAML valido:", sys.argv[1])' "$OUT/$y.yaml"
  done
else
  echo "    (python3-yaml nao instalado; validacao YAML ignorada. Instale: sudo apt install python3-yaml)"
fi
if command -v cloud-init >/dev/null 2>&1; then
  for y in db web; do
    cloud-init schema --config-file "$OUT/$y.yaml" || echo "    AVISO: cloud-init schema reclamou de $y.yaml"
  done
else
  echo "    (cloud-init nao instalado aqui; schema ignorado)"
fi

echo
echo "Pronto: $OUT/db.yaml e $OUT/web.yaml (permissao 600)."
echo "AVISO: contem chave privada e senha. Copie com scp para quem vai usar e apague depois."
