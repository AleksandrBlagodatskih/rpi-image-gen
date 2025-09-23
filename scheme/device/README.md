# Каталог device/ - Конфигурации устройств

Каталог содержит конфигурации для различных моделей устройств Raspberry Pi.

## Структура каталогов

### pi5/
**Назначение**: Конфигурация для Raspberry Pi 5
**Особенности**:
- Поддержка A/B обновлений (image-rota)
- Поддержка NVMe накопителей
- Требует: device-base, rpi-boot-firmware, rpi-linux-2712

### pi4/
**Назначение**: Конфигурация для Raspberry Pi 4
**Особенности**:
- 64-битная архитектура
- Требует: rpi-generic64
- Тип хранения: SD

### pi3/
**Назначение**: Конфигурация для Raspberry Pi 3
**Особенности**:
- 64-битная архитектура
- Требует: rpi-generic64
- Тип хранения: SD

### cm5/
**Назначение**: Конфигурация для Compute Module 5
**Особенности**:
- Встроенный модуль
- Компактная форма

### cm4/
**Назначение**: Конфигурация для Compute Module 4
**Особенности**:
- Встроенный модуль
- Компактная форма

### zero2w/
**Назначение**: Конфигурация для Raspberry Pi Zero 2 W
**Особенности**:
- Компактная модель
- Беспроводная связь

## Формат файлов device.yaml

Каждый файл содержит метаданные и конфигурацию в YAML формате:

### Метаданные (METABEGIN/METAEND)
- `X-Env-Layer-Name` - имя слоя
- `X-Env-Layer-Category` - категория (device)
- `X-Env-Layer-Desc` - описание
- `X-Env-Layer-Version` - версия
- `X-Env-Layer-Requires` - зависимости
- `X-Env-Layer-Provides` - что предоставляет

### Переменные конфигурации
- `class` - класс устройства (pi5, pi4, pi3, etc.)
- `storage_type` - тип носителя (sd, nvme)
- `assetdir` - путь к ресурсам устройства

### Секция mmdebstrap
- `packages` - дополнительные пакеты для установки

## Использование

Файлы используются системой сборки для определения аппаратной конфигурации:

```bash
rpi-image-gen build -c my-config.yaml
```

Где в конфигурации указан device layer, например:
```yaml
device:
  layer: rpi5
```

## Формат файлов device.yaml

Каждый файл содержит метаданные и конфигурацию в YAML формате:

### Метаданные (METABEGIN/METAEND)
- `X-Env-Layer-Name` - имя слоя
- `X-Env-Layer-Category` - категория (device)
- `X-Env-Layer-Desc` - описание
- `X-Env-Layer-Version` - версия
- `X-Env-Layer-Requires` - зависимости
- `X-Env-Layer-Provides` - что предоставляет

### Переменные конфигурации
- `class` - класс устройства (pi5, pi4, pi3, etc.)
- `storage_type` - тип носителя (sd, nvme)
- `assetdir` - путь к ресурсам устройства

### Секция mmdebstrap
- `packages` - дополнительные пакеты для установки

## Доступные шаблоны

### `yaml-device-template.md`
Шаблон для создания конфигураций устройств:
- Структура с метаданными METABEGIN/METAEND
- Переменные окружения X-Env-Var-*
- Конфигурация mmdebstrap
- Примеры для разных устройств

## Создание нового устройства

1. **Создайте каталог** для устройства:
   ```bash
   mkdir device/mydevice
   ```
2. **Создайте файл устройства** на основе шаблона:
   ```bash
   cp scheme/device/yaml-device-template.md device/mydevice/device.yaml
   ```
3. **Настройте метаданные** и переменные под ваше устройство
4. **Протестируйте конфигурацию**:
   ```bash
   rpi-image-gen metadata --lint device/mydevice/device.yaml
   ```
