#!/usr/bin/env bash
# =====================================================================
# 03-preparar-admin.sh - passos de ADMIN via CLI (equivalente ao Horizon admin)
# Executar como usuario stack:  sudo -u stack -i  ->  ./03-preparar-admin.sh
# Cria: imagem ubuntu-24.04, flavor vnes.small, projeto vnes,
#       usuario vnes-devops (papel member). Idempotente.
# Senha do vnes-devops: variavel VNES_DEVOPS_PASSWORD ou digitada (read -s).
# =====================================================================
set -euo pipefail

IMG_DIR=/opt/stack/images
IMG_FILE="${IMG_DIR}/noble-server-cloudimg-amd64.img"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"

echo "==> [0/5] Carregando credenciais de admin"
# shellcheck disable=SC1091
set +u
source /opt/stack/devstack/openrc admin admin
set -u

echo "==> [1/5] Imagem ubuntu-24.04"
if openstack image show ubuntu-24.04 >/dev/null 2>&1; then
  echo "    ja existe, pulando."
else
  mkdir -p "$IMG_DIR"
  if [[ ! -s "$IMG_FILE" ]]; then
    echo "    Baixando a imagem Ubuntu 24.04 cloud (~600 MB)..."
    curl -fL --retry 3 -o "${IMG_FILE}.part" "$IMG_URL"
    mv "${IMG_FILE}.part" "$IMG_FILE"
  fi
  echo "    Enviando para o Glance (publica)..."
  openstack image create ubuntu-24.04 \
    --file "$IMG_FILE" --disk-format qcow2 --container-format bare \
    --public --property hw_qemu_guest_agent=no
fi

echo "==> [2/5] Flavor vnes.small (1 vCPU, 1024 MB, 10 GB)"
if openstack flavor show vnes.small >/dev/null 2>&1; then
  echo "    ja existe, pulando."
else
  openstack flavor create vnes.small --vcpus 1 --ram 1024 --disk 10 --public
fi

echo "==> [3/5] Projeto vnes"
if openstack project show vnes --domain Default >/dev/null 2>&1; then
  echo "    ja existe, pulando."
else
  openstack project create vnes --domain Default --description "Projeto da loja VNES"
fi

echo "==> [4/5] Usuario vnes-devops"
if openstack user show vnes-devops --domain Default >/dev/null 2>&1; then
  echo "    ja existe, pulando (senha mantida)."
else
  if [[ -z "${VNES_DEVOPS_PASSWORD:-}" ]]; then
    read -r -s -p "Defina a senha do usuario vnes-devops: " VNES_DEVOPS_PASSWORD; echo
    read -r -s -p "Repita a senha: " CONFIRMA; echo
    [[ "$VNES_DEVOPS_PASSWORD" == "$CONFIRMA" ]] || { echo "As senhas nao conferem." >&2; exit 1; }
  fi
  openstack user create vnes-devops --domain Default --project vnes --password "$VNES_DEVOPS_PASSWORD"
fi

echo "==> [5/5] Papel member do vnes-devops no projeto vnes"
openstack role add --project vnes --user vnes-devops member
openstack role assignment list --project vnes --user vnes-devops --names

echo
echo "Pronto. Entre no Horizon como vnes-devops (dominio Default, projeto vnes)"
echo "ou use infra/openstack/criar-projeto-vnes.sh."
