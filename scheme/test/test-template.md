# Шаблон тестов для rpi-image-gen

## Структура файла: test/[category]/[test-name].[ext]

```bash
#!/bin/bash
# ==========================================
# ТЕСТ RPI-IMAGE-GEN: [TEST_NAME]
# ==========================================
#
# [КРАТКОЕ ОПИСАНИЕ ТЕСТА]
#
# Цели тестирования:
# - [Цель 1]
# - [Цель 2]
# - [Цель 3]
#
# Требования:
# - [Требование 1]
# - [Требование 2]
#
# Использование:
#   ./[test-name].sh
#
# Автор: [AUTHOR_NAME]
# Версия: [VERSION]
# Дата: [DATE]
# ==========================================

# НАСТРОЙКИ ТЕСТА
# ==========================================
set -euo pipefail  # Строгий режим выполнения

# КОНСТАНТЫ
# ==========================================
readonly TEST_NAME="[test-name]"
readonly TEST_VERSION="1.0.0"
readonly TEST_DESCRIPTION="[Описание теста]"

# ЦВЕТА ДЛЯ ВЫВОДА
# ==========================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ==========================================
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"
TEST_RESULTS=()
TEST_COUNT=0
FAILED_TESTS=0
PASSED_TESTS=0

# ФУНКЦИИ ЛОГИРОВАНИЯ
# ==========================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*" >&2
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $*" >&2
}

# ФУНКЦИИ УПРАВЛЕНИЯ ТЕСТАМИ
# ==========================================
show_test_header() {
    cat << EOF
${GREEN}${TEST_NAME}${NC} v${TEST_VERSION}
${TEST_DESCRIPTION}

Запуск: $(date)
Каталог: ${TEST_DIR}
Проект: ${PROJECT_ROOT}

EOF
}

show_test_summary() {
    local total_tests=${#TEST_RESULTS[@]}
    local passed_tests=0
    local failed_tests=0

    for result in "${TEST_RESULTS[@]}"; do
        if [[ "${result}" == "PASS" ]]; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done

    cat << EOF

${GREEN}РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ${NC}
==========================================
Всего тестов: ${total_tests}
Пройдено: ${passed_tests}
Провалено: ${failed_tests}
==========================================

EOF

    if [[ ${failed_tests} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# ФУНКЦИИ ВАЛИДАЦИИ
# ==========================================
validate_environment() {
    log_info "Проверка окружения"

    local missing_deps=()

    # Проверка зависимостей
    for dep in "bdebstrap" "mmdebstrap" "genimage" "python3" "yaml"; do
        if ! command -v "${dep}" >/dev/null 2>&1; then
            missing_deps+=("${dep}")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Отсутствуют зависимости: ${missing_deps[*]}"
        log_info "Установите зависимости: sudo apt install ${missing_deps[*]}"
        return 1
    fi

    # Проверка Python модулей
    if ! python3 -c "import yaml" >/dev/null 2>&1; then
        log_error "Python модуль yaml не установлен"
        return 1
    fi

    log_success "Окружение проверено"
    return 0
}

validate_test_data() {
    log_info "Проверка тестовых данных"

    # Проверка наличия тестовых файлов
    if [[ ! -d "${TEST_DIR}/data" ]]; then
        log_warning "Каталог тестовых данных не найден: ${TEST_DIR}/data"
    fi

    # Проверка конфигурационных файлов
    if [[ ! -f "${PROJECT_ROOT}/config/bookworm-minbase.yaml" ]]; then
        log_error "Файл конфигурации не найден: ${PROJECT_ROOT}/config/bookworm-minbase.yaml"
        return 1
    fi

    log_success "Тестовые данные проверены"
    return 0
}

# ОСНОВНЫЕ ТЕСТОВЫЕ ФУНКЦИИ
# ==========================================
test_[test1]() {
    local test_name="[test1]"
    log_test "Запуск теста: ${test_name}"

    # Инициализация теста
    TEST_COUNT=$((TEST_COUNT + 1))

    # Тестовая логика
    if [condition]; then
        log_success "Тест ${test_name} пройден"
        TEST_RESULTS+=("PASS")
        return 0
    else
        log_error "Тест ${test_name} провален"
        TEST_RESULTS+=("FAIL")
        return 1
    fi
}

test_[test2]() {
    local test_name="[test2]"
    log_test "Запуск теста: ${test_name}"

    # Инициализация теста
    TEST_COUNT=$((TEST_COUNT + 1))

    # Тестовая логика
    if [condition]; then
        log_success "Тест ${test_name} пройден"
        TEST_RESULTS+=("PASS")
        return 0
    else
        log_error "Тест ${test_name} провален"
        TEST_RESULTS+=("FAIL")
        return 1
    fi
}

# ФУНКЦИИ ПОМОЩНИКИ
# ==========================================
setup_test_environment() {
    log_info "Настройка тестового окружения"

    # Создание временных каталогов
    export TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_WORK_DIR="$(mktemp -d)"

    # Настройка путей
    export PATH="${PROJECT_ROOT}/bin:${PATH}"

    log_success "Тестовое окружение настроено"
}

cleanup_test_environment() {
    log_info "Очистка тестового окружения"

    # Удаление временных файлов
    if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi

    if [[ -d "${TEST_WORK_DIR:-}" ]]; then
        rm -rf "${TEST_WORK_DIR}"
    fi

    log_success "Тестовое окружение очищено"
}

# ФУНКЦИИ АНАЛИЗА РЕЗУЛЬТАТОВ
# ==========================================
analyze_results() {
    log_info "Анализ результатов"

    # Подсчет результатов
    local passed=0
    local failed=0

    for result in "${TEST_RESULTS[@]}"; do
        if [[ "${result}" == "PASS" ]]; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    # Вывод статистики
    log_info "Всего тестов: ${TEST_COUNT}"
    log_info "Пройдено: ${passed}"
    log_info "Провалено: ${failed}"

    # Определение успешности
    if [[ ${failed} -eq 0 ]]; then
        log_success "Все тесты пройдены успешно"
        return 0
    else
        log_error "Некоторые тесты провалились"
        return 1
    fi
}

# ФУНКЦИИ ОТЧЕТНОСТИ
# ==========================================
generate_report() {
    local report_file="${TEST_DIR}/test_report_$(date +%Y%m%d_%H%M%S).txt"

    log_info "Генерация отчета: ${report_file}"

    cat > "${report_file}" << EOF
ОТЧЕТ О ТЕСТИРОВАНИИ
====================
Тест: ${TEST_NAME}
Версия: ${TEST_VERSION}
Дата: $(date)
Время выполнения: ${SECONDS}s

РЕЗУЛЬТАТЫ
----------
Всего тестов: ${TEST_COUNT}
Пройдено: ${PASSED_TESTS}
Провалено: ${FAILED_TESTS}

ДЕТАЛИ ТЕСТОВ
-------------
EOF

    # Добавление деталей каждого теста
    local test_index=1
    for result in "${TEST_RESULTS[@]}"; do
        echo "Тест ${test_index}: ${result}" >> "${report_file}"
        ((test_index++))
    done

    log_success "Отчет сгенерирован: ${report_file}"
}

# ОСНОВНАЯ ЛОГИКА ТЕСТИРОВАНИЯ
# ==========================================
run_all_tests() {
    log_info "Запуск всех тестов"

    # Инициализация
    setup_test_environment || {
        log_error "Ошибка настройки окружения"
        return 1
    }

    # Запуск тестов
    local test_functions=(
        "test_[test1]"
        "test_[test2]"
        # Добавьте другие тесты
    )

    for test_func in "${test_functions[@]}"; do
        if [[ "$(type -t "${test_func}")" == "function" ]]; then
            if ! ${test_func}; then
                FAILED_TESTS=$((FAILED_TESTS + 1))
            else
                PASSED_TESTS=$((PASSED_TESTS + 1))
            fi
        else
            log_warning "Функция теста не найдена: ${test_func}"
        fi
    done

    # Анализ результатов
    analyze_results

    # Очистка
    cleanup_test_environment

    # Генерация отчета
    generate_report

    return $((FAILED_TESTS > 0 ? 1 : 0))
}

# ТОЧКА ВХОДА
# ==========================================
main() {
    local exit_code=0

    # Проверка аргументов
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_test_header
                echo "Использование: $0 [ОПЦИИ]"
                echo ""
                echo "ОПЦИИ:"
                echo "  -h, --help     Показать справку"
                echo "  -v, --verbose  Подробный вывод"
                echo "  -q, --quiet    Тихий режим"
                echo ""
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -q|--quiet)
                # Отключить вывод
                shift
                ;;
            *)
                log_error "Неизвестная опция: $1"
                exit 1
                ;;
        esac
    done

    # Проверка окружения
    if ! validate_environment; then
        log_error "Ошибка валидации окружения"
        exit 1
    fi

    # Проверка тестовых данных
    if ! validate_test_data; then
        log_error "Ошибка валидации тестовых данных"
        exit 1
    fi

    # Показ заголовка
    show_test_header

    # Запуск тестов
    if ! run_all_tests; then
        exit_code=1
    fi

    # Показ итогов
    show_test_summary

    exit ${exit_code}
}

# ЗАПУСК ОСНОВНОЙ ФУНКЦИИ
# ==========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## YAML тесты для слоев (test/layer/[test].yaml)

```yaml
# ==========================================
# ТЕСТ СЛОЯ RPI-IMAGE-GEN: [TEST_NAME]
# ==========================================

# БЛОК МЕТАДАННЫХ (METADATA BLOCK)
# ==========================================
# METABEGIN
# X-Env-Layer-Name: [test-layer-name]      # Имя тестового слоя
# X-Env-Layer-Category: test               # Категория: test
# X-Env-Layer-Desc: [Test layer description] # Описание тестового слоя
# X-Env-Layer-Version: 1.0.0               # Версия
# X-Env-Layer-Requires: [dependencies]     # Зависимости
# X-Env-Layer-Provides: test               # Что предоставляет
#
# X-Env-VarPrefix: test                    # Префикс переменных
#
# X-Env-Var-test_variable: "test_value"    # Тестовая переменная
# X-Env-Var-test_variable-Desc: Test variable for validation
# X-Env-Var-test_variable-Required: y      # Обязательность
# X-Env-Var-test_variable-Valid: string    # Валидация
# X-Env-Var-test_variable-Set: y           # Устанавливается
#
# METAEND
# ==========================================

# КОНФИГУРАЦИЯ MMDEBSTRAP (MMDEBSTRAP CONFIG)
# ==========================================
---
mmdebstrap:
  # Тестовые пакеты
  packages:
    - [test-package1]
    - [test-package2]

  # Тестовые хуки
  customize-hooks:
    - |
      #!/bin/bash
      set -euo pipefail

      # Тестовая логика
      echo "Running test customization"

      # Проверка переменных
      if [[ -z "${test_variable:-}" ]]; then
        echo "ERROR: test_variable not set"
        exit 1
      fi

      # Проверка файлов
      if [[ ! -f "/test/file" ]]; then
        echo "ERROR: Test file not found"
        exit 1
      fi

      echo "Test customization completed"
```

## Структура тестового каталога

### test/layer/
```
test/layer/
├── run-tests.sh              # Скрипт запуска тестов
├── valid-*.yaml              # Корректные тестовые слои
├── invalid-*.yaml            # Некорректные тестовые слои
├── test-*.yaml               # Функциональные тесты
├── env/                      # Тесты переменных окружения
│   └── *.yaml
└── fixtures/                 # Тестовые данные
    ├── config/
    ├── layers/
    └── data/
```

### test/integration/
```
test/integration/
├── test-build.sh             # Интеграционные тесты сборки
├── test-config.sh            # Тесты конфигурации
├── test-layers.sh            # Тесты слоев
└── fixtures/                 # Тестовые данные
```

## Типы тестов

### 1. Модульные тесты
- Тестирование отдельных функций
- Изоляция компонентов
- Быстрое выполнение

### 2. Интеграционные тесты
- Тестирование взаимодействия компонентов
- Реальные сценарии использования
- Полная сборка образов

### 3. Валидационные тесты
- Проверка корректности YAML
- Валидация метаданных
- Проверка зависимостей

### 4. Производительные тесты
- Измерение времени выполнения
- Мониторинг использования ресурсов
- Оптимизация процессов

## Лучшие практики тестирования

### Организация тестов
- Один тест - одна функция
- Описательные имена тестов
- Независимое выполнение

### Логирование
- Подробное логирование действий
- Сохранение результатов
- Генерация отчетов

### Очистка
- Удаление временных файлов
- Восстановление окружения
- Обработка ошибок

### Параметризация
- Переменные для разных сценариев
- Конфигурируемые параметры
- Множественные варианты

## Запуск тестов

### Запуск всех тестов
```bash
# Из каталога test/layer/
./run-tests.sh

# Из корня проекта
test/layer/run-tests.sh
```

### Запуск конкретного теста
```bash
# Валидация конкретного слоя
rpi-image-gen metadata --lint layer/[category]/[layer].yaml

# Тестирование конфигурации
rpi-image-gen config --lint config/[config].yaml
```

### Запуск с опциями
```bash
# Подробный вывод
./run-tests.sh --verbose

# Сухой запуск
./run-tests.sh --dry-run

# Только быстрые тесты
./run-tests.sh --quick
```

## Обработка результатов

### Коды завершения
- `0` - все тесты пройдены
- `1` - некоторые тесты провалились
- `2` - ошибка настройки окружения

### Отчеты
- Текстовые отчеты
- XML для CI/CD
- HTML отчеты
- JSON для API

### Интеграция с CI/CD
```yaml
# GitHub Actions
- name: Run tests
  run: |
    ./test/layer/run-tests.sh
    ./test/integration/test-build.sh
```

## Расширение тестов

### Добавление нового теста
```bash
# 1. Создать функцию теста
test_new_feature() {
    log_test "Testing new feature"
    # Логика теста
}

# 2. Добавить в список тестов
test_functions=(
    "test_new_feature"
    # ... другие тесты
)
```

### Создание тестовых данных
```yaml
# test/layer/fixtures/config/test-config.yaml
device:
  layer: rpi5
image:
  layer: image-rpios
  boot_part_size: 200%
  root_part_size: 300%
  name: test-image
layer:
  base: bookworm-minbase
```

## Отладка тестов

### Включение отладочного режима
```bash
export VERBOSE=1
export DEBUG=1
./run-tests.sh
```

### Отладка конкретного теста
```bash
# Запуск с bash -x
bash -x ./test-[name].sh

# Проверка переменных
env | grep -E "(TEST_|IGconf_)"
```

### Логирование в файл
```bash
./run-tests.sh 2>&1 | tee test_log.txt
```

## Примеры тестов

### Тест валидации слоя
```bash
test_layer_validation() {
    log_test "Testing layer validation"

    # Тестирование корректного слоя
    if rpi-image-gen metadata --lint layer/base/device-base.yaml >/dev/null 2>&1; then
        log_success "Valid layer test passed"
        return 0
    else
        log_error "Valid layer test failed"
        return 1
    fi
}
```

### Тест сборки образа
```bash
test_image_build() {
    log_test "Testing image build"

    # Тестирование сборки
    if rpi-image-gen build -c test-config.yaml --dry-run >/dev/null 2>&1; then
        log_success "Image build test passed"
        return 0
    else
        log_error "Image build test failed"
        return 1
    fi
}
```

### Тест зависимостей
```bash
test_dependencies() {
    log_test "Testing dependencies"

    local missing_deps=()

    # Проверка основных команд
    for cmd in "bdebstrap" "mmdebstrap" "genimage" "python3"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_deps+=("${cmd}")
        fi
    done

    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log_success "Dependencies test passed"
        return 0
    else
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
}
```
