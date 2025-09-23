# Шаблон YAML конфигурации для сборки образов

## Структура файла: config/[name].yaml

```yaml
# ==========================================
# КОНФИГУРАЦИЯ СБОРКИ ОБРАЗА RASPBERRY PI
# ==========================================

# Секция: Устройство (Device Configuration)
# Определяет целевое устройство и его аппаратные характеристики
device:
  layer: "rpi5"                    # Слой устройства: rpi5, rpi4, pi3, cm4, cm5, zero2w
  hostname: "raspberrypi"          # Имя хоста (опционально)
  user1pass: ""                    # Пароль пользователя (пустой = отключен)
  # Дополнительные переменные устройства
  # storage_type: "sd"              # Тип носителя: sd, nvme
  # sector_size: 512               # Размер сектора

# Секция: Образ (Image Configuration)
# Определяет параметры создаваемого дискового образа
image:
  layer: "image-rpios"             # Тип образа: image-rpios, image-rota
  boot_part_size: "200%"           # Размер загрузочного раздела
  root_part_size: "300%"           # Размер корневого раздела
  name: "my-custom-image"          # Имя выходного файла
  # Дополнительные параметры образа
  # system_part_size: "400%"       # Размер системного раздела (для A/B)
  # provider: "genimage"           # Поставщик образа
  # outputdir: "./work"            # Каталог для выходных файлов

# Секция: Слои (Layer Configuration)
# Определяет программные компоненты и их зависимости
layer:
  base: "bookworm-minbase"         # Базовый слой
  # Дополнительные слои
  # - "openssh-server"              # SSH сервер
  # - "ca-certificates"             # Сертификаты ЦС
  # - "fake-hwclock"               # Аппаратные часы
  # - "systemd-net-min"            # Минимальная сеть

# Секция: Переменные окружения (Environment Variables)
# Определяет переменные для процесса сборки
# IGconf_sys_workroot: "./work"    # Рабочий каталог
# IGconf_sys_apt_proxy_http: ""    # HTTP прокси для APT
# IGconf_sys_apt_cachedir: ""      # Кеш APT
# IGconf_sys_apt_keydir: ""        # Каталог ключей APT
# IGconf_target_dir: "./work/root" # Целевой каталог файловой системы

# Секция: Хуки (Hooks)
# Определяет скрипты для выполнения на разных этапах
# image_prebuild: ""               # Перед сборкой файловой системы
# image_postbuild: ""              # После сборки файловой системы
# device_prebuild: ""              # Перед сборкой устройства
# device_postbuild: ""             # После сборки устройства
# image_preimage: ""               # Перед созданием образа
# image_postimage: ""              # После создания образа
# device_preimage: ""              # Перед созданием образа устройства
# device_postimage: ""             # После создания образа устройства

# Секция: Развертывание (Deployment)
# Определяет параметры развертывания готового образа
# deploy_dir: ""                   # Каталог для развертывания
# deploy_hook: ""                  # Скрипт развертывания

# Секция: SBOM (Software Bill of Materials)
# Определяет параметры генерации спецификации ПО
# sbom_hook: ""                    # Скрипт генерации SBOM
```

## Обязательные секции

### 1. device
**Обязательна для всех конфигураций**
- `layer` - определяет целевое устройство
- Должна ссылаться на существующий слой в `device/`

### 2. image
**Обязательна для создания дисковых образов**
- `layer` - тип образа (image-rpios для обычных, image-rota для A/B)
- `boot_part_size` - размер загрузочного раздела
- `root_part_size` - размер корневого раздела
- `name` - имя выходного файла

### 3. layer
**Обязательна для определения ПО**
- `base` - базовый слой (например, bookworm-minbase)
- Дополнительные слои перечисляются в массиве

## Опциональные секции

### Environment Variables (IGconf_*)
Используются для настройки процесса сборки:
- `IGconf_sys_workroot` - рабочий каталог
- `IGconf_sys_apt_proxy_http` - HTTP прокси для APT
- `IGconf_sys_apt_cachedir` - каталог кеша APT
- `IGconf_sys_apt_keydir` - каталог ключей APT

### Hooks
Скрипты выполняемые на разных этапах сборки

### Deployment
Параметры для развертывания готового образа

### SBOM
Параметры для генерации спецификации программного обеспечения

## Примеры использования

### Минимальная конфигурация
```yaml
device:
  layer: rpi5
image:
  layer: image-rpios
  boot_part_size: 200%
  root_part_size: 300%
  name: minimal-image
layer:
  base: bookworm-minbase
```

### Полная конфигурация с дополнительными слоями
```yaml
device:
  layer: rpi5
  hostname: mypi
  user1pass: mypassword
image:
  layer: image-rota
  boot_part_size: 200%
  system_part_size: 400%
  name: full-system
layer:
  base: bookworm-minbase
  - openssh-server
  - ca-certificates
  - fake-hwclock
```

## Валидация

Конфигурация проверяется командой:
```bash
rpi-image-gen config --lint /path/to/config.yaml
```
