#!/usr/bin/env bash
# =====================================================================
# 01-preparar-host.sh - prepara a VM vnes-cloud para o DevStack
# Executar como usuario com sudo (NAO como root):  ./01-preparar-host.sh
# =====================================================================
set -euo pipefail

# Branch do DevStack compativel com Ubuntu 24.04 (noble). Pode ser trocada:
#   DEVSTACK_BRANCH=stable/2026.1 ./01-preparar-host.sh
DEVSTACK_BRANCH="${DEVSTACK_BRANCH:-stable/2026.2}"
DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -eq 0 ]]; then
  echo "Execute como usuario comum com sudo, nao como root." >&2
  exit 1
fi

echo "==> [1/7] Atualizando pacotes do sistema"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

echo "==> [2/7] Instalando git, curl e cpu-checker"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install git cpu-checker curl

echo "==> [3/7] Verificando virtualizacao aninhada (KVM)"
if [[ ! -e /dev/kvm ]]; then
  echo "ERRO: /dev/kvm nao existe. No Windows (PowerShell como admin) rode:" >&2
  echo "  Set-VMProcessor -VMName vnes-cloud -ExposeVirtualizationExtensions \$true" >&2
  exit 1
fi
sudo kvm-ok

echo "==> [4/7] Verificando memoria e swap"
free -h
if [[ $(swapon --show --noheadings | wc -l) -eq 0 ]]; then
  echo "    Sem swap: criando /swapfile de 4 GB (folga durante o stack.sh)"
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

echo "==> [5/7] Criando o usuario 'stack' (padrao da documentacao do DevStack)"
if ! id stack >/dev/null 2>&1; then
  sudo useradd -s /bin/bash -d /opt/stack -m stack
fi
sudo chmod +x /opt/stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack >/dev/null
sudo chmod 440 /etc/sudoers.d/stack
sudo visudo -cf /etc/sudoers.d/stack

echo "==> [6/7] Clonando o DevStack (${DEVSTACK_BRANCH})"
if [[ ! -d /opt/stack/devstack/.git ]]; then
  sudo -u stack git clone https://opendev.org/openstack/devstack --branch "${DEVSTACK_BRANCH}" /opt/stack/devstack
else
  echo "    /opt/stack/devstack ja existe, mantendo."
fi

echo "==> [7/7] Gerando o local.conf com a senha do admin"
if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  read -r -s -p "Senha do admin do OpenStack (so letras e numeros, min. 8): " ADMIN_PASSWORD; echo
  read -r -s -p "Repita a senha: " CONFIRMA; echo
  [[ "$ADMIN_PASSWORD" == "$CONFIRMA" ]] || { echo "As senhas nao conferem." >&2; exit 1; }
fi
if [[ ! "$ADMIN_PASSWORD" =~ ^[A-Za-z0-9]{8,}$ ]]; then
  echo "Senha invalida: use somente letras e numeros (minimo 8 caracteres)." >&2
  exit 1
fi
sed "s/TROCAR_SENHA/${ADMIN_PASSWORD}/" "${DIR_SCRIPT}/local.conf" | sudo -u stack tee /opt/stack/devstack/local.conf >/dev/null
sudo chmod 600 /opt/stack/devstack/local.conf

echo
echo "=============================================================="
echo " Host preparado. Proximo passo (leva ~40-70 minutos):"
echo "   sudo -u stack -i"
echo "   cd devstack && ./stack.sh"
echo " Dica: rode dentro de 'tmux' para nao perder a sessao."
echo "=============================================================="
