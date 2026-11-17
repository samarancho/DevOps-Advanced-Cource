#!/usr/bin/env bash
# Снимки ВМ стенда для провайдера qemu (vagrant-qemu не поддерживает `vagrant snapshot`).
# Использует внутренние снимки qcow2 (qemu-img snapshot). ВМ должны быть ВЫКЛЮЧЕНЫ.
#
#   ./snapshot-qemu.sh save    clean     # vagrant halt + снимок всех созданных ВМ
#   ./snapshot-qemu.sh restore clean     # vagrant halt + откат всех ВМ к снимку
#   ./snapshot-qemu.sh list
#   ./snapshot-qemu.sh delete  clean
set -euo pipefail
cd "$(dirname "$0")"

ACTION="${1:-list}"
NAME="${2:-}"
QEMU_IMG="$(command -v qemu-img || echo /opt/homebrew/bin/qemu-img)"

disks() {
  find .vagrant/machines -path '*/qemu/vq_*/linked-box.img' 2>/dev/null | sort
}

vm_of() { echo "$1" | cut -d/ -f3; }

[ -n "$(disks)" ] || { echo "ВМ на qemu не найдены (.vagrant/machines/*/qemu)"; exit 1; }

case "$ACTION" in
  save|restore|delete)
    [ -n "$NAME" ] || { echo "Укажите имя снимка: $0 $ACTION <имя>"; exit 1; }
    echo ">>> выключаем ВМ (vagrant halt)"
    vagrant halt
    ;;
esac

for d in $(disks); do
  vm=$(vm_of "$d")
  case "$ACTION" in
    save)    "$QEMU_IMG" snapshot -c "$NAME" "$d" && echo "$vm: снимок '$NAME' создан" ;;
    restore) "$QEMU_IMG" snapshot -a "$NAME" "$d" && echo "$vm: откат к '$NAME'" ;;
    delete)  "$QEMU_IMG" snapshot -d "$NAME" "$d" && echo "$vm: снимок '$NAME' удалён" ;;
    list)    echo "== $vm"; "$QEMU_IMG" snapshot -l "$d" | tail -n +3 ;;
    *)       echo "Неизвестное действие: $ACTION (save|restore|list|delete)"; exit 1 ;;
  esac
done

case "$ACTION" in
  save|restore) echo ">>> готово; запустите стенд: vagrant up" ;;
esac
