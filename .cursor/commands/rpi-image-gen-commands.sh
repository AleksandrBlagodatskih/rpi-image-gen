#!/bin/bash
# Быстрые команды для работы с rpi-image-gen расширениями
# Использование: source .cursor/commands/rpi-image-gen-commands.sh

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# === ОСНОВНЫЕ КОМАНДЫ СБОРКИ ===

# Валидация всех расширений проекта
validate_all() {
    log_info "Валидация всех YAML конфигураций..."
    local errors=0

    for file in layer/*.yaml config/*.yaml; do
        if [[ -f "$file" ]; then
            log_info "Проверка: $file"
            if ! rpi-image-gen metadata --lint "$file" 2>/dev/null; then
                log_error "Ошибка валидации: $file"
                ((errors++))
            fi
        fi
    done

    if [[ $errors -eq 0 ]; then
        log_success "Все файлы прошли валидацию"
    else
        log_error "Найдено ошибок: $errors"
        return 1
    fi
}

# Тестовая сборка
build_dry_run() {
    local config="${1:-config.yaml}"
    log_info "Тестовая сборка: $config"
    rpi-image-gen build -c "$config" --dry-run
}

# Полная сборка с логированием
build_full() {
    local config="${1:-config.yaml}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="build_${timestamp}.log"

    log_info "Полная сборка: $config (лог: $log_file)"
    rpi-image-gen build -c "$config" -v 2>&1 | tee "$log_file"

    if [[ $? -eq 0 ]; then
        log_success "Сборка завершена успешно"
        echo "Лог сохранен: $log_file"
    else
        log_error "Сборка завершилась с ошибкой"
        echo "Подробности в логе: $log_file"
        return 1
    fi
}

# === АНАЛИЗ И ДИАГНОСТИКА ===

# Анализ зависимостей слоев
analyze_dependencies() {
    log_info "Анализ зависимостей слоев..."

    for layer_file in layer/*.yaml; do
        if [[ -f "$layer_file" ]; then
            local layer_name=$(basename "$layer_file" .yaml)
            echo "=== $layer_name ==="
            rpi-image-gen layer --describe "$layer_name" 2>/dev/null || echo "Слой не найден или ошибка"
            echo
        fi
    done
}

# Проверка переменных окружения
check_env_vars() {
    log_info "Проверка переменных окружения IGconf_*"

    echo "Текущие переменные окружения:"
    env | grep '^IGconf_' | sort || echo "Переменные IGconf_* не найдены"

    echo -e "\nПеременные в конфигурационных файлах:"
    for file in layer/*.yaml config/*.yaml; do
        if [[ -f "$file" ]; then
            echo "$file:"
            grep -n "IGconf_" "$file" | head -3 || echo "  Нет переменных"
        fi
    done
}

# === ПРОФИЛИРОВАНИЕ И МОНИТОРИНГ ===

# Профилирование сборки
profile_build() {
    local config="${1:-config.yaml}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local profile_file="profile_${timestamp}.log"

    log_info "Профилирование сборки (лог: $profile_file)"

    echo "=== Профиль сборки $(date) ===" > "$profile_file"
    echo "Команда: rpi-image-gen build -c $config" >> "$profile_file"
    echo "Начало: $(date)" >> "$profile_file"

    # Мониторинг ресурсов в фоне
    {
        while kill -0 $$ 2>/dev/null; do
            echo "$(date +%s),$(top -bn1 | grep 'Cpu(s)' | awk '{print $2+$4}'),$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')" >> "$profile_file"
            sleep 2
        done
    } &
    local monitor_pid=$!

    # Запуск сборки с замером времени
    time rpi-image-gen build -c "$config" >> "$profile_file" 2>&1

    # Остановка мониторинга
    kill $monitor_pid 2>/dev/null

    echo "Конец: $(date)" >> "$profile_file"
    log_success "Профилирование завершено: $profile_file"
}

# Мониторинг ресурсов
monitor_resources() {
    local duration="${1:-30}"

    log_info "Мониторинг ресурсов системы ($duration сек)"

    echo "Время,CPU(%),Память(%),Диск(%)"
    local end_time=$(( $(date +%s) + duration ))

    while [ $(date +%s) -lt $end_time ]; do
        local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')
        local mem=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
        local disk=$(df / | awk 'NR==2{print $5}' | sed 's/%//')

        echo "$(date +%H:%M:%S),$cpu,$mem,$disk"
        sleep 5
    done
}

# === УПРАВЛЕНИЕ ПРОЕКТОМ ===

# Создание нового расширения
create_extension() {
    local type="$1"
    local name="$2"

    if [[ -z "$type" ] || [ -z "$name" ]; then
        log_error "Использование: create_extension <type> <name>"
        echo "Типы: device, application, infrastructure"
        return 1
    fi

    local template_file=".cursor/rules/extensions/templates/${type}-extension-template.yaml"
    local target_file="layer/${name}.yaml"

    if [[ ! -f "$template_file" ]; then
        log_error "Шаблон не найден: $template_file"
        return 1
    fi

    cp "$template_file" "$target_file"
    log_success "Создано расширение: $target_file"

    # Замена placeholders
    sed -i "s/\${extension_name}/$name/g" "$target_file"
    sed -i "s/\${app_name}/$name/g" "$target_file"
    sed -i "s/\${device_type}/rpi5/g" "$target_file"
    sed -i "s/\${description}/Расширение $name/g" "$target_file"

    log_info "Отредактируйте файл $target_file для настройки расширения"
}

# Очистка результатов сборки
clean_build() {
    log_info "Очистка результатов сборки..."

    rm -rf work/
    rm -f build_*.log
    rm -f profile_*.log
    rm -f *.img

    log_success "Очистка завершена"
}

# Проверка размера образов
check_image_size() {
    log_info "Проверка размера образов..."

    local images=$(find . -name "*.img" -type f 2>/dev/null)

    if [[ -z "$images" ]; then
        log_warn "Образы не найдены"
        return 1
    fi

    echo "Найденные образы:"
    for img in $images; do
        local size=$(ls -lh "$img" | awk '{print $5}')
        echo "  $img: $size"
    done
}

# === ДОПОЛНИТЕЛЬНЫЕ УТИЛИТЫ ===

# Интерактивное меню
show_menu() {
    echo "=== Быстрые команды rpi-image-gen ==="
    echo "1) Валидация всех расширений"
    echo "2) Тестовая сборка"
    echo "3) Полная сборка с логированием"
    echo "4) Анализ зависимостей"
    echo "5) Проверка переменных окружения"
    echo "6) Профилирование сборки"
    echo "7) Мониторинг ресурсов"
    echo "8) Создание нового расширения"
    echo "9) Очистка результатов сборки"
    echo "10) Проверка размера образов"
    echo "0) Выход"
    echo
    read -p "Выберите действие (0-10): " choice

    case $choice in
        1) validate_all ;;
        2) build_dry_run ;;
        3) build_full ;;
        4) analyze_dependencies ;;
        5) check_env_vars ;;
        6) profile_build ;;
        7) monitor_resources ;;
        8) read -p "Тип расширения (device/application/infrastructure): " type && read -p "Имя расширения: " name && create_extension "$type" "$name" ;;
        9) clean_build ;;
        10) check_image_size ;;
        0) return 0 ;;
        *) log_error "Неверный выбор" && show_menu ;;
    esac
}

# Автодополнение для bash
if [[ -n "$BASH_VERSION" ]; then
    _rpi_commands() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local commands="validate_all build_dry_run build_full analyze_dependencies check_env_vars profile_build monitor_resources create_extension clean_build check_image_size show_menu"

        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    }

    complete -F _rpi_commands validate_all build_dry_run build_full analyze_dependencies check_env_vars profile_build monitor_resources create_extension clean_build check_image_size show_menu
fi

# Если скрипт запущен напрямую, показать меню
if [[[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    show_menu
fi

log_success "Команды rpi-image-gen загружены. Используйте show_menu() для интерактивного режима."
