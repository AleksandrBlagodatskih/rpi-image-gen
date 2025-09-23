# Шаблон AsciiDoc документации для rpi-image-gen

## Структура файла: docs/[section]/[document].adoc

```asciidoc
= [НАЗВАНИЕ ДОКУМЕНТА]
[Имя Автора] <email@example.com>
v[VERSION], [DATE]
:sectnums:
:toc: left
:toclevels: 3
:toc-title: Содержание
:description: [КРАТКОЕ ОПИСАНИЕ ДОКУМЕНТА]
:keywords: [ключевые слова через запятую]
:imagesdir: ../images
:stylesdir: ../styles
:scriptsdir: ../scripts

== Введение

[НАЗВАНИЕ ДОКУМЕНТА] - это [КРАТКОЕ ОПИСАНИЕ].

=== Цели документа

* [Цель 1]
* [Цель 2]
* [Цель 3]

=== Целевая аудитория

* [Аудитория 1]
* [Аудитория 2]

== Обзор

=== Концепции

[ОПИСАНИЕ ОСНОВНЫХ КОНЦЕПЦИЙ]

==== [Концепция 1]

[ОПИСАНИЕ КОНЦЕПЦИИ 1]

==== [Концепция 2]

[ОПИСАНИЕ КОНЦЕПЦИИ 2]

=== Архитектура

[ОПИСАНИЕ АРХИТЕКТУРЫ]

[blockdiag]
----
blockdiag {
   // Определение диаграммы
   A -> B -> C;
   A [label = "Компонент A"];
   B [label = "Компонент B"];
   C [label = "Компонент C"];
}
----

== Установка и настройка

=== Требования

* [Требование 1]
* [Требование 2]
* [Требование 3]

=== Установка

. Скачайте проект:
+
[source,bash]
----
git clone https://github.com/raspberrypi/rpi-image-gen.git
----

. Перейдите в каталог проекта:
+
[source,bash]
----
cd rpi-image-gen
----

. Установите зависимости:
+
[source,bash]
----
sudo ./install_deps.sh
----

=== Настройка

==== Базовая настройка

[ОПИСАНИЕ БАЗОВОЙ НАСТРОЙКИ]

==== Дополнительные настройки

[ОПИСАНИЕ ДОПОЛНИТЕЛЬНЫХ НАСТРОЕК]

== Использование

=== Базовое использование

==== [Сценарий 1]

[source,yaml]
----
# Пример конфигурации
device:
  layer: rpi5

image:
  layer: image-rpios
  boot_part_size: 200%
  root_part_size: 300%
  name: my-image

layer:
  base: bookworm-minbase
----

Запуск:

[source,bash]
----
rpi-image-gen build -c config/bookworm-minbase.yaml
----

=== Расширенное использование

==== [Сценарий 2]

[ОПИСАНИЕ РАСШИРЕННОГО ИСПОЛЬЗОВАНИЯ]

== Конфигурация

=== Параметры конфигурации

[cols="1,3,2,2", options="header"]
|===
| Параметр | Описание | Тип | По умолчанию

| [parameter.name]
| [Описание параметра]
| [Тип данных]
| [Значение по умолчанию]

| [parameter.example]
| [Пример параметра]
| string
| default_value
|===

=== Примеры конфигурации

==== Минимальная конфигурация

[source,yaml]
----
# Минимальная конфигурация
device:
  layer: rpi5

image:
  layer: image-rpios
  boot_part_size: 200%
  root_part_size: 300%
  name: minimal

layer:
  base: bookworm-minbase
----

==== Полная конфигурация

[source,yaml]
----
# Полная конфигурация
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
----

== API справочник

=== Классы

==== [ClassName]

[source,python]
----
class [ClassName]:
    """[Описание класса]"""

    def __init__(self, param1=None, param2=None):
        """Инициализация"""
        pass

    def method1(self, arg1):
        """[Описание метода]"""
        pass
----

=== Функции

==== [function_name](args)

[Описание функции]

*Параметры:*
- `arg1` ([type]): [Описание параметра 1]
- `arg2` ([type]): [Описание параметра 2]

*Возвращает:* [type] - [Описание возвращаемого значения]

*Пример:*
[source,python]
----
result = [function_name](arg1, arg2)
----

== Команды и утилиты

=== rpi-image-gen

Основная команда:

[source,bash]
----
rpi-image-gen [command] [options]
----

==== Подкоманды

* `build` - сборка образа
* `clean` - очистка
* `layer` - управление слоями
* `metadata` - работа с метаданными
* `config` - работа с конфигурацией

==== Опции

* `-c, --config FILE` - файл конфигурации
* `-S, --source DIR` - каталог с исходными файлами
* `-B, --build DIR` - каталог сборки
* `-v, --verbose` - подробный вывод
* `-h, --help` - справка

=== Дополнительные утилиты

==== [utility-name]

[source,bash]
----
[utility-name] [options] [arguments]
----

* `-f, --force` - принудительное выполнение
* `-n, --dry-run` - сухой запуск
* `-v, --verbose` - подробный вывод

== Решение проблем

=== Распространенные ошибки

==== Ошибка 1: [Название ошибки]

*Симптомы:*
- [Симптом 1]
- [Симптом 2]

*Причина:* [Описание причины]

*Решение:*
. [Шаг 1]
. [Шаг 2]
. [Шаг 3]

==== Ошибка 2: [Название ошибки]

*Симптомы:*
- [Симптом 1]
- [Симптом 2]

*Причина:* [Описание причины]

*Решение:*
. [Шаг 1]
. [Шаг 2]

=== Диагностика

==== Проверка зависимостей

[source,bash]
----
# Проверка основных зависимостей
command -v bdebstrap >/dev/null 2>&1 || echo "bdebstrap не установлен"
command -v mmdebstrap >/dev/null 2>&1 || echo "mmdebstrap не установлен"
command -v genimage >/dev/null 2>&1 || echo "genimage не установлен"
----

==== Проверка системы

[source,bash]
----
# Проверка архитектуры
uname -m

# Проверка памяти
free -h

# Проверка дискового пространства
df -h
----

=== Логи и отладка

[source,bash]
----
# Включение отладочного режима
export VERBOSE=1

# Просмотр логов
tail -f /var/log/rpi-image-gen/*.log

# Создание отчета об ошибке
rpi-image-gen metadata --debug > debug_report.txt
----

== Справочник

=== Переменные окружения

[cols="1,3,2", options="header"]
|===
| Переменная | Описание | Пример значения

| `IGTOP`
| Путь к корневому каталогу проекта
| `/home/user/rpi-image-gen`

| `SRC_DIR`
| Каталог с исходными файлами
| `./examples`

| `BUILD_DIR`
| Каталог сборки
| `./work`

| `VERBOSE`
| Режим подробного вывода
| `1`

| `DRY_RUN`
| Режим сухого запуска
| `1`
|===

=== Файлы конфигурации

* `config/[name].yaml` - основные конфигурации
* `device/[device]/device.yaml` - конфигурации устройств
* `layer/[category]/[layer].yaml` - слои

=== Каталоги

* `bin/` - исполняемые файлы
* `config/` - конфигурации
* `device/` - устройства
* `docs/` - документация
* `examples/` - примеры
* `image/` - образы
* `layer/` - слои
* `lib/` - библиотеки
* `scripts/` - скрипты
* `site/` - Python модули
* `templates/` - шаблоны
* `test/` - тесты

== Приложения

=== Приложение A: Схема проекта

[blockdiag]
----
blockdiag {
   // Схема архитектуры
   User -> "rpi-image-gen" -> "Layer Manager" -> "mmdebstrap" -> Image;
   "Layer Manager" -> "Config Loader";
   "Layer Manager" -> "Metadata Parser";
   "Config Loader" -> "YAML Config";
   "Metadata Parser" -> "Layer YAML";
}
----

=== Приложение B: Примеры команд

[source,bash]
----
# Сборка базового образа
rpi-image-gen build -c config/bookworm-minbase.yaml

# Сборка с дополнительными слоями
rpi-image-gen build -c config/full-system.yaml

# Очистка рабочего каталога
rpi-image-gen clean -c config/my-config.yaml

# Просмотр доступных слоев
rpi-image-gen layer --list

# Валидация слоя
rpi-image-gen metadata --lint layer/base/device-base.yaml
----

=== Приложение C: Переменные IGconf

[cols="1,3,2", options="header"]
|===
| Переменная | Описание | Секция

| `IGconf_device_layer`
| Слой устройства
| device

| `IGconf_image_layer`
| Слой образа
| image

| `IGconf_layer_base`
| Базовый слой
| layer

| `IGconf_sys_workroot`
| Рабочий каталог
| system

| `IGconf_target_dir`
| Целевой каталог
| system
|===

== Ссылки

=== Внешние ресурсы

* https://github.com/raspberrypi/rpi-image-gen[Проект rpi-image-gen]
* https://github.com/bdrung/bdebstrap[bdebstrap]
* https://gitlab.mister-muffin.de/josch/mmdebstrap[mmdebstrap]
* https://github.com/pengutronix/genimage[genimage]

=== Дополнительная документация

* link:index.adoc[Главная документация]
* link:config/index.adoc[Конфигурация]
* link:layer/index.adoc[Слои]
* link:execution/index.adoc[Выполнение]
* link:provisioning/index.adoc[Развертывание]

=== Сообщество

* https://github.com/raspberrypi/rpi-image-gen/issues[Issues]
* https://github.com/raspberrypi/rpi-image-gen/discussions[Discussions]
* https://forums.raspberrypi.com[Форумы Raspberry Pi]

== История изменений

=== v[VERSION] ([DATE])

* [Изменение 1]
* [Изменение 2]
* [Изменение 3]

=== v[PREVIOUS_VERSION] ([PREVIOUS_DATE])

* [Предыдущее изменение 1]
* [Предыдущее изменение 2]
```

## Структура документа

### 1. Заголовок и метаданные
- Название документа
- Автор и контакты
- Версия и дата
- Настройки AsciiDoc

### 2. Введение
- Описание документа
- Цели и аудитория

### 3. Основные разделы
- Обзор и концепции
- Установка и настройка
- Использование
- Конфигурация

### 4. API справочник
- Классы и функции
- Параметры и возвращаемые значения

### 5. Решение проблем
- Распространенные ошибки
- Диагностика
- Логи и отладка

### 6. Справочная информация
- Переменные окружения
- Файлы и каталоги
- Приложения

## Типы документов

### Руководства пользователя
```asciidoc
= Руководство пользователя rpi-image-gen

== Быстрый старт

=== Установка

=== Первый запуск

== Основные операции

=== Сборка образа

=== Управление слоями
```

### Техническая документация
```asciidoc
= Техническое руководство rpi-image-gen

== Архитектура

=== Компоненты системы

=== Взаимодействие компонентов

== API

=== Классы

=== Методы

=== Функции
```

### Справочники
```asciidoc
= Справочник по конфигурации

== Параметры

=== device

=== image

=== layer

== Примеры

=== Минимальная конфигурация

=== Полная конфигурация
```

### Примеры и руководства
```asciidoc
= Примеры использования

== Базовые примеры

=== Минимальный образ

=== Образ с SSH

== Расширенные примеры

=== A/B обновления

=== Кастомные слои
```

## Соглашения по оформлению

### Заголовки
- `=` - Главный заголовок
- `==` - Раздел
- `===` - Подраздел
- `====` - Под-подраздел

### Текстовые элементы
- `*жирный текст*` - жирный
- `_курсив_` - курсив
- ``+моноширинный+`` - моноширинный
- `моноширинный` - встроенный код

### Списки
- `*` - неупорядоченный список
- `.` - упорядоченный список
- `**` - вложенный список

### Ссылки
- `link:index.adoc[Текст ссылки]` - внутренняя
- `https://example.com[Текст]` - внешняя

### Код
[source,bash]
----
#!/bin/bash
echo "Hello World"
----

### Таблицы
[cols="1,3,2", options="header"]
|===
| Заголовок 1 | Заголовок 2 | Заголовок 3
| Значение 1  | Значение 2  | Значение 3
|===

## Генерация документации

### HTML
```bash
asciidoctor document.adoc
```

### PDF
```bash
asciidoctor-pdf document.adoc
```

### Многостраничная
```bash
asciidoctor -b multipage_html5 document.adoc
```

## Метки и атрибуты

### Условные блоки
```asciidoc
// Только для Linux
ifdef::linux[]
Linux-specific content
endif::linux[]
```

### Атрибуты документа
```asciidoc
:version: 1.0.0
:release-date: 2024-01-01
```

### Перекрестные ссылки
```asciidoc
<<section-name,Текст ссылки>>
```

## Диаграммы

### BlockDiag
```asciidoc
[blockdiag]
----
blockdiag {
   A -> B -> C;
}
----
```

### PlantUML
```asciidoc
[plantuml]
----
@startuml
A -> B: Message
@enduml
----
```

## Включения

### Включение файлов
```asciidoc
include::section.adoc[]
```

### Включение с тегами
```asciidoc
include::section.adoc[tag=snippet]
```

## Замечания и предупреждения

### Замечание
NOTE: Это замечание

### Важно
IMPORTANT: Это важно

### Предупреждение
WARNING: Это предупреждение

### Опасно
CAUTION: Это опасно
