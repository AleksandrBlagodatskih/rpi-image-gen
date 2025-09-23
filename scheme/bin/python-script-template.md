# Шаблон Python исполняемого скрипта для rpi-image-gen

## Структура файла: bin/[script-name].py

```python
#!/usr/bin/env python3
"""
==========================================
ИСПОЛНЯЕМЫЙ PYTHON СКРИПТ RPI-IMAGE-GEN: [SCRIPT_NAME]
==========================================

[КРАТКОЕ ОПИСАНИЕ СКРИПТА]

Возможности:
- [Возможность 1]
- [Возможность 2]
- [Возможность 3]

Использование:
    python3 [script-name].py [аргументы]

Пример:
    python3 [script-name].py --help

Автор: [AUTHOR_NAME]
Версия: [VERSION]
Дата: [DATE]
==========================================
"""

# СТАНДАРТНЫЕ БИБЛИОТЕКИ
# ==========================================
import os
import sys
import argparse
import logging
from pathlib import Path
from typing import List, Dict, Optional, Any

# ЛОКАЛЬНЫЕ ИМПОРТЫ
# ==========================================
try:
    # Попытка импорта из локальной установки rpi-image-gen
    from logger import log_success, log_warning, log_error
    from env_types import VariableResolver
    LOCAL_IMPORT = True
except ImportError:
    # Fallback для standalone использования
    LOCAL_IMPORT = False

    def log_success(message: str) -> None:
        print(f"✓ {message}")

    def log_warning(message: str) -> None:
        print(f"⚠ {message}", file=sys.stderr)

    def log_error(message: str) -> None:
        print(f"✗ {message}", file=sys.stderr)

# КОНСТАНТЫ И КОНФИГУРАЦИЯ
# ==========================================
SCRIPT_NAME = "[script-name]"
SCRIPT_VERSION = "1.0.0"
SCRIPT_DESCRIPTION = "[Описание скрипта]"

# НАСТРОЙКА ЛОГИРОВАНИЯ
# ==========================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# КЛАСС ОСНОВНОЙ ЛОГИКИ
# ==========================================
class [ClassName]:
    """
    [ОПИСАНИЕ КЛАССА]

    Аргументы:
        config_path (str): Путь к конфигурационному файлу
        verbose (bool): Режим подробного вывода

    Атрибуты:
        config (Dict[str, Any]): Загруженная конфигурация
        work_dir (Path): Рабочий каталог
    """

    def __init__(self, config_path: str = None, verbose: bool = False):
        """
        Инициализация [ClassName].

        Аргументы:
            config_path (str, optional): Путь к конфигурационному файлу
            verbose (bool, optional): Режим подробного вывода
        """
        self.config_path = config_path
        self.verbose = verbose
        self.config: Dict[str, Any] = {}
        self.work_dir = Path.cwd()

        # Определение путей проекта
        self._setup_paths()

        # Загрузка конфигурации
        if self.config_path:
            self.load_config()

        if self.verbose:
            logger.setLevel(logging.DEBUG)
            log_success(f"{SCRIPT_NAME} инициализирован в подробном режиме")

    def _setup_paths(self) -> None:
        """Настройка путей проекта."""
        script_dir = Path(__file__).parent
        self.project_root = script_dir.parent

        # Поиск корня проекта
        if (self.project_root / 'LICENSE').exists():
            self.project_root = self.project_root
        else:
            self.project_root = Path.cwd()

        if self.verbose:
            log_success(f"Корень проекта: {self.project_root}")

    def load_config(self) -> bool:
        """
        Загрузка конфигурации из файла.

        Возвращает:
            bool: True если загрузка успешна, False иначе
        """
        try:
            if LOCAL_IMPORT:
                import yaml
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    self.config = yaml.safe_load(f)
                log_success(f"Конфигурация загружена из: {self.config_path}")
                return True
            else:
                log_warning("YAML модуль недоступен для standalone режима")
                return False
        except Exception as e:
            log_error(f"Ошибка загрузки конфигурации: {e}")
            return False

    def validate_environment(self) -> bool:
        """
        Валидация окружения и зависимостей.

        Возвращает:
            bool: True если окружение корректно, False иначе
        """
        try:
            # Проверка основных команд
            required_commands = ['bdebstrap', 'mmdebstrap', 'genimage']
            missing_commands = []

            for cmd in required_commands:
                if not self._command_exists(cmd):
                    missing_commands.append(cmd)

            if missing_commands:
                log_error(f"Отсутствуют команды: {', '.join(missing_commands)}")
                log_warning("Установите зависимости: sudo apt install bdebstrap mmdebstrap genimage")
                return False

            # Проверка Python модулей
            try:
                import yaml
                import jinja2
            except ImportError as e:
                log_error(f"Отсутствует Python модуль: {e}")
                return False

            log_success("Окружение валидно")
            return True

        except Exception as e:
            log_error(f"Ошибка валидации окружения: {e}")
            return False

    def _command_exists(self, command: str) -> bool:
        """Проверка существования команды в PATH."""
        return os.system(f"command -v {command} >/dev/null 2>&1") == 0

    def run_main_logic(self, **kwargs) -> bool:
        """
        Основная логика скрипта.

        Аргументы:
            **kwargs: Дополнительные параметры

        Возвращает:
            bool: True если выполнение успешно, False иначе
        """
        try:
            log_success(f"Запуск основной логики {SCRIPT_NAME}")

            # Пример основной логики
            if self.verbose:
                log_success("Выполнение в подробном режиме")

            # Здесь реализуется основная логика скрипта
            result = self._process_data(**kwargs)

            log_success(f"Основная логика {SCRIPT_NAME} выполнена успешно")
            return result

        except Exception as e:
            log_error(f"Ошибка выполнения основной логики: {e}")
            return False

    def _process_data(self, **kwargs) -> bool:
        """
        Обработка данных.

        Возвращает:
            bool: True если обработка успешна, False иначе
        """
        # Пример обработки данных
        log_success("Обработка данных...")

        if not self.config:
            log_warning("Конфигурация не загружена, используется конфигурация по умолчанию")

        # Здесь реализуется логика обработки
        return True

    def save_results(self, output_path: str) -> bool:
        """
        Сохранение результатов.

        Аргументы:
            output_path (str): Путь для сохранения

        Возвращает:
            bool: True если сохранение успешно, False иначе
        """
        try:
            output_file = Path(output_path)
            output_file.parent.mkdir(parents=True, exist_ok=True)

            # Пример сохранения
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(f"# Результаты работы {SCRIPT_NAME}\n")
                f.write(f"Время выполнения: {Path.cwd()}\n")
                f.write(f"Конфигурация: {self.config}\n")

            log_success(f"Результаты сохранены в: {output_path}")
            return True

        except Exception as e:
            log_error(f"Ошибка сохранения результатов: {e}")
            return False

# ФУНКЦИИ ПАРСИНГА АРГУМЕНТОВ
# ==========================================
def parse_arguments() -> argparse.Namespace:
    """Разбор аргументов командной строки."""
    parser = argparse.ArgumentParser(
        description=SCRIPT_DESCRIPTION,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Примеры использования:
  python3 {SCRIPT_NAME}.py --help
  python3 {SCRIPT_NAME}.py --verbose --config config.yaml
  python3 {SCRIPT_NAME}.py --dry-run --output results.txt
        """
    )

    parser.add_argument(
        '-c', '--config',
        type=str,
        help='Путь к конфигурационному файлу'
    )

    parser.add_argument(
        '-o', '--output',
        type=str,
        default=f'{SCRIPT_NAME}_output.txt',
        help='Файл для сохранения результатов'
    )

    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Подробный вывод'
    )

    parser.add_argument(
        '-n', '--dry-run',
        action='store_true',
        help='Сухой запуск (только показать действия)'
    )

    parser.add_argument(
        '--version',
        action='version',
        version=f'{SCRIPT_NAME} {SCRIPT_VERSION}'
    )

    return parser.parse_args()

# ОСНОВНАЯ ФУНКЦИЯ
# ==========================================
def main() -> int:
    """
    Основная функция скрипта.

    Возвращает:
        int: Код завершения (0 - успех, 1 - ошибка)
    """
    try:
        # Парсинг аргументов
        args = parse_arguments()

        # Инициализация основного класса
        processor = [ClassName](
            config_path=args.config,
            verbose=args.verbose
        )

        # Валидация окружения
        if not processor.validate_environment():
            return 1

        # Сухой запуск
        if args.dry_run:
            log_success("РЕЖИМ СУХОГО ЗАПУСКА")
            log_success(f"Конфигурация: {args.config or 'по умолчанию'}")
            log_success(f"Вывод: {args.output}")
            return 0

        # Выполнение основной логики
        if processor.run_main_logic():
            # Сохранение результатов
            if processor.save_results(args.output):
                log_success(f"{SCRIPT_NAME} завершен успешно")
                return 0
            else:
                log_error("Ошибка сохранения результатов")
                return 1
        else:
            log_error("Ошибка выполнения основной логики")
            return 1

    except KeyboardInterrupt:
        log_warning("Выполнение прервано пользователем")
        return 130
    except Exception as e:
        log_error(f"Критическая ошибка: {e}")
        return 1

# ТОЧКА ВХОДА
# ==========================================
if __name__ == "__main__":
    sys.exit(main())

# ЗАМЕТКИ РАЗРАБОТЧИКА
# ==========================================
"""
ПРИМЕЧАНИЯ:

1. Для интеграции с rpi-image-gen используйте локальные импорты
2. В standalone режиме используйте встроенные функции логирования
3. Все пути должны быть абсолютными или относительными от корня проекта
4. Используйте валидацию окружения перед выполнением основных операций
5. Поддерживайте как интерактивный, так и автоматический режимы

ИЗВЕСТНЫЕ ПРОБЛЕМЫ:

1. В некоторых системах могут отсутствовать зависимости
2. Путь к локальным модулям должен быть правильно настроен
3. Кодировка файлов должна быть UTF-8

ПЛАНЫ РАЗВИТИЯ:

1. Добавить поддержку плагинов
2. Реализовать параллельную обработку
3. Добавить экспорт в различные форматы
4. Интеграция с CI/CD системами

ИСТОРИЯ ИЗМЕНЕНИЙ:

v1.0.0 (YYYY-MM-DD):
- Начальная реализация
- Поддержка основных операций
- Интеграция с rpi-image-gen
"""
```

## Структура Python скрипта

### 1. Заголовок и документация
- Название скрипта и описание
- Возможности и примеры использования
- Информация об авторе и версии

### 2. Импорты
- Стандартные библиотеки Python
- Локальные импорты из rpi-image-gen
- Fallback для standalone использования

### 3. Константы и конфигурация
- Имена скрипта и версии
- Настройки логирования
- Параметры по умолчанию

### 4. Основной класс
- Инициализация с параметрами
- Валидация окружения
- Основная логика обработки
- Сохранение результатов

### 5. Парсинг аргументов
- argparse для командной строки
- Опции для конфигурации и режимов
- Помощь и примеры использования

### 6. Основная функция
- Обработка аргументов
- Валидация и выполнение
- Обработка ошибок
- Код завершения

### 7. Документация разработчика
- Примечания и известные проблемы
- Планы развития
- История изменений

## Использование

### Создание нового скрипта
```bash
cp scheme/bin/python-script-template.md bin/my-tool.py
# Редактирование с заменой плейсхолдеров
```

### Запуск
```bash
# Справка
python3 bin/my-tool.py --help

# С конфигурацией
python3 bin/my-tool.py --config config.yaml --verbose

# Сухой запуск
python3 bin/my-tool.py --dry-run --output results.txt
```

## Интеграция с rpi-image-gen

Скрипт автоматически интегрируется с системой rpi-image-gen:
- Использует локальную систему логирования
- Работает с переменными окружения IGconf_*
- Интегрируется с CLI через модульную систему
- Поддерживает все этапы сборки

## Лучшие практики

- Используйте валидацию окружения перед выполнением
- Поддерживайте режим сухого запуска для тестирования
- Обрабатывайте все возможные исключения
- Используйте типизацию для лучшей читаемости кода
- Добавляйте подробное логирование для отладки
