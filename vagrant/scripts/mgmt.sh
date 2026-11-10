#!/usr/bin/env bash
# Управляющая машина (mgmt). Ставим только инструменты общего назначения.
# Ansible, Kubespray, kubectl и Helm устанавливаются на занятиях вручную —
# это часть учебной программы.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo ">>> [mgmt] git, python3-venv, make"
apt-get install -y -qq git python3-venv python3-pip make unzip sshpass >/dev/null

cat > /etc/motd <<'EOF'

  DevOps продвинутый курс — управляющая машина (mgmt)
  Отсюда мы ставим кластер (Kubespray). Работа с кластером (kubectl, helm) — на master-1.

  Переменные стенда: echo $LAB_NET $LB_IP $GITLAB_URL

EOF
echo ">>> [mgmt] готово"
