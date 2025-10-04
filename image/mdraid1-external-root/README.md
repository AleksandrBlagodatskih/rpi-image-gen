# Слой image-raid (mdraid1-external-root) - RAID1 с внешними дисками

## Описание

Этот слой создает образ Raspberry Pi с поддержкой RAID1 на внешних дисках. SD карта используется только для загрузки, а корневая файловая система размещается на RAID1 массиве из внешних дисков.

**Имя слоя:** `image-raid`  
**Путь:** `image/mbr/mdraid1-external-root/`  
**Категория:** `image`  
**Версия:** `1.0.0`

## Архитектура

- **SD карта**: Загрузочный раздел с kernel и initramfs
- **Внешние диски**: RAID1 массив для корневой файловой системы
- **Поддержка шифрования**: Опциональное LUKS шифрование RAID массива
- **Файловые системы**: Поддержка ext4, btrfs, f2fs

## Требования

### Обязательные зависимости
- `image-base` - базовые компоненты для образов
- `device-base` - базовые настройки устройств
- `artefact-base` - управление артефактами сборки
- `locale-base` - локаль и региональные настройки
- `target-config` - конфигурация цели сборки
- `raid-base` - базовая поддержка RAID
- `sys-misc-mdadm-tools` - инструменты mdadm

### Рекомендуемые зависимости
- `net-misc` - сетевая конфигурация
- `security-minimal` - базовая безопасность

## Конфигурация

### Основные переменные

**Префикс переменных:** `IGconf_image_`

| Переменная | Описание | Значение по умолчанию | Обязательна |
|---|----|---|----|
| `IGconf_image_rootfs_type` | Тип файловой системы RAID | `ext4` | Да |
| `IGconf_image_raid_level` | Уровень RAID | `RAID1` | Да |
| `IGconf_image_raid_devices` | Количество устройств в RAID | `2` | Да |
| `IGconf_image_encryption_enabled` | Включить шифрование | `n` | Нет |
| `IGconf_image_pmap` | Тип provisioning map | `clear` | Нет |
| `IGconf_image_boot_part_size` | Размер загрузочного раздела | `200M` | Нет |
| `IGconf_image_root_part_size` | Размер корневого раздела | `100%` | Нет |

### Типы provisioning map

- `clear` - нешифрованный RAID массив
- `crypt` - шифрованный RAID массив с LUKS

### Дополнительные переменные

| Переменная | Описание | Значение по умолчанию |
|---|----|---|
| `IGconf_image_sector_size` | Размер сектора | `512` |
| `IGconf_image_compression` | Тип сжатия образа | `zstd` |
| `IGconf_image_apt_cache` | Кэширование APT пакетов | `n` |
| `IGconf_image_ccache` | Кэширование компиляции | `n` |
| `IGconf_image_ccache_size` | Размер ccache кэша | `5G` |
| `IGconf_image_parallel_jobs` | Параллельные задачи сборки | `0` (авто) |
| `IGconf_image_image_size_optimization` | Оптимизация размера образа | `n` |

## Использование

### Базовая конфигурация

```yaml
# Базовая конфигурация для тестирования
device:
  layer: rpi5
  hostname: rpi5-raid1-test
  user: pi

image:
  layer: image-raid
  boot_part_size: 200M
  root_part_size: 100%
  name: rpi5-raid1-image
  compression: zstd
  
  # RAID конфигурация
  raid_level: RAID1
  raid_devices: 2
  rootfs_type: ext4
  encryption_enabled: n
  pmap: clear

layer:
  base: bookworm-minbase

# Настройка артефактов (обязательно)
artefact:
  target_name: rpi5-raid1-test
  version: 1.0.0

# Региональные настройки (обязательно)
locale:
  timezone: UTC
  default: en_US.UTF-8
  keyboard_layout: us
  keyboard_keymap: us
```

### С шифрованием

```yaml
# Продакшн конфигурация с шифрованием LUKS2
device:
  layer: rpi5
  hostname: rpi5-raid1-secure
  user: pi

image:
  layer: image-raid
  boot_part_size: 200M
  root_part_size: 100%
  name: rpi5-raid1-encrypted
  compression: zstd
  
  # RAID конфигурация с шифрованием
  raid_level: RAID1
  raid_devices: 2
  rootfs_type: btrfs
  encryption_enabled: y
  pmap: crypt
  
  # Параметры шифрования
  key_method: random
  key_size: 512
  key_file: /boot/luks-key
  
  # Оптимизация производительности для продакшн
  apt_cache: y
  ccache: y
  ccache_size: 5G
  parallel_jobs: 4
  image_size_optimization: y

layer:
  base: bookworm-minbase

artefact:
  target_name: rpi5-raid1-secure
  version: 1.0.0

locale:
  timezone: Europe/Moscow
  default: ru_RU.UTF-8
  keyboard_layout: Russian
  keyboard_keymap: ru
```

## Сборка

### Тестовая сборка

```bash
# Сухой запуск для проверки конфигурации
rpi-image-gen build -c config/rpi5-raid1-test.yaml --dry-run

# Полная сборка
rpi-image-gen build -c config/rpi5-raid1-test.yaml
```

### Производственная сборка

```bash
# С оптимизацией производительности и шифрованием
rpi-image-gen build -c config/rpi5-raid1-encrypted.yaml

# Или с переопределением параметров через командную строку
rpi-image-gen build -c config/rpi5-raid1-test.yaml \
  -- IGconf_image_encryption_enabled=y \
  -- IGconf_image_pmap=crypt \
  -- IGconf_image_apt_cache=y \
  -- IGconf_image_ccache=y \
  -- IGconf_image_parallel_jobs=4 \
  -- IGconf_image_compression=zstd
```

## Результаты сборки

Слой создает следующие образы:

1. **SD карта**: `sdcard.img` - загрузочный образ для SD карты
2. **Внешние диски**: `external1.img`, `external2.img` - RAID участники

## Загрузка и установка

1. Запишите `sdcard.img` на SD карту
2. Запишите `external1.img` и `external2.img` на внешние диски
3. Вставьте SD карту и внешние диски в Raspberry Pi
4. Включите питание - система загрузится с RAID1 массива

## Верификация

После сборки рекомендуется проверить:

```bash
# Проверка целостности образов
./integrity-check.sh work/image-rpi5-raid1-test/

# Проверка конфигурации RAID
./performance-optimization.sh work/image-rpi5-raid1-test/filesystem/
```

## Безопасность

### Шифрование
- Поддержка LUKS2 шифрования RAID массива
- Безопасное управление ключами шифрования
- Поддержка TPM для хранения ключей (в разработке)

### Целостность
- Верификация целостности файловой системы
- Проверка корректности RAID массива
- Валидация provisioning map

## Производительность

### Оптимизация сборки
- Поддержка APT кэширования
- Использование ccache для ускорения компиляции
- Параллельная сборка с настраиваемым количеством заданий

### Оптимизация размера
- Опциональное удаление документации
- Очистка кэша пакетов
- Поддержка различных алгоритмов сжатия

## Устранение неисправностей

### Распространенные проблемы

1. **Ошибка валидации переменных**
   ```bash
   # Проверьте синтаксис переменных в конфигурации
   rpi-image-gen metadata --lint layer/mdraid1-external-root.yaml
   ```

2. **Ошибка сборки genimage**
   ```bash
   # Проверьте шаблоны конфигурации
   genimage --config genimage.cfg --help
   ```

3. **Проблемы с RAID**
   ```bash
   # Проверьте статус RAID массива
   cat /proc/mdstat
   mdadm --detail /dev/md0
   ```

## Расширение функциональности

### Кастомизация provisioning map

Создайте собственный `provisionmap-*.json` в директории `device/` для специфичных требований развертывания.

### Дополнительные файловые системы

Добавьте поддержку дополнительных файловых систем в `genimage.cfg.in.*` шаблонах.

### Кастомные ключи шифрования

Настройте собственные методы генерации и хранения ключей шифрования в `key-management.sh`.

## Лицензия

Этот слой распространяется под лицензией MIT. См. файл LICENSE для подробностей.

## Поддержка

- Документация: [ссылка на документацию]
- Issues: [ссылка на трекер проблем]
- Обсуждения: [ссылка на обсуждения]

## История изменений

### v1.0.0
- Первоначальный релиз
- Поддержка RAID1 с внешними дисками
- Поддержка шифрования LUKS
- Оптимизация производительности сборки
