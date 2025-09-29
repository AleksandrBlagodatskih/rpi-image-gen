#!/bin/bash
# Производственный мониторинг аудита для enterprise сред
# Автоматический мониторинг и алертинг для критических событий аудита

set -eu

# Конфигурация
LOG_DIR="/var/log/audit"
ALERT_THRESHOLD=10
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-admin@company.com}"
CHECK_INTERVAL=300  # 5 минут

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Отправка алерта в Slack
send_slack_alert() {
    local message="$1"
    local color="danger"

    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"$color\",\"text\":\"$message\",\"ts\":$(date +%s)}]}" \
            "$SLACK_WEBHOOK" >/dev/null 2>&1 || true
    fi
}

# Отправка email алерта
send_email_alert() {
    local subject="$1"
    local message="$2"

    if command -v mail >/dev/null 2>&1 && [ -n "$EMAIL_RECIPIENT" ]; then
        echo "$message" | mail -s "$subject" "$EMAIL_RECIPIENT"
    fi
}

# Проверка статуса аудита
check_audit_status() {
    log_info "Проверка статуса auditd..."

    if ! systemctl is-active --quiet auditd; then
        local alert_msg="CRITICAL: auditd service is down on $(hostname)"
        log_error "$alert_msg"
        send_slack_alert "$alert_msg"
        send_email_alert "Audit Service Down" "$alert_msg"
        return 1
    fi

    # Проверка backlog
    local backlog=$(auditctl -s | grep -o 'backlog=[0-9]*' | cut -d= -f2)
    if [ "${backlog:-0}" -gt 100 ]; then
        local alert_msg="WARNING: High audit backlog ($backlog) on $(hostname)"
        log_warn "$alert_msg"
        send_slack_alert "$alert_msg"
    fi

    log_success "auditd status OK"
    return 0
}

# Анализ неуспешных попыток аутентификации
check_failed_auth() {
    log_info "Анализ неуспешных попыток аутентификации..."

    local failed_count=$(ausearch -m USER_AUTH -sv no -ts today | wc -l)

    if [ "$failed_count" -gt "$ALERT_THRESHOLD" ]; then
        local alert_msg="ALERT: $failed_count failed authentication attempts today on $(hostname)"
        log_warn "$alert_msg"
        send_slack_alert "$alert_msg"
        send_email_alert "Failed Authentication Alert" "$alert_msg"
    fi

    echo "Failed auth attempts: $failed_count"
}

# Анализ использования sudo
check_sudo_usage() {
    log_info "Анализ использования sudo..."

    local sudo_today=$(ausearch -k sudo -ts today | wc -l)
    local sudo_users=$(ausearch -k sudo -ts today | grep -o 'auid=[0-9]*' | sort | uniq | wc -l)

    echo "Sudo commands today: $sudo_today"
    echo "Unique sudo users: $sudo_users"

    # Проверка необычно высокого использования sudo
    if [ "$sudo_today" -gt 50 ]; then
        local alert_msg="WARNING: High sudo usage ($sudo_today commands) on $(hostname)"
        log_warn "$alert_msg"
        send_slack_alert "$alert_msg"
    fi
}

# Анализ изменений критических файлов
check_file_changes() {
    log_info "Анализ изменений критических файлов..."

    local passwd_changes=$(ausearch -k passwd -ts today | wc -l)
    local shadow_changes=$(ausearch -k shadow -ts today | wc -l)
    local sudoers_changes=$(ausearch -k sudoers -ts today | wc -l)

    echo "Passwd changes: $passwd_changes"
    echo "Shadow changes: $shadow_changes"
    echo "Sudoers changes: $sudoers_changes"

    if [ "$passwd_changes" -gt 0 ] || [ "$shadow_changes" -gt 0 ] || [ "$sudoers_changes" -gt 0 ]; then
        local alert_msg="ALERT: Critical file changes detected on $(hostname) - passwd:$passwd_changes shadow:$shadow_changes sudoers:$sudoers_changes"
        log_warn "$alert_msg"
        send_slack_alert "$alert_msg"
        send_email_alert "Critical File Changes" "$alert_msg"
    fi
}

# Анализ сетевой активности
check_network_activity() {
    log_info "Анализ сетевой активности..."

    local network_events=$(ausearch -k network -ts today | wc -l)

    echo "Network events: $network_events"

    # Поиск подозрительной сетевой активности
    local suspicious=$(ausearch -k network -ts today | grep -i "denied\|failed\|error" | wc -l)

    if [ "$suspicious" -gt 5 ]; then
        local alert_msg="WARNING: $suspicious suspicious network events on $(hostname)"
        log_warn "$alert_msg"
        send_slack_alert "$alert_msg"
    fi
}

# Генерация ежедневного отчета
generate_daily_report() {
    log_info "Генерация ежедневного отчета аудита..."

    local report_file="/var/log/audit/daily-report-$(date +%Y%m%d).txt"

    cat > "$report_file" << EOF
ЕЖЕДНЕВНЫЙ ОТЧЕТ АУДИТА
=======================
Дата: $(date)
Хост: $(hostname)
Период: Последние 24 часа

СТАТУС СИСТЕМЫ:
$(auditctl -s)

НЕУСПЕШНЫЕ ПОПЫТКИ АУТЕНТИФИКАЦИИ:
$(ausearch -m USER_AUTH -sv no -ts today | wc -l)

УСПЕШНЫЕ ВХОДЫ ПОЛЬЗОВАТЕЛЕЙ:
$(ausearch -m USER_AUTH -sv yes -ts today | grep -o 'acct="[[:alnum:]]*"' | sort | uniq -c | sort -nr | head -10)

ИЗМЕНЕНИЯ КРИТИЧЕСКИХ ФАЙЛОВ:
Passwd: $(ausearch -k passwd -ts today | wc -l)
Shadow: $(ausearch -k shadow -ts today | wc -l)
Sudoers: $(ausearch -k sudoers -ts today | wc -l)

ИСПЛЬЗОВАНИЕ SUDO:
Команд: $(ausearch -k sudo -ts today | wc -l)
Уникальных пользователей: $(ausearch -k sudo -ts today | grep -o 'auid=[0-9]*' | sort | uniq | wc -l)

СЕТЕВАЯ АКТИВНОСТЬ:
Событий: $(ausearch -k network -ts today | wc -l)
Подозрительных: $(ausearch -k network -ts today | grep -i "denied\|failed\|error" | wc -l)

ЗАГРУЗКА МОДУЛЕЙ ЯДРА:
$(ausearch -k modules -ts today | wc -l)

EOF

    log_success "Ежедневный отчет сохранен: $report_file"
}

# Основной мониторинг цикл
main() {
    echo "=== ПРОИЗВОДСТВЕННЫЙ МОНИТОРИНГ АУДИТА ==="
    echo "Интервал проверки: $CHECK_INTERVAL секунд"
    echo ""

    while true; do
        echo "=== ЦИКЛ МОНИТОРИНГА $(date) ==="

        check_audit_status
        echo ""

        check_failed_auth
        echo ""

        check_sudo_usage
        echo ""

        check_file_changes
        echo ""

        check_network_activity
        echo ""

        # Генерация ежедневного отчета в полночь
        if [ "$(date +%H%M)" = "0000" ]; then
            generate_daily_report
            echo ""
        fi

        log_info "Следующая проверка через $CHECK_INTERVAL секунд..."
        sleep "$CHECK_INTERVAL"
    done
}

# Обработка сигналов для graceful shutdown
cleanup() {
    log_info "Получен сигнал завершения, генерирую финальный отчет..."
    generate_daily_report
    exit 0
}

trap cleanup SIGTERM SIGINT

# Запуск мониторинга
main "$@"
