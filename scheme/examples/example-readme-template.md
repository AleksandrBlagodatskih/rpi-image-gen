# Пример использования rpi-image-gen

## [НАЗВАНИЕ ПРИМЕРА]

[КРАТКОЕ ОПИСАНИЕ ПРИМЕРА]

## Описание

[ПОДРОБНОЕ ОПИСАНИЕ ПРИМЕРА]

### Особенности

- [Особенность 1]
- [Особенность 2]
- [Особенность 3]

### Цели

- [Цель 1]
- [Цель 2]
- [Цель 3]

## Требования

### Системные требования

- ОС: [ОС, например: Linux (Ubuntu 20.04+)]
- Архитектура: [Архитектура, например: amd64/arm64]
- Дисковое пространство: [Требуемое место]
- Оперативная память: [Требуемая память]

### Зависимости

- [Зависимость 1]
- [Зависимость 2]
- [Зависимость 3]

### Установка зависимостей

```bash
# Установка основных зависимостей
sudo apt update
sudo apt install [список пакетов]

# Установка Python зависимостей (если нужно)
pip3 install [список Python пакетов]
```

## Структура примера

```
examples/[example-name]/
├── config/                 # Конфигурационные файлы
│   └── [config].yaml      # Основная конфигурация
├── device/                # Конфигурации устройств (опционально)
│   └── [device]/          # Папка с устройством
├── layer/                 # Пользовательские слои (опционально)
│   └── [layer].yaml       # Кастомный слой
├── scripts/               # Дополнительные скрипты (опционально)
│   └── [script].sh        # Вспомогательный скрипт
├── [files]/               # Дополнительные файлы (опционально)
│   └── [file]             # Конфигурационные файлы, данные
└── README.md              # Эта документация
```

## Использование

### Быстрый старт

```bash
# Переход в каталог примера
cd examples/[example-name]

# Сборка образа
rpi-image-gen build -S ./ -c config/[config].yaml
```

### Подробная сборка

```bash
# 1. Подготовка окружения
export IGTOP=/path/to/rpi-image-gen

# 2. Установка зависимостей
sudo $IGTOP/install_deps.sh

# 3. Сборка образа
rpi-image-gen build \
  --source ./ \
  --config config/[config].yaml \
  --verbose
```

### Дополнительные опции

```bash
# Сборка с пользовательскими переменными
rpi-image-gen build <args> -- \
  IGconf_device_user1pass='mypassword' \
  IGconf_ssh_pubkey_user1="$(cat ~/.ssh/id_rsa.pub)" \
  IGconf_ssh_pubkey_only=y

# Сборка только файловой системы (без образа)
rpi-image-gen build <args> --only-fs

# Сборка только образа (используя существующую ФС)
rpi-image-gen build <args> --only-image
```

## Конфигурация

### Основная конфигурация

Файл: `config/[config].yaml`

```yaml
device:
  layer: "[device-layer]"
  hostname: "[hostname]"
  user1pass: "[password]"

image:
  layer: "[image-layer]"
  boot_part_size: "[boot-size]"
  root_part_size: "[root-size]"
  name: "[image-name]"

layer:
  base: "[base-layer]"
  - "[additional-layers]"
```

### Переменные окружения

| Переменная | Описание | Пример значения |
|------------|----------|-----------------|
| `IGconf_device_user1pass` | Пароль пользователя | `mypassword` |
| `IGconf_ssh_pubkey_user1` | SSH публичный ключ | `ssh-rsa AAA...` |
| `IGconf_ssh_pubkey_only` | Только SSH доступ | `y` |
| `IGconf_sys_workroot` | Рабочий каталог | `./work` |

### Кастомные переменные

```bash
# Установка пользовательских переменных
export CUSTOM_VAR1="value1"
export CUSTOM_VAR2="value2"
```

## Результаты

### Выходные файлы

После успешной сборки создаются:

- `work/[image-name].img` - готовый образ диска
- `work/[image-name].json` - метаданные образа
- `work/rootfs/` - корневая файловая система
- `work/logs/` - логи сборки

### Размер образа

- Минимальный: ~[размер] MB
- Стандартный: ~[размер] MB
- Полный: ~[размер] MB

## Проверка

### Тестирование образа

```bash
# Проверка образа
rpi-image-gen metadata --lint config/[config].yaml

# Валидация слоев
rpi-image-gen layer --lint [layer-name]

# Проверка конфигурации
rpi-image-gen config --lint config/[config].yaml
```

### Монтирование образа

```bash
# Монтирование для проверки
sudo losetup -f work/[image-name].img
sudo mount /dev/loop0p2 /mnt
ls /mnt

# Размонтирование
sudo umount /mnt
sudo losetup -d /dev/loop0
```

## Устранение проблем

### Распространенные ошибки

#### Ошибка 1: [Название ошибки]

**Симптомы:**
- [Симптом 1]
- [Симптом 2]

**Причина:** [Описание причины]

**Решение:**
1. [Шаг 1]
2. [Шаг 2]
3. [Шаг 3]

#### Ошибка 2: [Название ошибки]

**Симптомы:**
- [Симптом 1]
- [Симптом 2]

**Причина:** [Описание причины]

**Решение:**
1. [Шаг 1]
2. [Шаг 2]

### Отладка

```bash
# Включение подробного логирования
export VERBOSE=1

# Включение отладочного режима
set -x

# Просмотр логов
tail -f work/logs/*.log

# Диагностика окружения
rpi-image-gen metadata --debug
```

## Расширение примера

### Создание кастомных слоев

1. Создайте файл `layer/custom-layer.yaml`
2. Определите метаданные слоя
3. Добавьте хуки для настройки
4. Укажите зависимости

### Добавление скриптов

1. Создайте скрипт в `scripts/`
2. Сделайте его исполняемым
3. Добавьте в хуки слоев
4. Протестируйте выполнение

### Интеграция с внешними системами

[Описание интеграции с внешними системами]

## Примеры команд

### Сборка с различными опциями

```bash
# Минимальная сборка
rpi-image-gen build -c config/minimal.yaml

# Сборка с SSH
rpi-image-gen build -c config/ssh.yaml -- \
  IGconf_ssh_pubkey_user1="$(cat ~/.ssh/id_rsa.pub)"

# Сборка с кастомными переменными
rpi-image-gen build -c config/custom.yaml -- \
  CUSTOM_FEATURE1=y CUSTOM_FEATURE2="value"
```

### Очистка

```bash
# Очистка рабочего каталога
rpi-image-gen clean -c config/[config].yaml

# Полная очистка
rm -rf work/
```

## Ссылки

- [Главная документация](../../README.adoc)
- [Руководство по конфигурации](../config/README.md)
- [Справочник по слоям](../layer/README.md)
- [Примеры использования](../examples/README.md)

## Лицензия

Этот пример распространяется под той же лицензией, что и проект rpi-image-gen.

## Поддержка

- [Issues](https://github.com/raspberrypi/rpi-image-gen/issues)
- [Discussions](https://github.com/raspberrypi/rpi-image-gen/discussions)
- [Форумы Raspberry Pi](https://forums.raspberrypi.com/)

---

*Этот пример демонстрирует [основную функциональность]. Для создания собственных примеров используйте шаблоны из `scheme/examples/`.*

