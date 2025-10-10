#!/bin/bash
# Скрипт для сборки полной конфигурации системы
# Использует все обновленные слои согласно правилам extensions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."

    if ! command -v rpi-image-gen >/dev/null 2>&1; then
        log_error "rpi-image-gen не найден. Запустите: sudo ./install_deps.sh"
        exit 1
    fi

    if ! command -v qemu-user-static >/dev/null 2>&1; then
        log_warn "qemu-user-static не найден. Некоторые функции могут не работать."
    fi

    log_success "Зависимости проверены"
}

# Загрузка переменных окружения
load_environment() {
    local env_file="$PROJECT_ROOT/config/complete-system.env"

    if [[ ! -f "$env_file" ]]; then
        log_error "Файл переменных окружения не найден: $env_file"
        exit 1
    fi

    log_info "Загрузка переменных окружения из: $env_file"

    # Преобразование файла .env в массив аргументов для командной строки
    ENV_VARS=()

    # Добавляем системные переменные
    ENV_VARS+=("IGconf_sys_apt_keydir=/usr/share/keyrings")
    log_info "  IGconf_sys_apt_keydir=/usr/share/keyrings"

    while IFS='=' read -r key value; do
        # Пропускаем комментарии и пустые строки
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Убираем пробелы
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ -n "$key" && -n "$value" ]]; then
            ENV_VARS+=("$key=$value")
            log_info "  $key=$value"
        fi
    done < "$env_file"

    log_success "Загружено ${#ENV_VARS[@]} переменных окружения"
}

# Валидация конфигурации
validate_config() {
    log_info "Валидация конфигурации..."

    local config_file="$PROJECT_ROOT/config/complete-system.yaml"

    if [[ ! -f "$config_file" ]]; then
        log_error "Файл конфигурации не найден: $config_file"
        exit 1
    fi

    if ! "$PROJECT_ROOT/rpi-image-gen" metadata --lint "$config_file"; then
        log_error "Конфигурация не прошла валидацию"
        exit 1
    fi

    log_success "Конфигурация валидна"
}

# Сборка образа
build_image() {
    log_info "Начало сборки образа..."

    local config_file="$PROJECT_ROOT/config/complete-system.yaml"
    local build_cmd=(
        "$PROJECT_ROOT/rpi-image-gen"
        build
        -c "$config_file"
        --
        "${ENV_VARS[@]}"
    )

    log_info "Команда сборки:"
    echo "  ${build_cmd[*]}"

    log_info "Начало сборки... Это может занять значительное время."

    if "${build_cmd[@]}"; then
        log_success "Сборка образа завершена успешно!"
        show_build_results
    else
        log_error "Сборка образа завершилась с ошибкой"
        exit 1
    fi
}

# Показ результатов сборки
show_build_results() {
    log_info "Результаты сборки:"

    # Поиск созданных образов
    local work_dir="$PROJECT_ROOT/work"
    if [[ -d "$work_dir" ]]; then
        find "$work_dir" -name "*.img" -type f | while read -r img_file; do
            local size
            size=$(du -h "$img_file" | cut -f1)
            log_success "Создан образ: $img_file (размер: $size)"
        done
    fi

    # Информация о следующих шагах
    cat << 'EOF'

📋 ДАЛЬНЕЙШИЕ ШАГИ:

1. 🚀 Запись образа на SD-карту:
   sudo rpi-imager --cli work/*/complete-system.img /dev/mmcblk0

2. 🔐 Настройка безопасности при первой загрузке:
   - Измените пароль root
   - Настройте SSH ключи
   - Проверьте статус безопасности: /usr/local/bin/raid-luks-status

3. 📊 Мониторинг:
   - Cockpit: https://rpi-complete-system:9090
   - Status скрипты: /usr/local/bin/*-status

4. 🔧 Диагностика:
   - RAID/LUKS: raid-luks-status
   - AppArmor: apparmor-status
   - Firewall: sudo ufw status

✅ ПОЛНАЯ СИСТЕМА ГОТОВА К ИСПОЛЬЗОВАНИЮ!

EOF
}

# Основная функция
main() {
    log_info "🚀 Сборка полной конфигурации rpi-image-gen"
    log_info "Использует все обновленные слои согласно правилам extensions v2.0.0"

    check_dependencies
    load_environment
    validate_config
    build_image
}

# Проверка аргументов
if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h)
            cat << 'EOF'
Скрипт сборки полной конфигурации rpi-image-gen

Использование:
  ./build-complete-system.sh          # Полная сборка
  ./build-complete-system.sh --help   # Эта справка

Что включает конфигурация:
- ✅ Полная система безопасности (AppArmor, Auditd, Fail2ban, PAM)
- ✅ Гибридное хранилище (RAID1 + LUKS шифрование)
- ✅ Контейнеризация (Distrobox)
- ✅ Сетевое управление (Cockpit)
- ✅ Оптимизации для Raspberry Pi 5 и SATA HAT

Файлы конфигурации:
- config/complete-system.yaml    # Основная конфигурация
- config/complete-system.env     # Переменные окружения

EOF
            exit 0
            ;;
        *)
            log_error "Неизвестный аргумент: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
fi

# Запуск основной функции
main "$@"
