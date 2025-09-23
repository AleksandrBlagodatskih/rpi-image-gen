# Шаблон YAML конфигурации устройства

## Структура файла: device/[device]/device.yaml

```yaml
# ==========================================
# КОНФИГУРАЦИЯ УСТРОЙСТВА RASPBERRY PI
# ==========================================

# БЛОК МЕТАДАННЫХ (METADATA BLOCK)
# ==========================================
# METABEGIN
# X-Env-Layer-Name: [device-name]          # Имя слоя устройства
# X-Env-Layer-Category: device             # Категория: device
# X-Env-Layer-Desc: [description]          # Описание устройства
# X-Env-Layer-Version: 1.0.0               # Версия слоя
# X-Env-Layer-Requires: [dependencies]     # Зависимости
# X-Env-Layer-Provides: device             # Что предоставляет
#
# X-Env-VarPrefix: device                  # Префикс переменных
#
# ПЕРЕМЕННЫЕ УСТРОЙСТВА (DEVICE VARIABLES)
# ==========================================
# X-Env-Var-class: [device-class]          # Класс устройства
# X-Env-Var-class-Desc: Device class       # Описание
# X-Env-Var-class-Required: n              # Обязательность: y/n
# X-Env-Var-class-Valid: keywords:[values] # Допустимые значения
# X-Env-Var-class-Set: y                   # Устанавливается: y/n
#
# X-Env-Var-storage_type: sd               # Тип носителя
# X-Env-Var-storage_type-Desc: Storage media type
# X-Env-Var-storage_type-Required: n
# X-Env-Var-storage_type-Valid: keywords:sd,nvme
# X-Env-Var-storage_type-Set: y
#
# X-Env-Var-assetdir: ${DIRECTORY}         # Каталог ресурсов
# X-Env-Var-assetdir-Desc: Device specific asset directory
# X-Env-Var-assetdir-Required: n
# X-Env-Var-assetdir-Valid: string
# X-Env-Var-assetdir-Set: y
#
# ДОПОЛНИТЕЛЬНЫЕ ПЕРЕМЕННЫЕ (OPTIONAL VARIABLES)
# ==========================================
# X-Env-Var-hostname: raspberrypi          # Имя хоста по умолчанию
# X-Env-Var-hostname-Desc: Default hostname
# X-Env-Var-hostname-Required: n
# X-Env-Var-hostname-Valid: string
# X-Env-Var-hostname-Set: y
#
# X-Env-Var-sector_size: 512              # Размер сектора
# X-Env-Var-sector_size-Desc: Storage sector size
# X-Env-Var-sector_size-Required: n
# X-Env-Var-sector_size-Valid: integer
# X-Env-Var-sector_size-Set: y
#
# METAEND
# ==========================================

# КОНФИГУРАЦИЯ MMDEBSTRAP (MMDEBSTRAP CONFIGURATION)
# ==========================================
---
mmdebstrap:
  # Пакеты, специфичные для устройства
  packages:
    - firmware-brcm80211                    # Wi-Fi прошивка
    # - firmware-realtek                    # Realtek Wi-Fi (если нужно)
    # - bluez-firmware                      # Bluetooth прошивка

  # Ключевые кольца для верификации пакетов
  # keyrings:
  #   - /usr/share/keyrings/raspberrypi-archive-keyring.gpg

  # Опции APT
  # aptopt:
  #   - "APT::Install-Recommends false"      # Не устанавливать рекомендованные

  # Хуки настройки (customize hooks)
  # customize-hooks:
  #   - device-setup.sh                      # Скрипт настройки устройства
```

## Обязательные блоки

### 1. Блок метаданных (METABEGIN/METAEND)
**Обязателен для всех файлов устройств**

#### Обязательные поля метаданных:
- `X-Env-Layer-Name` - имя слоя (должно совпадать с именем каталога)
- `X-Env-Layer-Category` - категория (всегда "device")
- `X-Env-Layer-Desc` - описание устройства
- `X-Env-Layer-Version` - версия слоя
- `X-Env-Layer-Requires` - зависимости (другие слои)
- `X-Env-Layer-Provides` - что предоставляет (обычно "device")

#### Обязательные переменные:
- `X-Env-VarPrefix` - префикс для переменных (обычно "device")
- `X-Env-Var-class` - класс устройства
- `X-Env-Var-storage_type` - тип носителя
- `X-Env-Var-assetdir` - каталог ресурсов

### 2. Секция mmdebstrap
**Обязательна для определения пакетов**

#### Обязательные поля:
- `packages` - массив пакетов для установки

## Опциональные блоки

### Дополнительные переменные окружения
- Любые переменные с префиксом X-Env-Var-
- Могут включать валидацию и значения по умолчанию

### Конфигурация mmdebstrap
- `keyrings` - ключевые кольца для верификации
- `aptopt` - опции APT
- `customize-hooks` - пользовательские хуки настройки

## Форматы переменных

### Ключевые слова (keywords)
```yaml
X-Env-Var-[name]-Valid: keywords:value1,value2,value3
```

### Диапазоны (range)
```yaml
X-Env-Var-[name]-Valid: range:1,100
```

### Регулярные выражения (regex)
```yaml
X-Env-Var-[name]-Valid: regex:^([0-9]+)$
```

### Строки (string)
```yaml
X-Env-Var-[name]-Valid: string
```

### Целые числа (integer)
```yaml
X-Env-Var-[name]-Valid: integer
```

## Примеры устройств

### Raspberry Pi 5
```yaml
# METABEGIN
# X-Env-Layer-Name: rpi5
# X-Env-Layer-Category: device
# X-Env-Layer-Desc: Raspberry Pi 5 specific device layer
# X-Env-Layer-Version: 1.0.0
# X-Env-Layer-Requires: device-base,rpi-boot-firmware,rpi-linux-2712
# X-Env-Layer-Provides: device
#
# X-Env-VarPrefix: device
#
# X-Env-Var-class: pi5
# X-Env-Var-class-Desc: Device class
# X-Env-Var-class-Required: n
# X-Env-Var-class-Valid: keywords:pi5
# X-Env-Var-class-Set: y
#
# X-Env-Var-storage_type: sd
# X-Env-Var-storage_type-Desc: Storage media type
# X-Env-Var-storage_type-Required: n
# X-Env-Var-storage_type-Valid: keywords:sd,nvme
# X-Env-Var-storage_type-Set: y
#
# X-Env-Var-assetdir: ${DIRECTORY}
# X-Env-Var-assetdir-Desc: Device specific asset directory
# X-Env-Var-assetdir-Required: n
# X-Env-Var-assetdir-Valid: string
# X-Env-Var-assetdir-Set: y
# METAEND
---
mmdebstrap:
  packages:
    - firmware-brcm80211
```

### Compute Module 4
```yaml
# METABEGIN
# X-Env-Layer-Name: cm4
# X-Env-Layer-Category: device
# X-Env-Layer-Desc: Raspberry Pi Compute Module 4
# X-Env-Layer-Version: 1.0.0
# X-Env-Layer-Requires: device-base,rpi-generic64
# X-Env-Layer-Provides: device
#
# X-Env-VarPrefix: device
#
# X-Env-Var-class: cm4
# X-Env-Var-class-Desc: Compute Module class
# X-Env-Var-class-Required: n
# X-Env-Var-class-Valid: keywords:cm4
# X-Env-Var-class-Set: y
#
# X-Env-Var-storage_type: sd
# X-Env-Var-storage_type-Desc: Storage media type
# X-Env-Var-storage_type-Required: n
# X-Env-Var-storage_type-Valid: keywords:sd
# X-Env-Var-storage_type-Set: y
#
# X-Env-Var-assetdir: ${DIRECTORY}
# X-Env-Var-assetdir-Desc: Device specific asset directory
# X-Env-Var-assetdir-Required: n
# X-Env-Var-assetdir-Valid: string
# X-Env-Var-assetdir-Set: y
# METAEND
---
mmdebstrap:
  packages:
    - firmware-brcm80211
```

## Валидация

Слои устройств проверяются командой:
```bash
rpi-image-gen layer --lint [device-name]
```

Или:
```bash
rpi-image-gen metadata --lint device/[device]/device.yaml
```
