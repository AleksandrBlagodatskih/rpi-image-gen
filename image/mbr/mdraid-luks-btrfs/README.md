# Image Layer: MBR Boot + MD RAID1 + LUKS2 + Btrfs

Этот слой создает образ Raspberry Pi с:
- **MBR загрузочным разделом** на SD карте
- **MD RAID1** на двух SATA SSD дисках
- **LUKS2 шифрованием** на RAID массиве
- **Btrfs файловой системой** на шифрованном контейнере

## Архитектура

```
SD Card (MBR)
├── Boot partition (VFAT) - /boot/firmware
│   ├── Kernel
│   ├── initramfs
│   └── LUKS keyfile
└── (No root partition on SD)

SATA SSD 1 & SSD 2
└── MD RAID1 (/dev/md0) [from mdraid.empty.img]
    └── GPT partition table
        └── Partition 1 (/dev/md0p1)
            └── LUKS2 container (/dev/mapper/cryptroot)
                └── Btrfs root filesystem (/) [from root.btrfs.img]

Build artifacts (created by genimage):
├── boot.vfat.img - Boot partition for SD card
├── mdraid.empty.img - Empty MD RAID1 container
└── root.btrfs.img - Btrfs root filesystem
```

## Использование

### Конфигурация

```yaml
device:
  layer: rpi5  # или другой device layer

image:
  layer: image-mbr-mdraid-luks-btrfs
  boot_part_size: 200M
  mdraid_devices: /dev/sda,/dev/sdb
  luks_keyfile: /boot/luks-key

layer:
  base: bookworm-minbase
  device: radxa-sata-penta-hat  # Required for SATA SSD support
  sys-apps: cryptsetup  # Required for LUKS encryption
  sys-apps: btrfs  # Required for Btrfs filesystem
  mdadm: mdadm  # Required for RAID support
  # другие необходимые слои
```

### Параметры

- `boot_part_size`: Размер загрузочного раздела на SD карте (по умолчанию: 200M)
- `mdraid_devices`: Список устройств для MD RAID1 через запятую (device names, менее надежно)
- `mdraid_uuids`: Список UUIDs дисков для MD RAID1 через запятую (более надежно, рекомендуется)
- `luks_keyfile`: Путь к файлу ключа LUKS на загрузочном разделе (по умолчанию: /boot/luks-key)

#### Выбор между device names и UUIDs

**Device names** (`/dev/sda,/dev/sdb`):
- Просты в использовании
- Могут изменяться при переподключении дисков
- Подходят для статических конфигураций

**UUIDs** (`12345678-1234-1234-1234-123456789012,...`):
- Более надежны, не зависят от порядка подключения
- Требуют предварительного определения UUIDs дисков
- Рекомендуются для production систем

```bash
# Получение UUID диска
blkid /dev/sda | grep UUID
# UUID="12345678-1234-1234-1234-123456789012"
```

### Сборка

```bash
# Using device names (simple)
rpi-image-gen build -c examples/config-mdraid-luks-btrfs.yaml

# Using UUIDs (recommended for production)
rpi-image-gen build -c examples/config-mdraid-luks-btrfs-uuids.yaml
```

## Процесс развертывания

1. **Сборка образов**: genimage создает SD карту + пустой MD RAID + Btrfs
2. **Запись SD карты**: Запишите SD образ на карту
3. **Provisioning**: Примените provisioning для создания LUKS на MD RAID и помещения Btrfs внутрь
4. **Первая загрузка**: Система автоматически расшифрует LUKS и соберет MD RAID

### Подробный процесс:

**Build time (genimage):**
- `boot.vfat` - загрузочный раздел для SD карты (MBR)
- `mdraid.empty` - пустой MD RAID1 контейнер
- `root.btrfs` - файловая система Btrfs

**Provisioning time:**
- `boot.vfat` записывается на SD карту (MBR partitioning)
- На `mdraid.empty` создается GPT таблица разделов
- В GPT создается раздел 1 (`/dev/md0p1`)
- LUKS применяется к разделу 1 → создается `/dev/mapper/cryptroot`
- Btrfs (`root.btrfs`) записывается внутрь LUKS контейнера

**Runtime:**
- При загрузке cryptsetup открывает LUKS
- mdadm собирает RAID из `/dev/mapper/cryptroot` (работает даже в degraded mode)
- Btrfs монтируется как корневая файловая система

## Provisioning

Для использования с provisioning системой:

```bash
# Генерация JSON описания
./bin/image2json -g genimage.cfg -f image.json

# Provisioning на устройство
./bin/idp.sh -f image.json
```

## Требования к оборудованию

- **Raspberry Pi 5** (обязательно для Radxa SATA Penta HAT)
- **Radxa SATA Penta HAT** - для подключения SATA SSD
- **SD карта** для загрузки (MBR partitioning)
- **Два SATA SSD диска** одинакового размера для RAID1
- **12V питание** для SATA HAT и дисков

## Настройка оборудования

### Radxa SATA Penta HAT

Для работы с SATA SSD дисками требуется настройка Radxa SATA Penta HAT:

```yaml
# В конфигурации добавить:
radxa_sata:
  pcie_gen3: y        # PCIe Gen 3.0 для максимальной производительности
  initramfs_sata: y   # Ранняя инициализация SATA в initramfs
```

### Подключение оборудования

1. **Подключите FFC кабель** между Pi 5 (разъем J6) и HAT
2. **Подключите SATA SSD** к портам HAT (используйте порты 1 и 2 для RAID1)
3. **Подключите 12V питание** к HAT (Molex или barrel jack)
4. **Вставьте SD карту** с образом в Pi 5
5. **Включите питание** системы

### Проверка дисков

После загрузки проверьте обнаружение дисков:

```bash
# Проверить SATA диски
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Проверить RAID статус (после provisioning)
cat /proc/mdstat

# Проверить LUKS контейнеры
lsblk -o NAME,TYPE,SIZE,MOUNTPOINT
```

## Безопасность

- LUKS2 с AES-256-XTS шифрованием
- Ключ шифрования хранится на загрузочном разделе
- MD RAID1 обеспечивает отказоустойчивость

## Отказоустойчивость

- **RAID1 зеркалирует данные** между двумя дисками
- **Degraded mode support** - система загружается даже при отказе одного диска
- **Горячая замена дисков** поддерживается
- **Автоматическое восстановление** при замене диска

## Производительность

- RAID1 обеспечивает хорошую производительность чтения
- Btrfs предоставляет современные возможности (snapshots, compression, etc.)
- LUKS добавляет минимальные накладные расходы на шифрование
