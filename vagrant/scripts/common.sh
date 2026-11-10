#!/usr/bin/env bash
# Общая подготовка всех ВМ стенда.
#   $1 — префикс подсети, например 192.168.56
#   $2 — список "ip:hostname,ip:hostname,..."
set -euo pipefail

NET="${1:?нужен префикс подсети}"
HOSTS="${2:?нужен список хостов}"
MY_IP="${3:-}"
LB_IP="${NET}.200"

export DEBIAN_FRONTEND=noninteractive

# Подстраховка для qemu: если образ не применил статический IP (нет cloud-init / другой
# формат сети), настраиваем его сами через netplan на втором интерфейсе.
if [ -n "$MY_IP" ] && ! ip -4 -o addr show | grep -q " ${MY_IP}/"; then
  DEF_IF=$(ip route show default | awk '{print $5; exit}')
  PRIV_IF=$(ip -o link show | awk -F': ' '{print $2}' | cut -d@ -f1 | grep -v -E "^(lo|${DEF_IF})$" | head -1)
  if [ -n "$PRIV_IF" ]; then
    echo ">>> [common] статический IP ${MY_IP} на ${PRIV_IF} (netplan)"
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
  fi
fi
ip -4 -br addr

echo ">>> [common] $(hostname): базовые пакеты"
apt-get update -qq
apt-get install -y -qq curl ca-certificates vim bash-completion jq tree net-tools >/dev/null

echo ">>> [common] часовой пояс"
timedatectl set-timezone Asia/Almaty || true

echo ">>> [common] /etc/hosts"
# Vagrant пишет "127.0.x.1 <hostname>" — kubelet и etcd не должны резолвить имя узла в loopback
sed -i "/^127\.0\.[0-9]\.1[[:space:]].*$(hostname)/d" /etc/hosts
sed -i '/# BEGIN devops-lab/,/# END devops-lab/d' /etc/hosts
{
  echo "# BEGIN devops-lab"
  IFS=',' read -ra PAIRS <<< "$HOSTS"
  for pair in "${PAIRS[@]}"; do
    echo "${pair%%:*} ${pair##*:}"
  done
  echo "# END devops-lab"
} >> /etc/hosts

echo ">>> [common] вход по паролю для пользователя vagrant (нужен для ssh-copy-id)"
echo 'vagrant:vagrant' | chpasswd
# В sshd побеждает ПЕРВОЕ найденное значение, а облачные образы кладут
# 60-cloudimg-settings.conf с "PasswordAuthentication no" — поэтому наш файл с префиксом 01-
cat > /etc/ssh/sshd_config.d/01-devops-lab.conf <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
systemctl restart ssh

echo ">>> [common] переменные стенда"
cat > /etc/profile.d/devops-lab.sh <<EOF
# Переменные учебного стенда
export LAB_NET="${NET}"
export LB_IP="${LB_IP}"
export GITLAB_DOMAIN="${LB_IP}.nip.io"
export GITLAB_URL="http://gitlab.${LB_IP}.nip.io"
export REGISTRY="registry.${LB_IP}.nip.io"
EOF
chmod 0644 /etc/profile.d/devops-lab.sh

echo ">>> [common] готово: $(hostname)"
