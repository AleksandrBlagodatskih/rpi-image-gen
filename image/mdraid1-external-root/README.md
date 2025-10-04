# Слой mdraid1-external-root - RAID1 с внешними дисками

## Описание

Этот слой создает образ Raspberry Pi с поддержкой RAID1 на внешних дисках. SD карта используется только для загрузки, а корневая файловая система размещается на RAID1 массиве из внешних дисков.

## Архитектура

- **SD карта**: Загрузочный раздел с kernel и initramfs
- **Внешние диски**: RAID1 массив для корневой файловой системы
- **Поддержка шифрования**: Опциональное LUKS шифрование RAID массива
- **Файловые системы**: Поддержка ext4, btrfs, f2fs

## Требования

### Обязательные зависимости
- `artefact-base` - управление артефактами сборки
- `sys-build-base` - инструменты сборки
- `target-config` - конфигурация цели сборки
- `locale-base` - локаль и региональные настройки
- `deploy-base` - развертывание артефактов
- `sbom-base` - генерация SBOM (Software Bill of Materials)
- `device-base` - базовые настройки устройств
- `sys-misc-raid-base` - базовая поддержка RAID
- `sys-misc-mdadm-tools` - инструменты mdadm

### Рекомендуемые зависимости
- `net-misc` - сетевая конфигурация
- `security-minimal` - базовая безопасность

## Конфигурация

### Основные переменные

| Переменная | Описание | Значение по умолчанию | Обязательна |
|---|----|---|----|
| `mdraid1_external_root_rootfs_type` | Тип файловой системы RAID | `ext4` | Да |
| `mdraid1_external_root_raid_level` | Уровень RAID | `RAID1` | Да |
| `mdraid1_external_root_raid_devices` | Количество устройств в RAID | `2` | Да |
| `mdraid1_external_root_encryption_enabled` | Включить шифрование | `n` | Нет |
| `mdraid1_external_root_pmap` | Тип provisioning map | `clear` | Нет |

### Типы provisioning map

- `clear` - нешифрованный RAID массив
- `crypt` - шифрованный RAID массив с LUKS

### Размеры разделов

| Переменная | Описание | Значение по умолчанию |
|---|----|---|
| `mdraid1_external_root_boot_part_size` | Размер загрузочного раздела | `200M` |
| `mdraid1_external_root_root_part_size` | Размер корневого раздела | `100%` |
| `mdraid1_external_root_sector_size` | Размер сектора | `512` |

## Использование

### Базовая конфигурация

```yaml
device:
  layer: pi5
  hostname: rpi5-raid

image:
  layer: mdraid1-external-root

layer:
  base: debian-bookworm-arm64-slim
  extension:
    # Базовые компоненты сборки
    - artefact-base
    - sys-build-base
    - target-config
    - locale-base
    - deploy-base
    - sbom-base
    - device-base
    # Специфичные для RAID
    - sys-misc-raid-base
    - sys-misc-mdadm-tools
    # Само расширение
    - mdraid1-external-root

# Настройка артефактов
artefact:
  target_name: rpi5-raid1-system
  version: 1.0.0

# Региональные настройки
locale:
  timezone: Europe/Moscow
  default: ru_RU.UTF-8
  keyboard_layout: Russian
  keyboard_keymap: ru

# Настройка RAID
mdraid1_external_root_raid_level: RAID1
mdraid1_external_root_raid_devices: 2
mdraid1_external_root_rootfs_type: ext4
mdraid1_external_root_encryption_enabled: n
mdraid1_external_root_pmap: clear
```

### С шифрованием

```yaml
# Включить шифрование RAID массива
mdraid1_external_root_encryption_enabled: y
mdraid1_external_root_pmap: crypt
mdraid1_external_root_key_method: random
mdraid1_external_root_key_size: 512

# Дополнительные настройки для шифрования
mdraid1_external_root_key_file: /boot/luks-key
mdraid1_external_root_key_env: LUKS_KEY
```

## Сборка

### Тестовая сборка

```bash
# Сухой запуск для проверки конфигурации
rpi-image-gen build -c test-config.yaml --dry-run

# Полная сборка
rpi-image-gen build -c test-config.yaml
```

### Производственная сборка

```bash
# С оптимизацией производительности
rpi-image-gen build -c config.yaml \
  -- IGconf_artefact_target_name=rpi5-raid1-system \
  -- IGconf_artefact_version=1.0.0 \
  -- IGconf_locale_timezone=Europe/Moscow \
  -- IGconf_locale_default=ru_RU.UTF-8 \
  -- IGconf_mdraid1_external_root_apt_cache=y \
  -- IGconf_mdraid1_external_root_ccache=y \
  -- IGconf_mdraid1_external_root_parallel_jobs=4 \
  -- IGconf_mdraid1_external_root_compression=zstd
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
