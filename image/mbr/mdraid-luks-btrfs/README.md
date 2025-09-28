# Image Layer: MBR Boot + MD RAID1 + LUKS2 + Btrfs + Swap (Server Optimized)

Этот слой создает **enterprise-оптимизированный** образ Raspberry Pi согласно [Debian mkfs.btrfs man page](https://manpages.debian.org/trixie/btrfs-progs/mkfs.btrfs.8.en.html) с:
- **MBR загрузочным разделом** на SD карте
- **MD RAID1** на двух SATA SSD дисках
- **LUKS2 шифрованием** на RAID массиве
- **Btrfs файловой системой с субтомами** на шифрованном контейнере
- **Encrypted swap** на отдельном Btrfs разделе
- **Server-grade оптимизациями** для enterprise workloads

## Архитектура

```
SD Card (MBR)
├── Boot partition (VFAT) - /boot/firmware
│   ├── Kernel
│   ├── initramfs
│   └── LUKS keyfile
└── (No root partition on SD)

SATA SSD 1 & SSD 2
└── MD RAID1 (/dev/md0) [from mdraid.empty.img, 4K sectors]
    └── GPT partition table
        └── Partition 1 (/dev/md0p1)
            └── LUKS2 container (/dev/mapper/cryptroot)
                └── Btrfs root filesystem [from root.btrfs.img, 4K sectors]
                    ├── @ (root subvolume) - /
                    ├── @home - /home
                    ├── @var - /var
                    ├── @srv - /srv
                    ├── @opt - /opt
                    ├── @tmp - /tmp
                    └── @swap (swap subvolume, nocow) - /swap
                        └── swapfile (encrypted swap)

Build artifacts (created by genimage):
├── boot.vfat.img - Boot partition for SD card
├── mdraid.empty.img - Empty MD RAID1 container
└── root.btrfs.img - Btrfs root filesystem with all subvolumes
```

## Использование

### Конфигурация

```yaml
device:
  layer: rpi5  # или другой device layer

image:
  layer: image-mbr-mdraid-luks-btrfs
  boot_part_size: 200M
  swap_size: 8G  # Размер swap файла (по умолчанию 8G)
  mdraid_devices: /dev/sda,/dev/sdb
  luks_keyfile: /boot/luks-key

layer:
  base: bookworm-minbase
  device: radxa-sata-penta-hat  # Required for SATA SSD support
  sys-apps: cryptsetup  # Required for LUKS encryption
  sys-apps: btrfs  # Required for Btrfs filesystem
  mdadm: mdadm  # Required for RAID support
  docker: docker-debian-bookworm  # Optional: Docker with Btrfs optimizations
  # или
  docker: docker-debian-trixie    # Optional: Docker with Btrfs optimizations
  # другие необходимые слои
```

### Параметры

- `boot_part_size`: Размер загрузочного раздела на SD карте (по умолчанию: 200M)
- `swap_size`: Размер swap файла на Btrfs (по умолчанию: 8G)
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
- `root.btrfs` - файловая система Btrfs со всеми субтомами (включая @swap)

**Provisioning time:**
- `boot.vfat` записывается на SD карту (MBR partitioning)
- На `mdraid.empty` создается GPT таблица разделов
- В GPT создается раздел 1 (`/dev/md0p1`)
- LUKS применяется к разделу → `/dev/mapper/cryptroot`
- Btrfs (`root.btrfs`) записывается в cryptroot

**Runtime:**
- При загрузке cryptsetup открывает LUKS контейнер
- mdadm собирает RAID (работает даже в degraded mode)
- Systemd монтирует все субтома включая @swap
- Swap файл создается и активируется на nocow субтоме
- Btrfs монтируется с оптимизациями для сервера

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

## Docker оптимизации

При включении Docker engine слоев (`docker-debian-bookworm` или `docker-debian-trixie`) автоматически применяются оптимизации для Btrfs:

### Минималистичный набор Docker Btrfs оптимизаций (rootfs-overlay)

#### daemon.json - базовые настройки
```json
{
  "storage-driver": "btrfs",
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ]
}
```

**Ключевые оптимизации:**
- **Btrfs storage driver**: Нативная поддержка Btrfs для containers
- **Systemd cgroup driver**: интеграция с systemd

#### Systemd оптимизации
- **Systemd integration**: правильная интеграция с systemd
- **Temporary directory**: оптимизация временных файлов

#### Структура rootfs-overlay
```
rootfs-overlay/
├── etc/
│   └── docker/
│       └── daemon.json          # Базовые настройки Docker
```

**Примечание**: Все файлы применяются автоматически через rootfs-overlay только при наличии Docker provider.

### Преимущества Btrfs для Docker
- **Copy-on-Write**: эффективное использование пространства
- **Snapshots**: быстрые контейнерные snapshots
- **Subvolumes**: изоляция контейнеров
- **Compression**: автоматическое сжатие слоев образов

### Использование
```yaml
layer:
  docker: docker-debian-bookworm  # Автоматически оптимизирует daemon.json для Btrfs
```

## Server Optimizations

### Btrfs Server Optimizations

Конфигурация оптимизирована для **enterprise server workloads** согласно [Debian mkfs.btrfs man page](https://manpages.debian.org/trixie/btrfs-progs/mkfs.btrfs.8.en.html):

#### Data & Metadata Profiles
- **Default profiles**: Single data, DUP metadata (оптимально для SSD)
- **Избегание RAID5/6**: Нестабильны для production (per man page warnings)
- **SSD optimization**: DUP не нужен на SSD из-за внутренней deduplication

#### Advanced Features (per mkfs.btrfs)
- **BLAKE2 checksums**: Более сильная integrity чем CRC32C (default)
- **32K nodesize**: Оптимизировано для server workloads, уменьшает фрагментацию
- **ZSTD:3 compression**: Быстрое сжатие с хорошим коэффициентом для server data
- **Free-space-tree**: Современный space_cache=v2 (default в kernel 5.15+)
- **Extref**: Поддержка >64K hardlinks (enterprise requirement)

#### Subvolume Layout
Серверная структура субтомов для enterprise workloads:
- **@** (default): Корневая файловая система
- **@home**: Домашние директории пользователей
- **@var**: Переменные данные (logs, databases, etc.)
- **@srv**: Server data (/srv)
- **@opt**: Опциональное ПО (/opt)
- **@tmp**: Временные файлы (/tmp)
- **@swap**: Swap субтом (nocow, без compression для swapfile)

### Mount Options
Все субтома монтируются с оптимизациями для SSD и server workloads (сжатие отключено для максимальной производительности):
```
ssd,noatime,nodiratime,space_cache=v2
```

**Оптимизированные mount options:**
- **@ (root)**: `ssd,autodefrag` - система с авто-дефрагментацией (без сжатия)
- **@home, @srv, @opt, @tmp**: `ssd` - пользовательские данные (без сжатия для performance)
- **@var**: `ssd` - логи и базы данных (без сжатия для performance)
- **@swap**: `nocompress,ssd` - swap без сжатия для максимальной производительности

### Enterprise fstab Configuration

Полная конфигурация fstab оптимизирована для enterprise server:

```bash
# Boot partition (VFAT) - external SD card
UUID=<BOOT_UUID> /boot/firmware vfat defaults,noatime,nodiratime,flush,umask=0077 0 2

# Root filesystem - Btrfs subvolumes with encryption (no compression)
UUID=<CRYPT_UUID> /      btrfs defaults,subvol=@,ssd,noatime,nodiratime,space_cache=v2,autodefrag 0 0
UUID=<CRYPT_UUID> /home  btrfs defaults,subvol=@home,ssd,noatime,nodiratime,space_cache=v2 0 0
UUID=<CRYPT_UUID> /var   btrfs defaults,subvol=@var,ssd,noatime,nodiratime,space_cache=v2 0 0
UUID=<CRYPT_UUID> /srv   btrfs defaults,subvol=@srv,ssd,noatime,nodiratime,space_cache=v2 0 0
UUID=<CRYPT_UUID> /opt   btrfs defaults,subvol=@opt,ssd,noatime,nodiratime,space_cache=v2 0 0
UUID=<CRYPT_UUID> /tmp   btrfs defaults,subvol=@tmp,ssd,noatime,nodiratime,space_cache=v2 0 0

# Swap subvolume - optimized for performance
UUID=<CRYPT_UUID> /swap  btrfs defaults,subvol=@swap,nocompress,ssd,noatime,nodiratime,space_cache=v2 0 0

# Swap file - created by systemd service
/swap/swapfile none swap sw,pri=0,discard=once 0 0
```

### mkfs.btrfs Command Reference

Финальная команда mkfs.btrfs + genimage inode-flags:
```bash
# 1. Создание filesystem:
mkfs.btrfs -U <BTRFS_UUID> \
           --csum blake2 \
           -n 32768 \
           -s 4096 \
           -O free-space-tree,extref \
           /dev/mapper/cryptroot

# 2. Создание subvolumes (через genimage):
btrfs subvolume create /mnt/@swap
# ... остальные subvolumes

# 3. Установка inode flags (через genimage --inode-flags):
chattr +C /mnt/@swap  # nodatacow для swap
```

**Объяснение параметров:**
- `Default profiles`: single data, DUP metadata (оптимально для SSD, per man page)
- `--csum blake2`: BLAKE2 checksums (сильнее CRC32C)
- `-n 32768`: 32K nodesize (оптимально для server workloads)
- `-s 4096`: 4K sectorsize (SSD-aligned, kernel-compatible)
- `No compression`: Отключено для максимальной I/O производительности
- `-O free-space-tree,extref`: Современные features для enterprise use
- `--inode-flags nodatacow:@swap`: Отключает COW для swap субтома

### Genimage --inode-flags: Продвинутые оптимизации

**inode-flags** - это мощная функция genimage для установки inode флагов Btrfs на уровне файловой системы. В отличие от `chattr`, который применяется к существующим файлам, `inode-flags` устанавливается при создании файловой системы.

#### Как работает --inode-flags:

```bash
# Синтаксис:
inode-flags = "nodatacow:/path/to/directory"
inode-flags = "nodatacow,nodatasum:/path/to/directory"

# Поддерживаемые флаги:
# - nodatacow: Отключает COW (copy-on-write) для данных
# - nodatasum: Отключает checksums данных (без отключения COW)
# - Комбинация: "nodatacow,nodatasum:/path" - максимальная производительность
```

#### Наследование флагов:

```
rootfs/
├── @swap/          ← inode-flags = "nodatacow:@swap"
│   ├── swapfile    ← Наследует nodatacow
│   └── other_files ← Наследуют nodatacow
├── @home/          ← Без специальных флагов
│   └── user_files  ← Обычное COW поведение
```

#### Преимущества перед chattr:

1. **Время применения**: При создании FS (не требует post-processing)
2. **Надежность**: Флаги устанавливаются до копирования файлов
3. **Производительность**: Нет overhead на установку флагов после создания
4. **Автоматизация**: Интегрировано в процесс создания образа

#### Текущая конфигурация:

```bash
# В genimage.cfg.in:
inode-flags = "nodatacow:@swap,nodatasum:@swap"  # Swap: max performance
inode-flags = "nodatacow:@tmp"                    # Temp files: high write perf
inode-flags = "nodatacow:@var"                    # Logs/databases: write perf
```

Это эквивалентно:
```bash
# После создания FS:
chattr +C /mnt/@swap    # nodatacow
chattr -c /mnt/@swap    # nodatasum (отключает datachecksums)
chattr +C /mnt/@tmp     # nodatacow
chattr +C /mnt/@var     # nodatacow
```

Но применяется автоматически во время создания образа.

#### ⚠️ **Предупреждение о trade-offs:**

**nodatacow** отключает Copy-on-Write:
- ❌ **Потеря snapshot функциональности** для этих субтомов
- ❌ **Увеличение фрагментации** при частых перезаписях
- ❌ **Нет deduplication** для этих данных
- ✅ **Максимальная производительность записи**

**nodatasum** отключает data checksums:
- ❌ **Потеря data integrity проверки** (зависим от hardware ECC)
- ❌ **Нет обнаружения silent corruption**
- ✅ **Экономия CPU** на checksum calculations

**Рекомендация:** Использовать только для высоконагруженных write-intensive субтомов.

### Systemd Integration
Автоматическое монтирование субтомов через systemd service после LUKS unlock.

## Производительность

Оптимизировано согласно Debian mkfs.btrfs man page для enterprise server workloads:

### Storage Performance
- **MD RAID1 4K sectors**: SSD-aligned sectorsize для optimal performance
- **DUP metadata**: Redundancy для metadata на SSD (без overhead RAID1)
- **Single data profile**: Оптимальная производительность для SSD storage
- **Btrfs COW**: Эффективное использование storage для snapshots/backups
- **No compression**: Максимальная I/O производительность (сжатие полностью отключено)
- **SSD optimizations**: Специфические mount options для SSD storage
- **Autodefrag**: Автоматическая дефрагментация для root subvolume
- **Swap optimization**: No compression, nocow для максимальной swap производительности

### Filesystem Optimizations
- **32K nodesize**: Лучшая производительность для server workloads (меньше фрагментации)
- **4K sectorsize**: SSD-aligned для оптимальной производительности и kernel compatibility
- **BLAKE2 checksums**: Hardware-accelerated integrity checking
- **Free-space-tree**: Современный space tracking (space_cache=v2)
- **Extref**: Поддержка >64K hardlinks per file
- **inode-flags**: Продвинутые оптимизации через genimage (nodatacow для swap, tmp, var)

### Security & Reliability
- **LUKS2 encryption**: Минимальные накладные расходы на шифрование
- **Encrypted swap**: Безопасный swap на Btrfs с nocow для производительности
- **DUP metadata**: Redundancy для metadata (SSD-optimized)
- **MD RAID1**: Hardware-level redundancy на device уровне

### Container Performance
- **Docker на Btrfs**: Высокая эффективность storage для containers
- **Btrfs COW**: Эффективное использование storage для container layers
- **Subvolume isolation**: Чистое разделение контейнеров
- **inode-flags optimization**: Swap, tmp, var субтомы оптимизированы (nodatacow)
