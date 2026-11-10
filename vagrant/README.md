# Учебный стенд курса «DevOps продвинутый: Kubernetes и CI/CD на основе GitLab»

## Состав стенда

| ВМ              | IP                        | CPU | RAM     | Назначение                                   |
|-----------------|---------------------------|-----|---------|----------------------------------------------|
| `mgmt`          | 192.168.56.10 | 1   | 1.5 GB  | Управляющая машина: Ansible, Kubespray |
| `master-1`      | 192.168.56.11 | 2   | 2.5 GB  | Control plane + etcd; здесь работаем с kubectl, helm, git |
| `worker-1`      | 192.168.56.21 | 2   | 4 GB    | Рабочий узел                                  |
| `worker-2`      | 192.168.56.22 | 2   | 4 GB    | Рабочий узел                                  |
| `gitlab-runner` | 192.168.56.31 | 2   | 1.5 GB  | GitLab Runner (поднимается с занятия 09)      |
| *MetalLB*       | 192.168.56.200–220 | — | —     | Внешние IP сервисов `LoadBalancer`: .200 — GitLab, .201–.220 — остальные |

ОС на всех ВМ — **Ubuntu 24.04**. Пользователь `vagrant`, пароль `vagrant`.

**Требования к компьютеру:** 4+ ядра, **16 GB RAM минимум** (рекомендуется 32 GB), 60 GB свободного места на диске, интернет.

---

## 1. Выберите провайдер под свою ОС

| Ваша ОС                          | Провайдер     | Что установить |
|----------------------------------|---------------|----------------|
| Windows 10/11                    | `virtualbox`  | VirtualBox 7.2+, Vagrant 2.4.9+ |
| Linux (Ubuntu, Fedora, …)        | `libvirt` (рекомендуется) или `virtualbox` | libvirt/KVM + плагин `vagrant-libvirt`, Vagrant 2.4.9+ |
| macOS Intel                      | `virtualbox`  | VirtualBox 7.2+, Vagrant 2.4.9+ |
| macOS Apple Silicon (M1–M4)      | `virtualbox`  | VirtualBox 7.2+ (сборка «macOS / Apple Silicon hosts»), Vagrant 2.4.9+ |
| macOS Apple Silicon (альтернатива, проверено на M3 Pro) | `qemu` | qemu, socket_vmnet, плагин `vagrant-qemu` 0.7.0+, Vagrant 2.4.9+ |

> Vagrant старше 2.4.9 не поддерживает VirtualBox 7.2 (ошибка «version of VirtualBox installed that is not supported»). Обновите Vagrant: https://developer.hashicorp.com/vagrant/install

### Windows
1. Установите [VirtualBox](https://www.virtualbox.org/wiki/Downloads) и [Vagrant](https://developer.hashicorp.com/vagrant/install).
2. Если включены Hyper-V / WSL2 / «Платформа виртуальной машины», VirtualBox будет работать медленно. Для курса лучше отключить их:
   `bcdedit /set hypervisorlaunchtype off` (PowerShell от администратора) и перезагрузиться.
3. Скачивайте стенд архивом или делайте `git clone` — файлы `*.sh` Vagrant сам переведёт в формат Unix.

### Linux (libvirt)
```bash
# Ubuntu / Debian
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-dev ebtables
sudo usermod -aG libvirt $USER     # перелогиньтесь после этой команды
vagrant plugin install vagrant-libvirt
```

### macOS Apple Silicon через qemu (если VirtualBox не подходит)
```bash
brew install qemu socket_vmnet
vagrant plugin install vagrant-qemu         # нужна версия 0.7.0+
vagrant plugin update vagrant-qemu
cd vagrant                                  # каталог стенда — там лежит файл службы

# Демон socket_vmnet должен раздавать подсеть стенда 192.168.56.0/24 (DHCP только .2–.9).
# ВАЖНО: `brew services start socket_vmnet` запускает его с подсетью 192.168.105.0/24 —
# с ней ВМ стенда друг друга НЕ видят. Остановите его и поставьте службу стенда:
sudo brew services stop socket_vmnet
sudo cp io.devops-lab.socket_vmnet.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/io.devops-lab.socket_vmnet.plist
pgrep -fl socket_vmnet          # должен быть ровно один процесс с --vmnet-gateway=192.168.56.1
# (служба стартует сама после перезагрузки Mac; убрать:
#  sudo launchctl bootout system /Library/LaunchDaemons/io.devops-lab.socket_vmnet.plist)
```

- Box для qemu — `crystax/ubuntu2404` (формат libvirt, arm64, диск 128 GB). У `bento/ubuntu-24.04` сборки libvirt для arm64 нет, а `cloud-image/ubuntu-24.04` под vagrant-qemu не отвечал по SSH.
- Если образ не применил статический IP сам, его настроит скрипт `scripts/common.sh` (netplan).
- Сетевые карты ВМ — `virtio-net-pci`: так `eth0` всегда NAT (через него ходит Vagrant), а `eth1` — сеть стенда.
- Служба socket_vmnet ставится **один раз**; в дни курса достаточно `vagrant up`.
- Если установлены и VirtualBox, и qemu — **обязательно** укажите провайдер (раздел 2), иначе выберется VirtualBox.

---

## 2. Укажите провайдер (обязательно!)

Vagrantfile выбирает box **в зависимости от провайдера**, поэтому его нужно указать явно — переменной окружения (удобнее, действует на все команды) или ключом `--provider`. Первая строка вывода `vagrant up` показывает, что выбрано:

```text
==> devops-lab: провайдер qemu, подсеть 192.168.56.0/24, box crystax/ubuntu2404
```

**Linux / macOS (bash, zsh):**
```bash
export VAGRANT_DEFAULT_PROVIDER=virtualbox     # или libvirt, или qemu
```

**Windows PowerShell:**
```powershell
$env:VAGRANT_DEFAULT_PROVIDER = "virtualbox"
```

**Windows cmd:**
```cmd
set VAGRANT_DEFAULT_PROVIDER=virtualbox
```

Либо так: `vagrant up --provider=libvirt`.

---

## 3. Запуск

```bash
cd vagrant
vagrant up                 # mgmt, master-1, worker-1, worker-2
vagrant status
vagrant ssh mgmt           # заходим на управляющую машину
```

ВМ `gitlab-runner` не стартует автоматически — она нужна с занятия 09:
```bash
vagrant up gitlab-runner
```

Проверка сети между машинами (все три должны ответить `OK`):
```bash
vagrant ssh mgmt -c 'for h in master-1 worker-1 worker-2; do ping -c1 -W1 $h >/dev/null && echo "$h OK" || echo "$h FAIL"; done'
```

### Полезные команды
| Команда | Что делает |
|---------|-----------|
| `vagrant halt` | выключить все ВМ (данные сохраняются) |
| `vagrant up` | включить снова |
| `vagrant snapshot save cluster-ok` | снимок всех ВМ (удобно после установки кластера) — VirtualBox, libvirt |
| `vagrant snapshot restore cluster-ok` | откат к снимку — VirtualBox, libvirt |
| `./snapshot-qemu.sh save cluster-ok` | то же для **qemu** (vagrant-qemu не умеет `vagrant snapshot`): выключит ВМ и сделает снимки дисков |
| `./snapshot-qemu.sh restore cluster-ok` / `list` | откат / список снимков на qemu |
| `vagrant destroy -f` | удалить стенд полностью |

---

## 4. Если ресурсов мало

Все параметры переопределяются переменными окружения **до** `vagrant up`:

| Переменная | По умолчанию | Описание |
|-----------|--------------|----------|
| `LAB_WORKER_MEM` | 4096 | RAM рабочих узлов, MB (GitLab в кластере требует ~6–7 GB на двоих) |
| `LAB_MASTER_MEM` | 2560 | RAM master-1, MB |
| `LAB_MGMT_MEM` | 1536 | RAM mgmt, MB |
| `LAB_RUNNER_MEM` | 1536 | RAM gitlab-runner, MB |
| `LAB_NET` | 192.168.56 | Префикс подсети (одинаковый для всех провайдеров) |
| `LAB_BOX` | bento/ubuntu-24.04 (qemu: crystax/ubuntu2404) | Box с Ubuntu 24.04 |

Пример: `LAB_WORKER_MEM=3584 vagrant up`.

Совет: на 16 GB закройте браузер с десятками вкладок и IDE перед установкой GitLab (занятие 07).

---

## 5. Частые проблемы

| Симптом | Причина и решение |
|---------|-------------------|
| `The box … doesn't support the provider you requested` / `could not be found` | Не тот провайдер или нет сборки box под вашу архитектуру. Проверьте строку `==> devops-lab: провайдер …` в начале вывода `vagrant up`; задайте провайдер явно или другой box: `LAB_BOX=<другой box> vagrant up` |
| qemu: ВМ стартует, но `vagrant up` висит на SSH / нет IP `192.168.56.x` | не запущен `socket_vmnet` (см. раздел 1) |
| Vagrant: «version of VirtualBox installed that is not supported» | Обновите Vagrant до 2.4.9+ |
| Что-то с сетью, непонятно что | Запустите `./diag.sh` в каталоге `vagrant/` — он соберёт адреса, маршруты и результаты ping всех ВМ в `diag.log` |
| qemu: ВМ не пингуют друг друга (`ip neigh` → FAILED) | `pgrep -fl socket_vmnet`: работает демон с другой подсетью (обычно `brew services`, 192.168.105.1). Остановите его, запустите службу стенда, затем `vagrant reload` |
| VirtualBox: `VERR_VMX_NO_VMX` / очень медленно на Windows | Отключите Hyper-V (см. выше), включите VT-x/AMD-V в BIOS |
| VirtualBox: ошибка host-only сети `192.168.56.x` | В `/etc/vbox/networks.conf` (Linux/macOS) должна быть строка `* 192.168.56.0/21` |
| libvirt: `Permission denied` | Пользователь не в группе `libvirt` — `sudo usermod -aG libvirt $USER` и перелогиниться |
| Скопировали каталог стенда с другого компьютера — «box not found» | Удалите скрытый каталог `.vagrant/` (в нём абсолютные пути старого пользователя) |
| `ssh-copy-id` просит пароль | Пароль `vagrant` |
| Не открывается `http://gitlab.192.168.56.200.nip.io` | Ваш роутер/DNS блокирует ответы с частными IP (DNS rebinding protection). Пропишите в hosts вашего компьютера: `192.168.56.200 gitlab.192.168.56.200.nip.io registry.192.168.56.200.nip.io` |
