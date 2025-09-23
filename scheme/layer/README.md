# Каталог layer/ - Библиотека слоев

Каталог содержит модульные компоненты (слои) для сборки образов Raspberry Pi.

## Структура каталогов

### base/
**Назначение**: Базовые слои инфраструктуры
**Компоненты**:
- `artefact-base.yaml` - базовое именование артефактов
- `core-essential.yaml` - основные системные компоненты
- `device-base.yaml` - базовая поддержка устройств
- `image-base.yaml` - базовая поддержка образов
- `locale-base.yaml` - поддержка локализации
- `sys-build-base.yaml` - базовая система сборки
- `target-config.yaml` - конфигурация цели сборки
- `deploy-base.yaml` - базовые механизмы развертывания

### debian/
**Назначение**: Слои для Debian-based систем
**Компоненты**:
- `bookworm/` - Debian Bookworm (stable)
- `trixie/` - Debian Trixie (testing)
- Слои для различных архитектур (arm64, armhf)

### raspbian/
**Назначение**: Слои для Raspbian-based систем
**Компоненты**:
- `bookworm/` - Raspbian Bookworm
- `trixie/` - Raspbian Trixie

### rpi/
**Назначение**: Raspberry Pi специфические слои
**Компоненты**:
- `device/` - аппаратная поддержка устройств
- `essential.yaml` - основные компоненты RPi
- `misc-skel.yaml` - базовая структура файлов
- `misc-utils.yaml` - вспомогательные утилиты
- `user-credentials.yaml` - управление учетными данными

### app-container/
**Назначение**: Поддержка контейнеров
**Компоненты**:
- Docker engine для различных дистрибутивов

### app-misc/
**Назначение**: Различные приложения
**Компоненты**:
- `ca-certificates.yaml` - сертификаты ЦС

### net-misc/
**Назначение**: Сетевые компоненты
**Компоненты**:
- `openssh-server.yaml` - SSH сервер

### sys-apps/
**Назначение**: Системные приложения
**Компоненты**:
- `fake-hwclock.yaml` - аппаратные часы
- `systemd-net-min.yaml` - минимальная сеть systemd

### suite/
**Назначение**: Готовые комплекты
**Компоненты**:
- Минимальные образы для Debian Bookworm/Trixie

### sbom/
**Назначение**: Software Bill of Materials
**Компоненты**:
- Генерация SBOM для аудита безопасности

## Формат файлов слоев

### Структура YAML файлов

1. **Метаданные** (METABEGIN/METAEND):
   - Определение имени слоя
   - Категория (build, device, image, app)
   - Описание и версия
   - Зависимости и что предоставляет

2. **Переменные окружения**:
   - Префикс для переменных
   - Определение переменных с валидацией
   - Значения по умолчанию

3. **Конфигурация mmdebstrap**:
   - Пакеты для установки
   - Хуки для выполнения

### Пример структуры:
```yaml
# METABEGIN
# X-Env-Layer-Name: my-layer
# X-Env-Layer-Category: app
# X-Env-Layer-Desc: My custom layer
# METAEND
---
mmdebstrap:
  packages:
    - my-package
  customize-hooks:
    - my-custom-script.sh
```

## Совместимость с Raspberry Pi

### 🔗 Ссылки на Raspberry Pi документацию

- **Security Hardening**: [https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/security.adoc](https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/security.adoc)
- **SSH Configuration**: [https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/ssh.adoc](https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/ssh.adoc)
- **Firewall Setup**: [https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/network.adoc](https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/network.adoc)
- **User Management**: [https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/user.adoc](https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/user.adoc)

### Raspberry Pi specific слои

Проект включает специализированные слои для Raspberry Pi:
- `rpi/device/` - аппаратная поддержка устройств (Pi 5, Pi 4, CM4)
- `sys-security/` - комплексное hardening (95% совместимости с Raspberry Pi docs)
- `app-container/docker/` - контейнеризация для ARM64

## Лучшие практики

См. файл `LAYER_BEST_PRACTICES` для рекомендаций:
- Использование `set -u` для строгой проверки переменных
- Правильное использование YAML синтаксиса
- Валидация слоев командой lint
- Обработка ошибок в хуках
- Следование Raspberry Pi security guidelines

## Использование

Слои используются в конфигурационных файлах:
```yaml
layer:
  base: bookworm-minbase
  additional:
    - openssh-server
    - ca-certificates
```

## Формат файлов слоев

### Структура YAML файлов

1. **Метаданные** (METABEGIN/METAEND):
   - Определение имени слоя
   - Категория (build, device, image, app)
   - Описание и версия
   - Зависимости и что предоставляет

2. **Переменные окружения**:
   - Префикс для переменных
   - Определение переменных с валидацией
   - Значения по умолчанию

3. **Конфигурация mmdebstrap**:
   - Пакеты для установки
   - Хуки для выполнения

### Пример структуры:
```yaml
# METABEGIN
# X-Env-Layer-Name: my-layer
# X-Env-Layer-Category: app
# X-Env-Layer-Desc: My custom layer
# METAEND
---
mmdebstrap:
  packages:
    - my-package
  customize-hooks:
    - my-custom-script.sh
```

## Доступные шаблоны

### `yaml-layer-template.md`
Шаблон для создания YAML слоев:
- Метаданные для разных категорий слоев
- Структура mmdebstrap конфигурации
- genimage конфигурация для image слоев
- Примеры для base, app, image слоев

## Создание нового слоя

1. **Выберите категорию** слоя (base, app, build, image, device)
2. **Создайте каталог** для категории:
   ```bash
   mkdir layer/my-category
   ```
3. **Создайте файл слоя** на основе шаблона:
   ```bash
   cp scheme/layer/yaml-layer-template.md layer/my-category/my-layer.yaml
   ```
4. **Настройте метаданные** и конфигурацию
5. **Протестируйте слой**:
   ```bash
   rpi-image-gen layer --lint my-category/my-layer
   ```
