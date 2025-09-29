#!/bin/bash
# Enterprise Cockpit Manager для управления и мониторинга
# Предоставляет инструменты для администрирования Cockpit в enterprise окружении

set -eu

# Конфигурация
COCKPIT_PORT="${COCKPIT_PORT:-8443}"
COCKPIT_URL="https://localhost:${COCKPIT_PORT}"
LOG_FILE="/var/log/cockpit-enterprise.log"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" >> "$LOG_FILE"
}

# Отправка алерта
send_alert() {
    local message="$1"
    local level="${2:-warning}"

    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"Cockpit Alert [${level^^}]: $message\"}" \
            "$ALERT_WEBHOOK" >/dev/null 2>&1 || true
    fi
}

# Проверка доступности Cockpit
check_cockpit_availability() {
    log_info "Проверка доступности Cockpit..."

    if curl -k --max-time 10 -s "$COCKPIT_URL/api/v1/version" >/dev/null 2>&1; then
        log_success "Cockpit доступен на $COCKPIT_URL"
        return 0
    else
        log_error "Cockpit недоступен на $COCKPIT_URL"
        send_alert "Cockpit service is down on $(hostname)" "critical"
        return 1
    fi
}

# Проверка статуса сервисов Cockpit
check_cockpit_services() {
    log_info "Проверка статуса сервисов Cockpit..."

    local socket_status=$(systemctl is-active cockpit.socket 2>/dev/null || echo "inactive")
    local service_status=$(systemctl is-active cockpit.service 2>/dev/null || echo "inactive")

    echo "Cockpit Socket: $socket_status"
    echo "Cockpit Service: $service_status"

    if [ "$socket_status" != "active" ]; then
        log_warn "Cockpit socket не активен"
        send_alert "Cockpit socket is inactive on $(hostname)" "warning"
    fi

    if [ "$service_status" != "active" ] && [ "$service_status" != "inactive" ]; then
        log_error "Cockpit service в неправильном состоянии: $service_status"
        send_alert "Cockpit service status issue on $(hostname)" "critical"
    fi
}

# Проверка сетевой доступности порта
check_cockpit_port() {
    log_info "Проверка доступности порта Cockpit..."

    if netstat -tln | grep -q ":$COCKPIT_PORT "; then
        log_success "Порт $COCKPIT_PORT открыт"
    else
        log_error "Порт $COCKPIT_PORT не открыт"
        send_alert "Cockpit port $COCKPIT_PORT is not accessible on $(hostname)" "critical"
    fi
}

# Проверка firewall правил
check_firewall_rules() {
    log_info "Проверка firewall правил для Cockpit..."

    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "$COCKPIT_PORT/tcp.*ALLOW"; then
            log_success "UFW правило для порта $COCKPIT_PORT настроено"
        else
            log_warn "UFW правило для порта $COCKPIT_PORT отсутствует"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --list-ports | grep -q "$COCKPIT_PORT/tcp"; then
            log_success "FirewallD правило для порта $COCKPIT_PORT настроено"
        else
            log_warn "FirewallD правило для порта $COCKPIT_PORT отсутствует"
        fi
    else
        log_info "Firewall не обнаружен (iptables или другой)"
    fi
}

# Проверка логов Cockpit
check_cockpit_logs() {
    log_info "Анализ логов Cockpit..."

    local error_count=$(journalctl -u cockpit -n 100 --since "1 hour ago" | grep -c "error\|Error\|ERROR" || true)
    local warn_count=$(journalctl -u cockpit -n 100 --since "1 hour ago" | grep -c "warning\|Warning\|WARNING" || true)

    echo "Ошибок в логах за последний час: $error_count"
    echo "Предупреждений в логах за последний час: $warn_count"

    if [ "$error_count" -gt 5 ]; then
        log_error "Обнаружено много ошибок в логах Cockpit ($error_count)"
        send_alert "High error count in Cockpit logs ($error_count) on $(hostname)" "warning"
    fi

    if [ "$warn_count" -gt 10 ]; then
        log_warn "Обнаружено много предупреждений в логах Cockpit ($warn_count)"
    fi
}

# Проверка производительности Cockpit
check_cockpit_performance() {
    log_info "Проверка производительности Cockpit..."

    local memory_usage=$(systemctl show cockpit.service -p MemoryCurrent --value 2>/dev/null | awk '{print $1/1024/1024 " MB"}' || echo "N/A")
    local cpu_usage=$(systemctl show cockpit.service -p CPUUsageNSec --value 2>/dev/null | awk '{print $1/1000000000 " seconds"}' || echo "N/A")

    echo "Использование памяти: $memory_usage"
    echo "Использование CPU: $cpu_usage"

    # Проверка на высокое потребление ресурсов
    if echo "$memory_usage" | grep -q " MB" && [ "$(echo "$memory_usage" | sed 's/ MB//')" -gt 100 ]; then
        log_warn "Высокое потребление памяти Cockpit"
        send_alert "High memory usage by Cockpit on $(hostname)" "warning"
    fi
}

# Проверка аутентификации пользователей
check_user_authentication() {
    log_info "Анализ аутентификации пользователей Cockpit..."

    local auth_attempts=$(journalctl -u cockpit -n 50 --since "1 hour ago" | grep -c "user.*login\|authentication" || true)

    echo "Попыток аутентификации за последний час: $auth_attempts"

    if [ "$auth_attempts" -gt 20 ]; then
        log_warn "Необычно много попыток аутентификации ($auth_attempts)"
        send_alert "Unusual authentication activity on Cockpit ($auth_attempts attempts) on $(hostname)" "warning"
    fi
}

# Генерация enterprise отчета
generate_enterprise_report() {
    log_info "Генерация enterprise отчета Cockpit..."

    local report_file="/var/log/cockpit-enterprise-report-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$report_file" << EOF
ОТЧЕТ ENTERPRISE COCKPIT
========================
Дата: $(date)
Хост: $(hostname)
Пользователь: $(whoami)

КОНФИГУРАЦИЯ COCKPIT:
Порт: $COCKPIT_PORT
URL: $COCKPIT_URL

СТАТУС СЕРВИСОВ:
$(systemctl status cockpit.socket --no-pager -l 2>/dev/null || echo "N/A")
$(systemctl status cockpit.service --no-pager -l 2>/dev/null || echo "N/A")

СЕТЕВАЯ ДОСТУПНОСТЬ:
$(netstat -tlnp | grep ":$COCKPIT_PORT" || echo "Port not found")

FIREWALL ПРАВИЛА:
$(ufw status | grep "$COCKPIT_PORT" 2>/dev/null || firewall-cmd --list-ports 2>/dev/null || echo "N/A")

ЛОГИ ЗА ПОСЛЕДНИЙ ЧАС:
Ошибок: $(journalctl -u cockpit -n 100 --since "1 hour ago" | grep -c "error\|Error\|ERROR" || true)
Предупреждений: $(journalctl -u cockpit -n 100 --since "1 hour ago" | grep -c "warning\|Warning\|WARNING" || true)

ПРОИЗВОДИТЕЛЬНОСТЬ:
Память: $(systemctl show cockpit.service -p MemoryCurrent --value 2>/dev/null | awk '{print $1/1024/1024 " MB"}' || echo "N/A")
CPU: $(systemctl show cockpit.service -p CPUUsageNSec --value 2>/dev/null | awk '{print $1/1000000000 " seconds"}' || echo "N/A")

АУТЕНТИФИКАЦИЯ:
Попыток за час: $(journalctl -u cockpit -n 50 --since "1 hour ago" | grep -c "user.*login\|authentication" || true)

EOF

    log_success "Enterprise отчет сохранен: $report_file"
    return 0
}

# Перезапуск Cockpit сервисов
restart_cockpit_services() {
    log_info "Перезапуск сервисов Cockpit..."

    if systemctl restart cockpit.socket; then
        log_success "Cockpit socket перезапущен"
    else
        log_error "Ошибка при перезапуске cockpit.socket"
        return 1
    fi

    # Service запускается по требованию, так что просто проверяем статус
    sleep 2
    if systemctl status cockpit.service --no-pager >/dev/null 2>&1; then
        log_success "Cockpit service активен"
    else
        log_warn "Cockpit service не активен (это нормально для socket activation)"
    fi
}

# Основная функция мониторинга
run_monitoring_cycle() {
    echo "=== ЦИКЛ МОНИТОРИНГА ENTERPRISE COCKPIT ==="
    echo ""

    check_cockpit_availability
    echo ""

    check_cockpit_services
    echo ""

    check_cockpit_port
    echo ""

    check_firewall_rules
    echo ""

    check_cockpit_logs
    echo ""

    check_cockpit_performance
    echo ""

    check_user_authentication
    echo ""

    generate_enterprise_report
    echo ""

    log_success "Цикл мониторинга завершен"
}

# Основной процесс
main() {
    # Создание директории для логов если не существует
    mkdir -p "$(dirname "$LOG_FILE")"

    # Заголовок
    echo "=== ENTERPRISE COCKPIT MANAGER ==="
    echo "Мониторинг и управление Cockpit в enterprise окружении"
    echo ""

    # Проверка прав доступа
    if [ "$EUID" -ne 0 ]; then
        log_error "Требуются права root для выполнения этого скрипта"
        exit 1
    fi

    # Выполнение мониторинга
    if run_monitoring_cycle; then
        log_success "Мониторинг выполнен успешно"
    else
        log_error "Мониторинг завершен с ошибками"
        exit 1
    fi
}

# Обработка сигналов
cleanup() {
    log_info "Получен сигнал завершения, генерирую финальный отчет..."
    generate_enterprise_report || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Запуск основного процесса
main "$@"
