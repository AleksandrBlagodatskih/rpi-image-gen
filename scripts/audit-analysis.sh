#!/bin/bash
# Enterprise аудит анализ для rpi-image-gen
# Анализирует аудит логи и предоставляет отчеты compliance

set -eu

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Проверка наличия auditd
check_auditd() {
    log_info "Проверка статуса auditd..."

    if systemctl is-active --quiet auditd; then
        log_success "auditd активен"
        auditctl -s
    else
        log_error "auditd не активен"
        log_info "Запуск auditd..."
        sudo systemctl start auditd
        sudo systemctl enable auditd
    fi
}

# Анализ аутентификации
analyze_authentication() {
    log_info "Анализ событий аутентификации..."

    echo "=== АУТЕНТИФИКАЦИЯ ЗА ПОСЛЕДНИЕ 24 ЧАСА ==="
    sudo ausearch -m USER_AUTH -ts today | head -20

    echo ""
    echo "=== НЕУСПЕШНЫЕ ПОПЫТКИ ВХОДА ==="
    sudo ausearch -m USER_AUTH -sv no | wc -l

    echo ""
    echo "=== УСПЕШНЫЕ ВХОДЫ ПОЛЬЗОВАТЕЛЕЙ ==="
    sudo ausearch -m USER_AUTH -sv yes | grep -o 'acct="[[:alnum:]]*"' | sort | uniq -c | sort -nr
}

# Анализ sudo использования
analyze_sudo() {
    log_info "Анализ использования sudo..."

    echo "=== SUDO КОМАНДЫ ЗА ПОСЛЕДНИЕ 24 ЧАСА ==="
    sudo ausearch -m USER_ACCT -ts today | head -20

    echo ""
    echo "=== ТОП ПОЛЬЗОВАТЕЛЕЙ ПО SUDO ИСПОЛЬЗОВАНИЮ ==="
    sudo ausearch -k sudo -ts today | grep -o 'auid=[0-9]*' | sort | uniq -c | sort -nr | head -10
}

# Анализ изменений файлов
analyze_file_changes() {
    log_info "Анализ изменений критических файлов..."

    echo "=== ИЗМЕНЕНИЯ КРИТИЧЕСКИХ ФАЙЛОВ ==="
    sudo ausearch -k passwd -ts today | head -10
    sudo ausearch -k shadow -ts today | head -10
    sudo ausearch -k sudoers -ts today | head -10
}

# Анализ сетевой активности
analyze_network() {
    log_info "Анализ сетевой активности..."

    echo "=== СЕТЕВЫЕ СОЕДИНЕНИЯ ==="
    sudo ausearch -k network -ts today | head -10

    echo ""
    echo "=== ИЗМЕНЕНИЯ ХОСТОВ ==="
    sudo ausearch -k hosts -ts today | head -5
}

# Анализ модулей ядра
analyze_kernel_modules() {
    log_info "Анализ загрузки модулей ядра..."

    echo "=== ЗАГРУЗКА МОДУЛЕЙ ЯДРА ==="
    sudo ausearch -k modules -ts today | head -10
}

# Генерация compliance отчета
generate_compliance_report() {
    log_info "Генерация compliance отчета..."

    REPORT_FILE="audit-compliance-report-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$REPORT_FILE" << EOF
ОТЧЕТ AUDIT COMPLIANCE
======================
Дата: $(date)
Хост: $(hostname)
Пользователь: $(whoami)

СТАТУС AUDITD:
$(sudo auditctl -s)

НЕУСПЕШНЫЕ ПОПЫТКИ АУТЕНТИФИКАЦИИ (24ч):
$(sudo ausearch -m USER_AUTH -sv no -ts today | wc -l)

УСПЕШНЫЕ ВХОДЫ ПОЛЬЗОВАТЕЛЕЙ (24ч):
$(sudo ausearch -m USER_AUTH -sv yes -ts today | grep -o 'acct="[[:alnum:]]*"' | sort | uniq -c | sort -nr)

ИЗМЕНЕНИЯ КРИТИЧЕСКИХ ФАЙЛОВ (24ч):
$(sudo ausearch -k passwd -ts today | wc -l) изменений passwd
$(sudo ausearch -k shadow -ts today | wc -l) изменений shadow
$(sudo ausearch -k sudoers -ts today | wc -l) изменений sudoers

ПРОИЗВОДИТЕЛЬНОСТЬ АУДИТА:
$(sudo auditctl -s | grep -E "(backlog|lost)")

EOF

    log_success "Отчет сохранен в: $REPORT_FILE"
}

# Основной процесс
main() {
    echo "=== ENTERPRISE AUDIT АНАЛИЗ ==="
    echo ""

    check_auditd
    echo ""

    analyze_authentication
    echo ""

    analyze_sudo
    echo ""

    analyze_file_changes
    echo ""

    analyze_network
    echo ""

    analyze_kernel_modules
    echo ""

    generate_compliance_report
    echo ""

    log_success "Анализ завершен"
}

# Запуск основного процесса
main "$@"
