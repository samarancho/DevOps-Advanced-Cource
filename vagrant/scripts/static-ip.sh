#!/usr/bin/env bash
# Статический IP стенда на втором сетевом интерфейсе (для Hyper-V и образов без cloud-init).
#   $1 - IP этой ВМ, например 192.168.56.10
set -euo pipefail
MY_IP="${1:?нужен IP}"

if ip -4 -o addr show | grep -q " ${MY_IP}/"; then
  echo ">>> [static-ip] ${MY_IP} уже настроен"
  exit 0
fi

# ждём, пока появится второй интерфейс (на Hyper-V он подключается при старте ВМ)
DEF_IF=""; PRIV_IF=""
for _ in $(seq 1 30); do
  DEF_IF=$(ip route show default | awk '{print $5; exit}')
  PRIV_IF=$(ip -o link show | awk -F': ' '{print $2}' | cut -d@ -f1 | grep -v -E "^(lo|${DEF_IF})$" | head -1 || true)
  [ -n "$PRIV_IF" ] && break
  sleep 2
done
if [ -z "$PRIV_IF" ]; then
  echo ">>> [static-ip] второй сетевой интерфейс не найден - выполните vagrant reload" >&2
  exit 1
fi

echo ">>> [static-ip] ${MY_IP} на ${PRIV_IF} (netplan)"
PRIV_MAC=$(cat "/sys/class/net/${PRIV_IF}/address")
cat > /etc/netplan/60-devops-lab.yaml <<NETPLAN
network:
  version: 2
  ethernets:
    devops-lab:
      match:
        macaddress: "${PRIV_MAC}"
      addresses: ["${MY_IP}/24"]
NETPLAN
chmod 600 /etc/netplan/60-devops-lab.yaml
netplan apply
sleep 2
ip -4 -br addr
