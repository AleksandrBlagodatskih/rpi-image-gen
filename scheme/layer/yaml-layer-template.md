# Шаблон YAML слоя для rpi-image-gen

## Структура файла: layer/[category]/[layer-name].yaml

```yaml
# ==========================================
# СЛОЙ ДЛЯ RPI-IMAGE-GEN
# ==========================================

# БЛОК МЕТАДАННЫХ (METADATA BLOCK)
# ==========================================
# METABEGIN
# X-Env-Layer-Name: [layer-name]           # Имя слоя
# X-Env-Layer-Category: [category]         # Категория: base, app, build, image, device
# X-Env-Layer-Desc: [description]          # Описание слоя
# X-Env-Layer-Version: 1.0.0               # Версия слоя
# X-Env-Layer-Requires: [dependencies]     # Зависимости (через запятую)
# X-Env-Layer-Provides: [provides]         # Что предоставляет
# X-Env-Layer-Conflicts: [conflicts]       # Конфликты (опционально)
#
# X-Env-VarPrefix: [prefix]                # Префикс переменных (опционально)
#
# ПЕРЕМЕННЫЕ СЛОЯ (LAYER VARIABLES)
# ==========================================
# X-Env-Var-[variable]: [default]          # Переменная слоя
# X-Env-Var-[variable]-Desc: [description] # Описание переменной
# X-Env-Var-[variable]-Required: y/n       # Обязательность: y/n
# X-Env-Var-[variable]-Valid: [validation] # Валидация: keywords, range, regex, string, integer
# X-Env-Var-[variable]-Set: y/n            # Устанавливается: y/n
#
# X-Env-Var-example_var: "default_value"   # Пример пользовательской переменной
# X-Env-Var-example_var-Desc: Example variable description
# X-Env-Var-example_var-Required: n
# X-Env-Var-example_var-Valid: string
# X-Env-Var-example_var-Set: n
#
# METAEND
# ==========================================

# КОНФИГУРАЦИЯ MMDEBSTRAP (MMDEBSTRAP CONFIGURATION)
# ==========================================
---
mmdebstrap:
  # Пакеты для установки
  packages:
    - [package-name]                        # Основные пакеты
    # - [optional-package]                   # Опциональные пакеты

  # Ключевые кольца (опционально)
  # keyrings:
  #   - /usr/share/keyrings/custom-keyring.gpg

  # Опции APT (опционально)
  # aptopt:
  #   - "APT::Install-Recommends false"       # Не устанавливать рекомендованные
  #   - "APT::Install-Suggests false"         # Не устанавливать предлагаемые

  # Хуки настройки (setup hooks)
  # setup-hooks:
  #   - layer-setup.sh                        # Скрипт настройки

  # Хуки извлечения (extract hooks)
  # extract-hooks:
  #   - layer-extract.sh                      # Скрипт извлечения

  # Основные хуки (essential hooks)
  # essential-hooks:
  #   - layer-essential.sh                    # Основные настройки

  # Хуки кастомизации (customize hooks)
  # customize-hooks:
  #   - layer-customize.sh                    # Кастомные настройки

  # Хуки очистки (cleanup hooks)
  # cleanup-hooks:
  #   - layer-cleanup.sh                      # Очистка

# КОНФИГУРАЦИЯ GENIMAGE (GENIMAGE CONFIGURATION) - только для image слоев
# ==========================================
# genimage:
#   images:
#     - name: [image-name]
#       format: [format]                     # Формат: ext4, btrfs, etc.
#       size: [size]                        # Размер: 1G, 2G, etc.
#       mountpoint: /
#       partition:
#         image: [partition-image]
#         size: [partition-size]
#         filesystem: [filesystem-type]      # Тип ФС: ext4, btrfs, etc.

# ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (ENVIRONMENT VARIABLES) - опционально
# ==========================================
# environment:
#   [VAR_NAME]: [value]                      # Произвольные переменные окружения

# ФАЙЛОВЫЕ СИСТЕМЫ (FILESYSTEMS) - опционально
# ==========================================
# filesystems:
#   - name: [fs-name]
#     type: [fs-type]                        # Тип: ext4, btrfs, etc.
#     device: [device]                       # Устройство: /dev/sda1, etc.
#     mount: [mount-point]                   # Точка монтирования: /
#     options: [mount-options]               # Опции монтирования: defaults,noatime

# СЕРВИСЫ (SERVICES) - опционально
# ==========================================
# services:
#   - name: [service-name]                   # Имя сервиса
#     enable: true                           # Включить: true/false
#     start: true                            # Запустить: true/false
#     # config: [config-file]                 # Конфигурационный файл (опционально)

# ПОЛЬЗОВАТЕЛИ (USERS) - опционально
# ==========================================
# users:
#   - name: [username]                       # Имя пользователя
#     groups: [group1,group2]                # Группы
#     shell: /bin/bash                       # Оболочка
#     home: /home/[username]                 # Домашний каталог
#     create_home: true                      # Создать домашний каталог
#     system: false                          # Системный пользователь
#     password: [password]                   # Пароль (опционально)
#     ssh_key: [ssh-key]                     # SSH ключ (опционально)
```

## Обязательные блоки

### 1. Блок метаданных (METABEGIN/METAEND)
**Обязателен для всех слоев**

#### Обязательные поля метаданных:
- `X-Env-Layer-Name` - имя слоя (должно совпадать с именем файла)
- `X-Env-Layer-Category` - категория слоя (base, app, build, image, device)
- `X-Env-Layer-Desc` - описание слоя
- `X-Env-Layer-Version` - версия слоя
- `X-Env-Layer-Requires` - зависимости (другие слои, через запятую)
- `X-Env-Layer-Provides` - что предоставляет слой

### 2. Секция mmdebstrap
**Обязательна для слоев, устанавливающих пакеты**

#### Обязательные поля:
- `packages` - массив пакетов для установки

## Опциональные блоки

### Переменные окружения
- Любые переменные с префиксом X-Env-Var-
- Могут включать валидацию и значения по умолчанию

### Хуки mmdebstrap
- `setup-hooks` - выполняются перед настройкой
- `extract-hooks` - выполняются после извлечения
- `essential-hooks` - выполняются после основных пакетов
- `customize-hooks` - выполняются для кастомизации
- `cleanup-hooks` - выполняются для очистки

### Конфигурация genimage (только для image слоев)
- `images` - определения дисковых образов

### Прочие секции
- `environment` - переменные окружения
- `filesystems` - файловые системы
- `services` - системные сервисы
- `users` - пользователи системы

## Категории слоев

### base (Базовые слои)
- Предоставляют фундаментальную функциональность
- Примеры: device-base, image-base, locale-base

### app (Прикладные слои)
- Устанавливают приложения и сервисы
- Примеры: openssh-server, docker-engine, nginx

### build (Слои сборки)
- Предоставляют инструменты для сборки
- Примеры: build-tools, development-tools

### image (Слои образов)
- Определяют структуру дисковых образов
- Примеры: image-rpios, image-rota

### device (Слои устройств)
- Специфичные для конкретных устройств
- Примеры: rpi5, pi4, cm4

## Форматы валидации

### Ключевые слова (keywords)
```yaml
X-Env-Var-[name]-Valid: keywords:value1,value2,value3
```

### Диапазоны (range)
```yaml
X-Env-Var-[name]-Valid: range:min,max
```

### Регулярные выражения (regex)
```yaml
X-Env-Var-[name]-Valid: regex:^[a-zA-Z0-9_]+$
```

### Типы данных
- `string` - строковые значения
- `integer` - целые числа
- `boolean` - логические значения

## Примеры слоев

### Прикладной слой (openssh-server)
```yaml
# METABEGIN
# X-Env-Layer-Name: openssh-server
# X-Env-Layer-Category: app
# X-Env-Layer-Desc: OpenSSH Server for secure remote access
# X-Env-Layer-Version: 1.0.0
# X-Env-Layer-Requires: base
# X-Env-Layer-Provides: ssh-server
#
# X-Env-VarPrefix: ssh
#
# X-Env-Var-port: 22
# X-Env-Var-port-Desc: SSH server port
# X-Env-Var-port-Required: n
# X-Env-Var-port-Valid: range:1,65535
# X-Env-Var-port-Set: y
#
# X-Env-Var-permit_root_login: "no"
# X-Env-Var-permit_root_login-Desc: Allow root login
# X-Env-Var-permit_root_login-Required: n
# X-Env-Var-permit_root_login-Valid: keywords:yes,no,prohibit-password,without-password
# X-Env-Var-permit_root_login-Set: y
#
# METAEND
---
mmdebstrap:
  packages:
    - openssh-server
    - openssh-client
```

### Базовый слой (device-base)
```yaml
# METABEGIN
# X-Env-Layer-Name: device-base
# X-Env-Layer-Category: base
# X-Env-Layer-Desc: Base device functionality and configuration
# X-Env-Layer-Version: 1.0.0
# X-Env-Layer-Provides: device-base
# METAEND
---
mmdebstrap:
  packages:
    - systemd
    - udev
    - kmod
```

### Слой образа (image-rpios)
```yaml
# METABEGIN
# X-Env-Layer-Name: image-rpios
# X-Env-Layer-Category: image
# X-Env-Layer-Desc: Raspberry Pi OS compatible image layout
# X-Env-Layer-Version: 1.0.0
# X-Env-Layer-Requires: image-base
# X-Env-Layer-Provides: image
#
# X-Env-VarPrefix: image
#
# X-Env-Var-boot_part_size: 200%
# X-Env-Var-boot_part_size-Desc: Boot partition size
# X-Env-Var-boot_part_size-Required: n
# X-Env-Var-boot_part_size-Valid: string
# X-Env-Var-boot_part_size-Set: y
#
# METAEND
---
genimage:
  images:
    - name: rpi-image
      format: ext4
      size: 2G
      partition:
        image: rootfs.ext4
        size: 2G
        filesystem: ext4
```

## Валидация

Слои проверяются командой:
```bash
rpi-image-gen layer --lint [layer-name]
```

Или:
```bash
rpi-image-gen metadata --lint layer/[category]/[layer-name].yaml
```
