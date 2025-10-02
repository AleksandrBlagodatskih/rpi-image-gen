# Использование официального Raspberry Pi OS Trixie как базы

**Дата:** 2 октября 2025  
**Версия OS:** Raspberry Pi OS Trixie (Debian 13)  
**Kernel:** Linux 6.12.47

---

## 🎯 Обзор

Вместо сборки образа с нуля, можно использовать **официальный образ Raspberry Pi OS Trixie** как базу и применить слои безопасности и RAID конфигурацию поверх него.

### ✨ Преимущества подхода:

1. **Быстрее** - не нужно собирать базовую систему с нуля
2. **Официальный образ** - протестирован и оптимизирован Raspberry Pi Foundation
3. **Все предустановлено** - firmware, драйвера, базовые утилиты
4. **Обновления** - легко получать обновления от upstream
5. **Надёжность** - проверенная конфигурация

---

## 📥 Доступные образы

### Raspberry Pi OS Trixie Lite (ARM64)

**Последний релиз:** 2025-10-01

**Ссылки:**
- Image: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
- SHA256: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256
- Release Notes: https://downloads.raspberrypi.com/raspios_lite_arm64/release_notes.txt

**Характеристики:**
- **Base:** Debian Trixie (13)
- **Kernel:** Linux 6.12.47
- **Architecture:** ARM64 (aarch64)
- **Size:** ~500 MB (compressed)
- **Compositor:** labwc (Wayland)
- **Applications:** Minimal set + Chromium 140.0 + Firefox 142.0

**Новое в 2025-10-01:**
- Новый Control Centre с plugin-based архитектурой
- Новая иконка тема PiXtrix
- Новые GTK темы (PiXtrix standard, PiXonyx dark)
- Новый шрифт Nunito Sans Light
- labwc 0.8.4 (Wayland compositor)
- Улучшенная поддержка клавиатуры
- Raspberry Pi firmware 676efed1194de38975889a34276091da1f5aadd3

---

## 🚀 Быстрый старт

### 1. Простая конфигурация с RAID1 и базовой безопасностью:

```bash
# Скопируйте пример конфигурации
cp examples/trixie-raid-security-simple.yaml my-config.yaml

# Соберите образ
./rpi-image-gen build -c my-config.yaml
```

**Что получится:**
- Официальный Raspberry Pi OS Trixie Lite
- RAID1 с f2fs для продления срока службы SD карт
- Security Suite (AppArmor, Fail2Ban, UFW, автообновления)
- LUKS2 шифрование

### 2. Enterprise конфигурация с полной безопасностью:

```bash
# Используйте enterprise конфигурацию
./rpi-image-gen build -c examples/trixie-raid-security-enterprise.yaml
```

**Что получится:**
- Все из простой конфигурации +
- Comprehensive auditd мониторинг
- Cockpit web-интерфейс управления
- Distrobox для контейнеризации
- Строгие password policies
- Compliance monitoring (CIS, PCI-DSS, HIPAA, GDPR)
- TPM key storage (если доступен)

---

## 📝 Конфигурационные файлы

### Базовая структура конфигурации:

```yaml
# Device configuration
device:
  layer: rpi5  # или rpi4, rpi-cm5, etc.

# Image configuration
image:
  layer: mdraid1-external-root
  name: my-trixie-image
  
  # Официальный образ как база
  base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
  
  # RAID конфигурация
  mdraid1_external_root_rootfs_type: f2fs  # ext4, btrfs, f2fs
  mdraid1_external_root_raid_level: RAID1
  mdraid1_external_root_raid_devices: 2
  mdraid1_external_root_encryption_enabled: y

# Применить слои безопасности
layers:
  - security-suite  # Комплексная безопасность
  # или индивидуальные компоненты:
  # - apparmor
  # - auditd
  # - fail2ban
  # - ufw
  # - unattended-upgrades

# Настройки безопасности
security:
  apparmor_enabled: y
  fail2ban_enabled: y
  ufw_enabled: y
  unattended_upgrades_enabled: y
```

---

## 🔒 SHA256 Verification

Для безопасности **настоятельно рекомендуется** проверять SHA256 checksum:

### Автоматическая проверка (рекомендуется):

```yaml
image:
  base_image_url: https://downloads.raspberrypi.com/.../image.img.xz
  base_image_sha256_url: https://downloads.raspberrypi.com/.../image.img.xz.sha256
```

### Ручная проверка:

```yaml
image:
  base_image_url: https://downloads.raspberrypi.com/.../image.img.xz
  base_image_sha256: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd"
```

Подробнее см. [SHA256 Verification Guide](./SHA256_VERIFICATION.md).

---

## 🔧 Применение слоёв

### Автоматический способ (рекомендуется):

```bash
# 1. Создайте конфигурацию
cat > my-trixie.yaml << 'EOF'
device:
  layer: rpi5

image:
  layer: mdraid1-external-root
  name: my-secure-raid
  base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
  mdraid1_external_root_rootfs_type: f2fs
  mdraid1_external_root_raid_level: RAID1
  mdraid1_external_root_raid_devices: 2
  mdraid1_external_root_encryption_enabled: y

layers:
  - security-suite
EOF

# 2. Соберите образ
./rpi-image-gen build -c my-trixie.yaml

# 3. Образ будет в work/
ls -lh work/image-*/
```

### Ручной способ (для кастомизации):

```bash
# 1. Скачайте базовый образ
mkdir -p cache
cd cache
wget https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz

# 2. Распакуйте
xz -d 2025-10-01-raspios-trixie-arm64-lite.img.xz

# 3. Примените слои вручную
./scripts/apply-layers-to-base-image.sh config/trixie-raid-security.yaml
```

---

## 🎯 Сценарии использования

### 1. Домашний сервер с безопасностью:

```yaml
device:
  layer: rpi5

image:
  layer: mdraid1-external-root
  base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
  mdraid1_external_root_rootfs_type: f2fs
  mdraid1_external_root_raid_devices: 2
  mdraid1_external_root_encryption_enabled: y

layers:
  - security-suite
  - cockpit  # Веб-интерфейс управления

security:
  ufw_allow_ssh: y
  ufw_ssh_port: 2222  # Нестандартный порт SSH
  fail2ban_enabled: y
  unattended_upgrades_enabled: y
```

### 2. IoT edge gateway с контейнерами:

```yaml
device:
  layer: rpi4

image:
  layer: mdraid1-external-root
  base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
  mdraid1_external_root_rootfs_type: f2fs
  mdraid1_external_root_raid_devices: 2

layers:
  - security-suite
  - distrobox  # Контейнеризация

security:
  apparmor_enabled: y
  ufw_enabled: y
  # Разрешить MQTT, Node-RED
  ufw_custom_rules:
    - allow 1883/tcp  # MQTT
    - allow 1880/tcp  # Node-RED
```

### 3. Enterprise production system:

```yaml
device:
  layer: rpi-cm5
  variant: 8G

image:
  layer: mdraid1-external-root
  base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
  mdraid1_external_root_rootfs_type: f2fs
  mdraid1_external_root_raid_devices: 2
  mdraid1_external_root_encryption_enabled: y
  mdraid1_external_root_key_method: tpm
  mdraid1_external_root_sector_size: 4096

layers:
  - security-suite
  - cockpit
  - distrobox

security:
  # Strict enterprise security
  apparmor_enabled: y
  apparmor_enforce_mode: enforce
  auditd_enabled: y
  auditd_compliance_monitoring: y
  fail2ban_enabled: y
  fail2ban_destemail: security@company.com
  ufw_enabled: y
  ufw_default_policy: deny
  password_min_length: 16
  password_max_age: 90
  
compliance:
  generate_sbom: y
  scan_vulnerabilities: y
  cis_benchmark: y
  pci_dss: y
  hipaa: y
```

---

## 📊 Сравнение подходов

| Параметр | Сборка с нуля | Базовый образ + слои |
|----------|---------------|----------------------|
| **Время сборки** | 30-60 минут | 5-10 минут |
| **Размер** | Минимальный | Стандартный |
| **Обновления** | Ручные | Автоматические |
| **Совместимость** | Полная контроль | Следует upstream |
| **Сложность** | Высокая | Низкая |
| **Поддержка** | Ваша | Raspberry Pi Foundation |

---

## ⚙️ Технические детали

### Базовый образ Trixie включает:

**Системные компоненты:**
- Linux kernel 6.12.47
- systemd
- Raspberry Pi firmware (latest)
- Device Tree overlays
- GPU drivers

**Networking:**
- NetworkManager
- dhcpcd
- wpa_supplicant
- Bluetooth stack

**Development:**
- gcc, make, build-essential
- Python 3.12
- Git

**Utilities:**
- sudo, ssh, rsync
- vim, nano
- curl, wget

**Applications:**
- Chromium 140.0.7339.185
- Firefox 142.0.1

### Слои безопасности добавляют:

**Security Suite:**
- AppArmor profiles
- auditd rules
- Fail2Ban filters
- UFW firewall rules
- PAM modules
- Sysctl parameters
- Unattended-upgrades config

**RAID Configuration:**
- mdadm tools
- f2fs-tools / e2fsprogs / btrfs-progs
- LUKS2 encryption
- Initramfs hooks

---

## 🔍 Проверка результата

После сборки образа:

```bash
# 1. Проверить размер
ls -lh work/image-*/

# 2. Проверить структуру
fdisk -l work/image-*/*.img

# 3. Монтировать и проверить содержимое
sudo losetup -fP work/image-*/*.img
sudo mount /dev/loop0p2 /mnt
ls -la /mnt/
sudo umount /mnt
sudo losetup -d /dev/loop0
```

### После установки на устройство:

```bash
# Проверить версию OS
cat /etc/os-release

# Проверить kernel
uname -a

# Проверить RAID
cat /proc/mdstat

# Проверить файловую систему
df -T /

# Проверить безопасность
sudo aa-status           # AppArmor
sudo fail2ban-client status  # Fail2Ban
sudo ufw status          # Firewall
sudo auditctl -s         # Auditd
```

---

## 🐛 Troubleshooting

### Проблема: Образ не скачивается

**Решение:**
```bash
# Проверьте соединение
ping raspberrypi.com

# Попробуйте вручную
wget https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz

# Используйте зеркало
BASE_IMAGE_URL="https://mirror.example.com/raspios/..." ./rpi-image-gen build -c config.yaml
```

### Проблема: Нехватка места

**Решение:**
```bash
# Очистите кеш
rm -rf cache/*.img
rm -rf work/

# Используйте внешний диск
export CACHE_DIR=/mnt/external/cache
export WORK_DIR=/mnt/external/work
```

### Проблема: Слои не применяются

**Решение:**
```bash
# Проверьте синтаксис конфигурации
./rpi-image-gen config --validate my-config.yaml

# Проверьте доступность слоёв
./rpi-image-gen layer --list

# Используйте отладку
./rpi-image-gen build -c my-config.yaml --debug
```

---

## 📚 Дополнительные ресурсы

### Официальная документация:
- Raspberry Pi OS: https://www.raspberrypi.com/software/
- Release Notes: https://downloads.raspberrypi.com/raspios_lite_arm64/release_notes.txt
- rpi-image-gen: docs/index.adoc

### Примеры конфигураций:
- `examples/trixie-raid-security-simple.yaml` - базовая
- `examples/trixie-raid-security-enterprise.yaml` - enterprise
- `config/trixie-raid-security.yaml` - полная

### Слои безопасности:
- `layer/security/` - все компоненты безопасности
- `layer/security/example-config.yaml` - примеры настроек

---

## ✅ Checklist перед использованием

- [ ] Скачан официальный образ Trixie
- [ ] Проверена checksum образа
- [ ] Создана конфигурация с нужными слоями
- [ ] Настроены параметры безопасности
- [ ] Настроен RAID (если нужен)
- [ ] Протестирована сборка
- [ ] Проверена работа на устройстве
- [ ] Документирована конфигурация

---

**Обновлено:** 2 октября 2025  
**Версия документа:** 1.0.0

