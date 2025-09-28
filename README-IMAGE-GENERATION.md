# Генерация образов в rpi-image-gen без реальных дисков

## Обзор процесса

rpi-image-gen генерирует образы в два этапа:
1. **Filesystem Generation** - создание корневой файловой системы
2. **Image Generation** - генерация .img файлов с разделами

Для получения только образов прошивки не нужны реальные диски - весь процесс происходит на рабочей станции.

## Опции сборки

```bash
# Только filesystem (без генерации образов)
./rpi-image-gen build -c config.yaml -f

# Только генерация образов (filesystem должна быть готова)
./rpi-image-gen build -c config.yaml -i

# Полная сборка (filesystem + образы)
./rpi-image-gen build -c config.yaml
```

## Примеры конфигураций

### Базовый образ (image-rpios)

```yaml
# minimal-config.yaml
device:
  layer: rpi5
  hostname: test-device

image:
  layer: image-rpios      # Базовый слой с boot + root
  name: test-image
  rootfs_type: ext4

layer:
  base: bookworm-minbase
```

### RAID overlay образ

```yaml
# raid-config.yaml
device:
  layer: rpi5
  hostname: raid-device

image:
  layer: raid             # RAID overlay слой
  name: raid-test
  rootfs_type: ext4

raid:
  level: RAID1            # RAID0 или RAID1
  devices: 2              # Количество external дисков
  sdcard_size: 200M       # Размер SD card
  external_size: 1G       # Размер на external диске

layer:
  base: bookworm-minbase
```

## Процесс генерации образов

### Этап 1: Создание filesystem

```bash
./rpi-image-gen build -c minimal-config.yaml -f
```

Этот этап:
- Загружает все слои и зависимости
- Создает Debian chroot в `work/chroot-*/filesystem/`
- Устанавливает пакеты и настраивает систему
- Выполняет все bdebstrap хуки

### Этап 2: Генерация образов

```bash
./rpi-image-gen build -c minimal-config.yaml -i
```

Этот этап:
- Вызывает pre-image хуки
- Генерирует genimage.cfg из шаблонов
- Запускает genimage для создания .img файлов
- Создает sparse образы для эффективного хранения

### Финальные артефакты

```bash
# Найти все сгенерированные образы
find work -name "*.img" -o -name "*.sparse"

# Структура для базового образа:
work/image-test-image/
├── test-image.img         # Основной образ для прошивки
├── test-image.img.sparse  # Sparse версия
├── boot.vfat.sparse       # Boot раздел
└── root.ext4.sparse       # Root раздел

# Структура для RAID overlay:
work/image-raid-test/
├── sdcard.img            # SD card с boot разделом
├── sdcard.img.sparse
├── external1.img         # External диск 1
├── external1.img.sparse
├── external2.img         # External диск 2
├── external2.img.sparse
├── raid1.ext4.sparse     # RAID filesystem
└── raid_config.sh        # RAID setup скрипт
```

## Использование образов

### Для базового образа:

```bash
# Записать на SD card
dd if=work/image-test-image/test-image.img of=/dev/sdX bs=4M

# Или с прогресс-баром
dd if=work/image-test-image/test-image.img of=/dev/sdX bs=4M status=progress
```

### Для RAID overlay:

```bash
# SD card
dd if=work/image-raid-test/sdcard.img of=/dev/mmcblk0 bs=4M

# External диски
dd if=work/image-raid-test/external1.img of=/dev/sda bs=4M
dd if=work/image-raid-test/external2.img of=/dev/sdb bs=4M
```

## Troubleshooting

### Проблема: Сборка останавливается на filesystem

**Причина:** Отсутствие интернета для загрузки пакетов

**Решение:**
```bash
# Проверить доступ к репозиториям
ping -c 3 deb.debian.org

# Или использовать локальный mirror
echo 'deb http://localhost:3142/debian bookworm main' > /etc/apt/sources.list.d/local-mirror.list
```

### Проблема: Genimage не может создать образы

**Причина:** Недостаточно места на диске или неправильные пути

**Решение:**
```bash
# Проверить свободное место
df -h work/

# Проверить genimage.cfg
cat work/image-*/genimage.cfg

# Запустить genimage вручную для отладки
genimage -c work/image-*/genimage.cfg
```

### Проблема: Образы не находятся

**Причина:** Сборка не дошла до этапа генерации образов

**Решение:**
```bash
# Проверить логи последней сборки
tail -f work/*/build.log

# Запустить только генерацию образов
./rpi-image-gen build -c config.yaml -i
```

## Оптимизация для быстрой генерации

### Использование sparse образов

Sparse образы эффективнее для хранения и передачи:
```bash
# Sparse образы создаются автоматически
ls -lh work/image-*.img.sparse

# Конвертировать в обычный образ при необходимости
cp work/image-test.img.sparse work/image-test.img
```

### Кеширование

```bash
# APT кеш сохраняется между сборками
ls -la work/keys/
ls -la work/host/

# Очистка кеша при необходимости
./rpi-image-gen clean
```

## Автоматизация

### Скрипт для пакетной генерации

```bash
#!/bin/bash
# batch-build.sh

CONFIGS=("minimal-config.yaml" "raid-config.yaml" "desktop-config.yaml")

for config in "${CONFIGS[@]}"; do
    echo "Building $config..."

    # Создать filesystem
    ./rpi-image-gen build -c "$config" -f

    # Создать образы
    ./rpi-image-gen build -c "$config" -i

    # Проверить результат
    if find work -name "*.img" | grep -q .; then
        echo "✓ $config: SUCCESS"
    else
        echo "✗ $config: FAILED"
    fi
done
```

## Архитектура образов

### Базовый образ (image-rpios)

```
+-----------------------------------+
| MBR Partition Table               |
+-----------------------------------+
| Boot Partition (vfat)             | 100M-500M
| - bootcode.bin                    |
| - config.txt                      |
| - cmdline.txt                     |
| - kernel.img                      |
+-----------------------------------+
| Root Partition (ext4/btrfs)       | Остальное место
| - Debian filesystem               |
| - /etc/fstab                      |
| - /boot/firmware -> boot part     |
+-----------------------------------+
```

### RAID overlay образы

```
SD Card:
+-----------------------------------+
| MBR Partition Table               |
+-----------------------------------+
| Boot Partition (vfat)             | 200M
| - bootcode.bin                    |
| - config.txt                      |
| - cmdline.txt                     |
| - kernel.img                      |
+-----------------------------------+

External Drive 1:
+-----------------------------------+
| RAID1 Partition 1 (ext4)          | 1G+
| - Часть RAID массива             |
+-----------------------------------+

External Drive 2:
+-----------------------------------+
| RAID1 Partition 2 (ext4)          | 1G+
| - Часть RAID массива             |
+-----------------------------------+

RAID Array (/dev/md0):
+-----------------------------------+
| Root Filesystem (ext4/btrfs)      |
| - Debian с RAID поддержкой       |
| - /etc/mdadm/mdadm.conf           |
| - RAID monitoring tools          |
+-----------------------------------+
```

## Заключение

rpi-image-gen позволяет создавать образы для прошивки полностью на рабочей станции без необходимости подключения реальных дисков. Процесс разделен на этапы, что позволяет гибко управлять сборкой и отлаживать проблемы.
