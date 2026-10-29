#!/usr/bin/env bash
# =====================================================================
# 05-autostart.sh - garante que a nuvem volte sozinha depois de religar a vnes-cloud:
#  - nova-compute religa as instancias que estavam ligadas (resume_guests_state_on_host_boot)
#  - todas as unidades devstack@*.service habilitadas no boot
#  - vnes-nat.service depois do OVS/OVN (reaplica IP do br-ex e MASQUERADE)
# Executar na vnes-cloud, na pasta infra/devstack:  sudo ./05-autostart.sh
# (rode antes o 04-persistir-nat.sh se a unidade vnes-nat ainda nao existir)
# =====================================================================
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "Execute com sudo." >&2; exit 1; }

echo "==> [1/3] nova-cpu.conf: resume_guests_state_on_host_boot = True"
CONF=/etc/nova/nova-cpu.conf
if grep -q '^resume_guests_state_on_host_boot' "$CONF"; then
  sed -i 's/^resume_guests_state_on_host_boot.*/resume_guests_state_on_host_boot = True/' "$CONF"
else
  sed -i '0,/^\[DEFAULT\]/s//[DEFAULT]\nresume_guests_state_on_host_boot = True/' "$CONF"
fi
grep -n resume_guests "$CONF"

echo "==> [2/3] Habilitando devstack@*.service e dependencias no boot"
systemctl list-unit-files 'devstack@*' --no-legend | awk '{print $1}' | xargs -r systemctl enable >/dev/null 2>&1 || true
systemctl enable openvswitch-switch ovn-ovsdb-server-nb ovn-ovsdb-server-sb libvirtd apache2 mysql rabbitmq-server memcached >/dev/null 2>&1 || true

echo "==> [3/3] vnes-nat.service (ordem apos OVS/OVN)"
install -m 644 "$DIR/vnes-nat.service" /etc/systemd/system/vnes-nat.service
systemctl daemon-reload
systemctl enable vnes-nat.service
systemctl restart vnes-nat.service
systemctl is-enabled vnes-nat.service
ip -4 addr show br-ex | grep inet || true
iptables -t nat -S POSTROUTING | grep 172.24.4.0/24 || true
echo "Pronto. (nova-compute le o novo valor no proximo boot ou: sudo systemctl restart devstack@n-cpu)"
