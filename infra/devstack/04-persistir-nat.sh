#!/usr/bin/env bash
# =====================================================================
# 04-persistir-nat.sh - torna permanentes (apos reboot) o ip_forward, o IP do br-ex
# e a regra MASQUERADE da rede publica do DevStack, sem iptables-persistent.
# Executar na vnes-cloud, na pasta infra/devstack:  sudo ./04-persistir-nat.sh
# =====================================================================
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "Execute com sudo." >&2; exit 1; }

echo "==> [1/3] sysctl.d (ip_forward)"
install -m 644 "$DIR/99-vnes-ipforward.conf" /etc/sysctl.d/99-vnes-ipforward.conf
sysctl --system >/dev/null

echo "==> [2/3] Unidade systemd vnes-nat.service"
install -m 644 "$DIR/vnes-nat.service" /etc/systemd/system/vnes-nat.service
systemctl daemon-reload
systemctl enable vnes-nat.service

echo "==> [3/3] Aplicando agora"
systemctl restart vnes-nat.service
systemctl is-enabled vnes-nat.service
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING | grep 172.24.4.0/24 || true
ip -4 addr show br-ex | grep inet || true
echo "Pronto."
