# Hybrid RAID Layout для rpi-image-gen

## Описание

Гибридная конфигурация хранилища для Raspberry Pi с комбинацией SD-карты и RAID1 на SSD дисках с опциональным LUKS2 шифрованием. Поддерживает автоматическое расширение дисков и различные типы файловых систем (ext4, btrfs, f2fs).

### Возможности

- **Гибридное хранение**: SD-карта для загрузки + RAID1 на SSD для данных
- **Опциональное шифрование**: LUKS2 с настраиваемым размером ключа
- **Множественные ФС**: ext4, btrfs, f2fs с оптимизациями для RAID1
- **Автоматическое расширение**: Сервис для расширения разделов при первой загрузке
- **Надежность**: RAID1 обеспечивает отказоустойчивость

## Структура

```
hybrid-raid-layout/
├── README.md                    # Эта документация
├── config/                      # Примеры конфигураций
│   ├── basic.yaml              # Базовая конфигурация без шифрования
│   ├── encrypted.yaml          # Конфигурация с LUKS2 шифрованием
│   └── development.yaml        # Конфигурация для разработки
├── bdebstrap/                  # Хуки mmdebstrap (отдельные файлы)
│   ├── customize01-raid-setup.sh
│   ├── customize02-luks-setup.sh
│   └── customize03-disk-expansion.sh
├── device/                     # Provision maps + overlay файлы
│   ├── provisionmap-clear.json # Для незашифрованной конфигурации
│   ├── provisionmap-crypt.json # Для зашифрованной конфигурации
│   ├── initramfs-tools/        # Initramfs хуки для загрузки
│   │   └── hooks/
│   │       └── hybrid-raid     # Хук для обработки SSD идентификаторов
│   └── rootfs-overlay/         # Overlay файлы для корневой ФС
│       ├── etc/
│       │   ├── luks/           # Директория для LUKS ключей
│       │   └── profile.d/
│       │       └── hybrid-raid-status.sh # Статус RAID при логине
│       └── usr/local/bin/      # Директория для утилит (создается зависимыми слоями)
├── scripts/                    # Утилитарные скрипты
│   ├── pre-image.sh           # Предварительная обработка образа
│   └── setup.sh               # Настройка разделов и конфигураций
├── genimage.cfg.in            # Шаблон конфигурации genimage
├── mke2fs.conf                # Конфигурация для создания ext4
├── image.yaml                 # Основной слой образа
└── layers/                    # Конфигурации зависимых слоев
    ├── raid.yaml              # Настройки RAID
    └── luks.yaml              # Настройки LUKS
```

## Конфигурационные переменные

### Основные параметры

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `encryption_enabled` | `n` | Включить LUKS2 шифрование (y/n) |
| `rootfs_type` | `ext4` | Тип файловой системы (ext4/btrfs/f2fs) |
| `root_part_size` | `2G` | Размер корневого раздела |
| `boot_part_size` | `200M` | Размер загрузочного раздела |
| `pmap` | `clear` | Тип provision map (clear/crypt) |
| `ssd_ids` | - | ID SSD устройств через запятую |

### Параметры шифрования

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `key_method` | `file` | Метод хранения ключа LUKS |
| `key_size` | `512` | Размер ключа в битах (256-8192) |

## Примеры использования

### Базовая конфигурация без шифрования

```yaml
device:
  layer: pi5
  hostname: my-raid-server

image:
  layer: hybrid-raid-layout
  name: basic-raid-image
  boot_part_size: 200M
  root_part_size: 4G

layer:
  base: bookworm-minbase
  security: apparmor-core

hybrid_raid_luks:
  rootfs_type: ext4
  ssd_ids: "ata-SAMSUNG_HD204UI_S1XWJ1LZ100000,ata-SAMSUNG_HD204UI_S1XWJ1LZ100001"
```

### Конфигурация с шифрованием

```yaml
# Наследуем базовую конфигурацию
device:
  layer: pi5
  hostname: encrypted-raid-server

image:
  layer: hybrid-raid-layout
  name: encrypted-raid-image
  boot_part_size: 200M
  root_part_size: 4G

layer:
  base: bookworm-minbase
  security: apparmor-core

hybrid_raid_luks:
  encryption_enabled: y
  key_size: 512
  rootfs_type: btrfs
  ssd_ids: "ata-SAMSUNG_HD204UI_S1XWJ1LZ100000,ata-SAMSUNG_HD204UI_S1XWJ1LZ100001"
```

### Конфигурация для разработки

```yaml
device:
  layer: pi5
  hostname: dev-raid-server

image:
  layer: hybrid-raid-layout
  name: dev-raid-image
  boot_part_size: 200M
  root_part_size: 2G

layer:
  base: bookworm-minbase
  development: full-dev-tools

hybrid_raid_luks:
  encryption_enabled: n
  rootfs_type: ext4
  ssd_ids: "ata-SAMSUNG_HD204UI_S1XWJ1LZ100000,ata-SAMSUNG_HD204UI_S1XWJ1LZ100001"
```

## Сборка образа

```bash
# Используя базовую конфигурацию
rpi-image-gen --config config/basic.yaml

# Используя конфигурацию с шифрованием
rpi-image-gen --config config/encrypted.yaml

# Используя конфигурацию для разработки
rpi-image-gen --config config/development.yaml
```

## Архитектура

### Загрузка системы

1. **SD-карта**: Содержит загрузчик, ядро и initramfs
2. **RAID1**: Автоматически собирается из двух SSD дисков
3. **Шифрование**: Опционально, корневой раздел шифруется LUKS2

### Автоматическое расширение

При первой загрузке запускается сервис `disk-expansion.service`, который:
- Расширяет RAID1 на весь доступный размер SSD
- Изменяет размер файловой системы
- Обновляет конфигурацию системы

### Provision Maps

- **clear**: Для незашифрованных конфигураций
- **crypt**: Для зашифрованных конфигураций с LUKS2

## Зависимости

- `mdadm` - управление RAID
- `cryptsetup` - LUKS шифрование (опционально)
- `e2fsprogs` - утилиты ext4
- `btrfs-progs` - утилиты btrfs
- `f2fs-tools` - утилиты f2fs

## Безопасность

- LUKS2 шифрование с PBKDF2 + Argon2id
- Автоматическое монтирование зашифрованных разделов
- Защищенные ключи в `/etc/luks/`
- Отключенный swap для предотвращения утечек

## Отладка

### Просмотр состояния RAID

```bash
cat /proc/mdstat
mdadm --detail /dev/md0
```

### Проверка шифрования

```bash
cryptsetup status cryptroot
lsblk -f
```

### Логи расширения дисков

```bash
journalctl -u disk-expansion.service
```

## Устранение неисправностей

### Проблемы с RAID

Если RAID не собирается автоматически:
```bash
# Ручная сборка
mdadm --assemble --scan
# Или принудительно
mdadm --assemble /dev/md0 /dev/disk/by-id/ata-SAMSUNG_HD204UI_S1XWJ1LZ100000 /dev/disk/by-id/ata-SAMSUNG_HD204UI_S1XWJ1LZ100001
```

### Проблемы с шифрованием

Если система не загружается с шифрованием:
- Проверьте наличие ключа LUKS
- Убедитесь в корректности UUID в cmdline.txt
- Проверьте initramfs на наличие хуков LUKS

## Совместимость

- **Устройства**: Raspberry Pi 4, 5
- **Дистрибутивы**: Debian Bookworm, Trixie
- **Файловые системы**: ext4, btrfs, f2fs
- **RAID**: Linux MD RAID1

## Разработка

Для внесения изменений следуйте правилам rpi-image-gen extensions:

1. Обновляйте документацию при изменении функциональности
2. Добавляйте примеры конфигураций для новых сценариев
3. Тестируйте на всех поддерживаемых комбинациях ФС и шифрования
4. Следуйте паттернам именования и структуры

## Лицензия

Этот слой распространяется под той же лицензией, что и rpi-image-gen.
