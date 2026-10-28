#!/usr/bin/env bash
# =====================================================================
# 02-horizon-https.sh - Horizon em HTTPS (https://cloud.vnes.com.br/dashboard)
# Executar APOS o stack.sh, como usuario com sudo:  ./02-horizon-https.sh
# Requer: /etc/ssl/vnes/vnes.fullchain.crt e /etc/ssl/vnes/vnes.key
#         (copiados da CA na vnes-infra).
#
# Como funciona: o DevStack gera o site Apache do Horizon (horizon.conf) so na
# porta 80. Este script NAO o altera; cria um site novo (zz-vnes-cloud-ssl.conf)
# que copia as linhas WSGI/Alias do horizon.conf para um vhost 443 com
# ServerName cloud.vnes.com.br. O nome comeca com "zz-" para que o horizon.conf
# continue sendo o vhost padrao da porta 80 (APIs em http://192.168.50.20/identity,
# /compute etc. seguem funcionando). Na porta 80 so o ServerName
# cloud.vnes.com.br e redirecionado para HTTPS.
# =====================================================================
set -euo pipefail

FQDN="cloud.vnes.com.br"
CERT=/etc/ssl/vnes/vnes.fullchain.crt
KEY=/etc/ssl/vnes/vnes.key
CA_ROOT="${CA_ROOT:-/etc/ssl/vnes/vnes-root-ca.crt}"   # opcional, so para o teste com curl
LOCAL_SETTINGS=/opt/stack/horizon/openstack_dashboard/local/local_settings.py
NOVO_SITE=zz-vnes-cloud-ssl
SITES_AVAIL=/etc/apache2/sites-available
STAMP="$(date +%Y%m%d-%H%M%S)"
FQDN_RE="${FQDN//./\\.}"

[[ $EUID -ne 0 ]] || { echo "Execute como usuario comum com sudo." >&2; exit 1; }

echo "==> [1/6] Conferindo certificado e chave"
sudo test -s "$CERT" || { echo "ERRO: $CERT nao encontrado. Copie da vnes-infra." >&2; exit 1; }
sudo test -s "$KEY"  || { echo "ERRO: $KEY nao encontrado. Copie da vnes-infra." >&2; exit 1; }
sudo chown root:root "$KEY"; sudo chmod 600 "$KEY"; sudo chmod 644 "$CERT"
c1=$(sudo openssl x509 -in "$CERT" -noout -pubkey | sha256sum)
c2=$(sudo openssl pkey -in "$KEY" -pubout | sha256sum)
[[ "$c1" == "$c2" ]] || { echo "ERRO: a chave nao corresponde ao certificado." >&2; exit 1; }
echo "    OK: certificado e chave combinam."

echo "==> [2/6] Habilitando modulos do Apache (ssl, headers, rewrite)"
sudo a2enmod ssl headers rewrite >/dev/null

echo "==> [3/6] Localizando o site do Horizon gerado pelo DevStack"
HCONF=""
if [[ -f "$SITES_AVAIL/horizon.conf" ]] && sudo grep -q 'WSGIScriptAlias' "$SITES_AVAIL/horizon.conf"; then
  HCONF="$SITES_AVAIL/horizon.conf"
else
  HCONF=$(sudo grep -l 'WSGIScriptAlias.*openstack_dashboard' "$SITES_AVAIL"/*.conf 2>/dev/null | grep -v "$NOVO_SITE" | head -n1 || true)
fi
[[ -n "$HCONF" ]] || { echo "ERRO: conf do Horizon nao encontrada em $SITES_AVAIL" >&2; exit 1; }
echo "    Encontrado: $HCONF"
sudo cp -a "$HCONF" "${HCONF}.bak-${STAMP}"

# Copia fiel das linhas WSGI/Alias do site original
WSGI_LINES=$(sudo grep -E '^[[:space:]]*(WSGIScriptAlias|WSGIApplicationGroup|SetEnv|Alias|RedirectMatch)[[:space:]]' "$HCONF" || true)
DAEMON_LINE=$(sudo grep -E '^[[:space:]]*WSGIDaemonProcess[[:space:]]' "$HCONF" | head -n1 || true)
[[ -n "$DAEMON_LINE" && -n "$WSGI_LINES" ]] || { echo "ERRO: nao consegui ler as diretivas WSGI de $HCONF" >&2; exit 1; }
WSGI_PATH=$(echo "$WSGI_LINES" | awk '/WSGIScriptAlias/ {print $3; exit}')
HORIZON_DIR="${WSGI_PATH%/openstack_dashboard/wsgi.py}"
# Novo grupo de daemon (nome diferente; 2 processos para economizar RAM)
DAEMON_SSL=$(echo "$DAEMON_LINE" | sed -E 's/WSGIDaemonProcess +[^ ]+/WSGIDaemonProcess horizon-ssl/; s/processes=[0-9]+/processes=2/; s/^[[:space:]]+//')
WSGI_INDENT=$(echo "$WSGI_LINES" | sed -E 's/^[[:space:]]*/    /')
echo "    HORIZON_DIR=$HORIZON_DIR"

echo "==> [4/6] Criando o site $NOVO_SITE"
LOGDIR=/var/log/apache2
if [[ -f "$SITES_AVAIL/$NOVO_SITE.conf" ]]; then
  sudo cp -a "$SITES_AVAIL/$NOVO_SITE.conf" "$SITES_AVAIL/$NOVO_SITE.conf.bak-${STAMP}"
fi
sudo tee "$SITES_AVAIL/$NOVO_SITE.conf" >/dev/null <<VHOST
# Gerado por 02-horizon-https.sh em ${STAMP}
# Redireciona SOMENTE o nome ${FQDN} para HTTPS (acesso por IP continua em HTTP)
<VirtualHost *:80>
    ServerName ${FQDN}
    RewriteEngine On
    RewriteRule ^/?(.*)\$ https://${FQDN}/\$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName ${FQDN}

    SSLEngine on
    SSLCertificateFile ${CERT}
    SSLCertificateKeyFile ${KEY}
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

    # --- Diretivas WSGI copiadas do site do Horizon gerado pelo DevStack ---
    ${DAEMON_SSL}
    WSGIProcessGroup horizon-ssl
${WSGI_INDENT}

    DocumentRoot ${HORIZON_DIR}/.blackhole/

    <Directory />
        Options FollowSymLinks
        AllowOverride None
    </Directory>
    <Directory ${HORIZON_DIR}/>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${LOGDIR}/horizon_ssl_error.log
    CustomLog ${LOGDIR}/horizon_ssl_access.log combined
</VirtualHost>
VHOST
sudo a2ensite "$NOVO_SITE" >/dev/null

echo "==> [5/6] Ajustando o local_settings.py do Horizon"
[[ -f "$LOCAL_SETTINGS" ]] || { echo "ERRO: $LOCAL_SETTINGS nao existe." >&2; exit 1; }
sudo cp -a "$LOCAL_SETTINGS" "${LOCAL_SETTINGS}.bak-${STAMP}"
# Remove bloco anterior (idempotente) e acrescenta o novo no final
sudo sed -i '/# >>> VNES HTTPS/,/# <<< VNES HTTPS/d' "$LOCAL_SETTINGS"
sudo tee -a "$LOCAL_SETTINGS" >/dev/null <<PYCONF

# >>> VNES HTTPS
# O Apache termina o TLS (o Django ja ve https); o header abaixo cobre proxy na frente.
ALLOWED_HOSTS = ['${FQDN}', '192.168.50.20', 'localhost', '127.0.0.1']
CSRF_TRUSTED_ORIGINS = ['https://${FQDN}']
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True
# <<< VNES HTTPS
PYCONF

echo "==> [6/6] Testando a configuracao do Apache e reiniciando"
sudo apachectl configtest
sudo systemctl restart apache2
sleep 3

echo "--- HTTPS https://${FQDN}/dashboard (resolve para 127.0.0.1 se o DNS ainda nao responde)"
if [[ -f "$CA_ROOT" ]]; then CACERT="$CA_ROOT"; else CACERT="$CERT"; fi
curl -sS -I --cacert "$CACERT" --resolve "${FQDN}:443:127.0.0.1" "https://${FQDN}/dashboard" | head -n 5 || \
  echo "AVISO: curl falhou; veja ${LOGDIR}/horizon_ssl_error.log (CA raiz em $CA_ROOT?)"
echo "--- Redirecionamento HTTP -> HTTPS (por nome)"
curl -sS -I --resolve "${FQDN}:80:127.0.0.1" "http://${FQDN}/dashboard" | grep -Ei '^(HTTP|Location)' || true
echo "--- API do Keystone por IP deve continuar em HTTP (esperado 200)"
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' http://192.168.50.20/identity/

echo
echo "Pronto. Abra https://${FQDN}/dashboard (usuario: admin, dominio: Default)."
echo "Obs.: com cookies 'secure', login em http://192.168.50.20/dashboard deixa de funcionar; use o nome HTTPS."
echo "Backups: ${HCONF}.bak-${STAMP} e ${LOCAL_SETTINGS}.bak-${STAMP}"
