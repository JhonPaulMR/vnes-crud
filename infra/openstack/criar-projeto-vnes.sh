#!/usr/bin/env bash
# =====================================================================
# criar-projeto-vnes.sh - PLANO B via CLI do que o vnes-devops faz no Horizon
# Rede, roteador, grupos de seguranca, keypair e as instancias vnes-db / vnes-web.
# Pre-requisito: python3-openstackclient e os arquivos renderizados
#   infra/cloud-init/out/db.yaml e out/web.yaml (gerados por render.sh na vnes-infra
#   e copiados para esta maquina, ou aponte com DB_USERDATA / WEB_USERDATA).
# Idempotente: reexecutar nao duplica recursos.
# =====================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_USERDATA="${DB_USERDATA:-${DIR}/../cloud-init/out/db.yaml}"
WEB_USERDATA="${WEB_USERDATA:-${DIR}/../cloud-init/out/web.yaml}"
KEY_FILE="${KEY_FILE:-$HOME/.ssh/vnes-key}"
IMAGE=ubuntu-24.04
FLAVOR=vnes.small

for f in "$DB_USERDATA" "$WEB_USERDATA"; do
  [[ -s "$f" ]] || { echo "ERRO: user-data nao encontrado: $f (rode infra/cloud-init/render.sh)" >&2; exit 1; }
done
command -v openstack >/dev/null || { echo "ERRO: instale o cliente: sudo apt install python3-openstackclient" >&2; exit 1; }

echo "==> [0/8] Credenciais do vnes-devops"
# shellcheck disable=SC1091
source "${DIR}/vnes-devops-openrc.sh"
openstack token issue -f value -c expires >/dev/null && echo "    autenticado."

echo "==> [1/8] Rede vnes-net / vnes-subnet (10.10.10.0/24, DNS 192.168.50.10)"
openstack network show vnes-net >/dev/null 2>&1 || openstack network create vnes-net
openstack subnet show vnes-subnet >/dev/null 2>&1 || \
  openstack subnet create vnes-subnet --network vnes-net --subnet-range 10.10.10.0/24 \
    --dns-nameserver 192.168.50.10

echo "==> [2/8] Roteador vnes-router (gateway public + interface na vnes-subnet)"
if ! openstack router show vnes-router >/dev/null 2>&1; then
  openstack router create vnes-router
  openstack router set vnes-router --external-gateway public
  openstack router add subnet vnes-router vnes-subnet
else
  echo "    ja existe, garantindo gateway e interface."
  openstack router set vnes-router --external-gateway public
  openstack router add subnet vnes-router vnes-subnet 2>/dev/null || true
fi

echo "==> [3/8] Grupo de seguranca sg-web (22, 80, 443 e ICMP)"
if ! openstack security group show sg-web >/dev/null 2>&1; then
  openstack security group create sg-web --description "Web VNES"
  for p in 22 80 443; do
    openstack security group rule create sg-web --ingress --protocol tcp --dst-port "$p" --remote-ip 0.0.0.0/0
  done
  openstack security group rule create sg-web --ingress --protocol icmp --remote-ip 0.0.0.0/0
fi

echo "==> [4/8] Grupo de seguranca sg-db (3306 e 22 so a partir de sg-web; ICMP)"
if ! openstack security group show sg-db >/dev/null 2>&1; then
  openstack security group create sg-db --description "Banco VNES"
  for p in 3306 22; do
    openstack security group rule create sg-db --ingress --protocol tcp --dst-port "$p" --remote-group sg-web
  done
  openstack security group rule create sg-db --ingress --protocol icmp --remote-group sg-web
fi

echo "==> [5/8] Keypair vnes-key"
if ! openstack keypair show vnes-key >/dev/null 2>&1; then
  if [[ ! -f "$KEY_FILE" ]]; then
    mkdir -p "$(dirname "$KEY_FILE")"
    ssh-keygen -t ed25519 -N "" -f "$KEY_FILE" -C "vnes-key"
    echo "    chave gerada em $KEY_FILE"
  fi
  chmod 600 "$KEY_FILE"
  openstack keypair create vnes-key --public-key "${KEY_FILE}.pub"
fi

echo "==> [6/8] Instancia vnes-db"
if ! openstack server show vnes-db >/dev/null 2>&1; then
  openstack server create vnes-db --flavor "$FLAVOR" --image "$IMAGE" --network vnes-net \
    --security-group sg-db --key-name vnes-key --user-data "$DB_USERDATA"
fi
echo "    aguardando ficar ACTIVE..."
for _ in $(seq 1 60); do
  st=$(openstack server show vnes-db -f value -c status)
  [[ "$st" == "ACTIVE" ]] && break
  [[ "$st" == "ERROR" ]] && { echo "ERRO: vnes-db em ERROR" >&2; openstack server show vnes-db -c fault; exit 1; }
  sleep 5
done
[[ "$st" == "ACTIVE" ]] || { echo "ERRO: vnes-db nao ficou ACTIVE" >&2; exit 1; }
DB_IP=$(openstack server show vnes-db -f json | python3 -c 'import json,sys,re; d=json.load(sys.stdin)["addresses"]; print(re.findall(r"\d+\.\d+\.\d+\.\d+", str(d))[0])')
echo "    IP privado do vnes-db: ${DB_IP}"

echo
echo "==> ATENCAO: antes de criar o vnes-web, atualize o DNS na vnes-infra:"
echo "      infra/dns/atualizar-registro.sh db ${DB_IP}"
if [[ -z "${PULAR_PAUSA_DNS:-}" ]]; then
  read -r -p "    Pressione ENTER depois de atualizar o DNS do db... " _
fi

echo "==> [7/8] Instancia vnes-web"
if ! openstack server show vnes-web >/dev/null 2>&1; then
  openstack server create vnes-web --flavor "$FLAVOR" --image "$IMAGE" --network vnes-net \
    --security-group sg-web --key-name vnes-key --user-data "$WEB_USERDATA"
fi
for _ in $(seq 1 60); do
  st=$(openstack server show vnes-web -f value -c status)
  [[ "$st" == "ACTIVE" ]] && break
  [[ "$st" == "ERROR" ]] && { echo "ERRO: vnes-web em ERROR" >&2; openstack server show vnes-web -c fault; exit 1; }
  sleep 5
done
[[ "$st" == "ACTIVE" ]] || { echo "ERRO: vnes-web nao ficou ACTIVE" >&2; exit 1; }

echo "==> [8/8] Floating IP do vnes-web"
FIP=$(openstack floating ip list --port "$(openstack port list --server vnes-web -f value -c ID | head -n1)" -f value -c "Floating IP Address" | head -n1)
if [[ -z "$FIP" ]]; then
  FIP=$(openstack floating ip create public -f value -c floating_ip_address)
  openstack server add floating ip vnes-web "$FIP"
fi
WEB_PRIV=$(openstack server show vnes-web -f json | python3 -c 'import json,sys,re; d=json.load(sys.stdin)["addresses"]; print(re.findall(r"\d+\.\d+\.\d+\.\d+", str(d))[0])')

echo
echo "=============================================================="
echo " vnes-db  : ${DB_IP} (privado)"
echo " vnes-web : ${WEB_PRIV} (privado)  /  ${FIP} (floating IP)"
echo
echo " Atualize o DNS na vnes-infra (se ainda nao fez):"
echo "   infra/dns/atualizar-registro.sh db  ${DB_IP}"
echo "   infra/dns/atualizar-registro.sh www ${FIP}"
echo "   infra/dns/atualizar-registro.sh @   ${FIP}"
echo " O cloud-init leva alguns minutos; acompanhe com:"
echo "   openstack console log show vnes-web | tail"
echo " Depois teste: https://www.vnes.com.br"
echo "=============================================================="
