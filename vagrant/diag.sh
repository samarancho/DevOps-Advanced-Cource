#!/usr/bin/env bash
# Диагностика сети стенда: ./diag.sh  -> результат в diag.log
cd "$(dirname "$0")"
{
  echo "=== host: qemu NICs"
  pgrep -fl qemu-system | grep -o -E "mac=[0-9a-f:]+|addr.path=[^ ]+|debug_port|port=333[0-9]+" | paste - - - - - 2>/dev/null
  echo "=== host: socket_vmnet"
  pgrep -fl socket_vmnet
  ls -l /opt/homebrew/var/run/socket_vmnet
  for vm in mgmt master-1 worker-1 worker-2; do
    echo; echo "=================== $vm"
    vagrant ssh "$vm" -c 'hostname; ip -br link; ip -4 -br addr; ip route; ls /etc/netplan; sudo cat /etc/netplan/*.yaml; ping -c2 -W1 192.168.56.1; ping -c2 -W1 192.168.56.10; ip neigh' 2>&1
  done
} > diag.log 2>&1
echo "Готово: $(pwd)/diag.log"
