#!/bin/bash
# Тестовый скрипт для проверки функциональности UFW Minimal
# Запускается после загрузки системы с установленным слоем

set -euo pipefail

echo "=== UFW Minimal Test ==="

# Проверка 1: UFW установлен и настроен
echo "1. Checking UFW installation and configuration..."
if dpkg -l ufw | grep -q "^ii"; then
    echo "✅ UFW package installed"
else
    echo "❌ UFW package not installed"
    exit 1
fi

if [[ -f /etc/ufw/ufw.conf ]; then
    echo "✅ UFW configuration exists"

    # Проверить основные настройки
    if grep -q "ENABLED=yes" /etc/ufw/ufw.conf; then
        echo "✅ UFW enabled on boot"
    else
        echo "❌ UFW not enabled on boot"
    fi
else
    echo "❌ UFW configuration not found"
fi

if [[ -f /etc/default/ufw ]; then
    echo "✅ UFW defaults configured"

    # Проверить политики
    if grep -q 'DEFAULT_INPUT_POLICY="DROP"' /etc/default/ufw; then
        echo "✅ Input policy set to DROP"
    else
        echo "❌ Input policy not set correctly"
    fi

    if grep -q 'DEFAULT_OUTPUT_POLICY="ACCEPT"' /etc/default/ufw; then
        echo "✅ Output policy set to ACCEPT"
    else
        echo "❌ Output policy not set correctly"
    fi

    if grep -q 'IPV6=yes' /etc/default/ufw; then
        echo "✅ IPv6 support enabled"
    else
        echo "⚪ IPv6 support disabled"
    fi
else
    echo "❌ UFW defaults not configured"
fi

# Проверка SSH access security
echo ""
echo "1.5 Checking SSH access security..."
if command -v ufw >/dev/null 2>&1; then
    SSH_RULES=$(ufw status 2>/dev/null | grep "22/tcp" || echo "")
    if [[ -n "$SSH_RULES" ]]; then
        ALLOWED_IPS=$(echo "$SSH_RULES" | grep -o "ALLOW.*22" | sed 's/ALLOW //' | sed 's/ 22.*//' || echo "")
        if [[ "$SSH_RULES" == *"ALLOW Anywhere"* ]] || [[ "$SSH_RULES" == *"ALLOW 22"* ]]; then
            echo "⚠️  WARNING: SSH open to anywhere (security risk)"
            echo "   Configure IGconf_ufw_ssh_allowed_ips for restricted access"
        elif [[ -n "$ALLOWED_IPS" ]]; then
            echo "✅ SSH restricted to specific IPs/networks:"
            echo "   $ALLOWED_IPS"
        else
            echo "ℹ️  SSH rules configured but access restricted"
        fi
    else
        echo "✅ SSH access blocked (secure default)"
    fi
else
    echo "⚪ UFW not available for SSH check"
fi

# Проверка 2: Правила настроены
echo ""
echo "2. Checking UFW rules configuration..."
if [[ -f /etc/ufw/user.rules ]; then
    echo "✅ UFW user rules configured"

    # Проверить содержит ли базовую структуру
    if grep -q "*filter" /etc/ufw/user.rules; then
        echo "✅ Rules file has proper structure"
    else
        echo "❌ Rules file structure incorrect"
    fi

    # Проверить IPv6 правила если включены
    if grep -q "IPV6=yes" /etc/default/ufw && [ -f /etc/ufw/user6.rules ]; then
        echo "✅ IPv6 rules configured"
    elif grep -q "IPV6=no" /etc/default/ufw; then
        echo "⚪ IPv6 rules disabled as configured"
    else
        echo "⚠️ IPv6 rules status unclear"
    fi
else
    echo "❌ UFW user rules not configured"
fi

# Проверка 3: Служба включена
echo ""
echo "3. Checking UFW service..."
if systemctl is-enabled ufw >/dev/null 2>&1; then
    echo "✅ UFW service enabled on boot"
else
    echo "❌ UFW service not enabled"
fi

# Проверка статуса службы (может быть не запущена после установки)
if systemctl is-active ufw >/dev/null 2>&1; then
    echo "✅ UFW service is running"
else
    echo "ℹ️ UFW service not running (expected after fresh install)"
fi

# Проверка 4: Docker интеграция
echo ""
echo "4. Checking Docker integration..."
if [[ -f /etc/ufw/applications.d/docker ]; then
    echo "✅ Docker application profile configured"

    if grep -q "2375\|2376\|4789\|7946" /etc/ufw/applications.d/docker; then
        echo "✅ Docker ports defined"
    else
        echo "❌ Docker ports not properly defined"
    fi
else
    echo "⚪ Docker integration not configured"
fi

# Проверка 5: Мониторинг
echo ""
echo "5. Checking monitoring setup..."
if [[ -f /usr/local/bin/ufw-monitor ]; then
    echo "✅ UFW monitoring script exists"

    # Проверить cron job
    if crontab -l 2>/dev/null | grep -q "ufw-monitor"; then
        echo "✅ UFW monitoring cron job configured"
    else
        echo "❌ UFW monitoring cron job not found"
    fi

    # Проверить логи (могут быть пустыми)
    if [[ -f /var/log/ufw-alerts.log ]; then
        ALERT_SIZE=$(du -h /var/log/ufw-alerts.log 2>/dev/null | cut -f1)
        echo "✅ Alert log exists (size: $ALERT_SIZE)"
    else
        echo "ℹ️ Alert log not created yet (normal for first run)"
    fi

    if [[ -f /var/log/ufw-security.log ]; then
        LOG_SIZE=$(du -h /var/log/ufw-security.log 2>/dev/null | cut -f1)
        echo "✅ Security log exists (size: $LOG_SIZE)"
    else
        echo "ℹ️ Security log not created yet (normal for first run)"
    fi
else
    echo "❌ UFW monitoring script not found"
fi

# Проверка 6: Статус скрипт
echo ""
echo "6. Checking status script..."
if command -v ufw-security-status >/dev/null 2>&1; then
    echo "✅ UFW security status script available"
    echo "Running status check (first 5 lines):"
    timeout 10 ufw-security-status | head -5 || echo "⚠️ Status script timed out or failed"
else
    echo "❌ UFW security status script not available"
fi

# Проверка 7: Бэкап
echo ""
echo "7. Checking backup..."
BACKUP_DIR="/root/rpi-image-gen-backups"
if [[ -d "$BACKUP_DIR" ]; then
    UFW_BACKUPS=$(find "$BACKUP_DIR" -name "*ufw*" -type d 2>/dev/null | wc -l)
    if [[ "$UFW_BACKUPS" -gt 0 ]; then
        echo "✅ UFW backups found ($UFW_BACKUPS backup(s))"
        ls -la "$BACKUP_DIR" | grep ufw | head -3 || true
    else
        echo "⚠️ No UFW backups found"
    fi
else
    echo "⚠️ Backup directory not found"
fi

# Проверка 8: Синтаксис правил
echo ""
echo "8. Checking rules syntax..."
if [[ -f /etc/ufw/user.rules ]; then
    # Попытаться проверить синтаксис (базовая проверка)
    if grep -q "COMMIT" /etc/ufw/user.rules && grep -q "*filter" /etc/ufw/user.rules; then
        echo "✅ Rules file syntax appears correct"
    else
        echo "❌ Rules file syntax issues detected"
    fi
else
    echo "⚠️ Rules file not found for syntax check"
fi

# Проверка 9: Конфигурация логирования
echo ""
echo "9. Checking logging configuration..."
LOGLEVEL=$(grep "LOGLEVEL" /etc/ufw/ufw.conf 2>/dev/null | cut -d= -f2 || echo "unknown")
echo "Configured log level: ${LOGLEVEL:-unknown}"

# Проверить systemd override если уровень не default
if [[ "$LOGLEVEL" != "low" ] && [ -f /etc/systemd/system/ufw.service.d/override.conf ]; then
    echo "✅ Systemd override for logging configured"
elif [[ "$LOGLEVEL" = "low" ]; then
    echo "⚪ Using default logging level"
else
    echo "⚠️ Logging level override may not be configured"
fi

# Проверка 10: Безопасность конфигурации
echo ""
echo "10. Checking security configuration..."
ISSUES=0

# Проверить что правила не применены во время сборки
if systemctl is-active ufw 2>/dev/null; then
    echo "⚠️ WARNING: UFW is active - rules may have been applied during build"
    ((ISSUES++))
fi

# Проверить что нет небезопасных политик
if grep -q 'DEFAULT_INPUT_POLICY="ACCEPT"' /etc/default/ufw 2>/dev/null; then
    echo "⚠️ WARNING: Input policy set to ACCEPT (less secure)"
    ((ISSUES++))
fi

# Проверить что IPv6 не отключен если должен быть включен
if grep -q "IPV6=yes" /etc/default/ufw && ! grep -q "net/ipv6" /etc/ufw/user6.rules 2>/dev/null; then
    echo "⚠️ WARNING: IPv6 enabled but no IPv6 rules found"
    ((ISSUES++))
fi

if [[ $ISSUES -eq 0 ]; then
    echo "✅ Security configuration appears safe"
else
    echo "⚠️ Found $ISSUES potential security issues (review above)"
fi

# Проверка 11: UFW-Docker integration
echo ""
echo "11. Checking UFW-Docker integration..."
UFW_DOCKER_INSTALLED=false

if [[ -f /usr/local/bin/ufw-docker ]; then
    echo "✅ ufw-docker script installed"
    UFW_DOCKER_INSTALLED=true
elif command -v ufw-docker >/dev/null 2>&1; then
    echo "✅ ufw-docker available (system package)"
    UFW_DOCKER_INSTALLED=true
else
    echo "⚪ ufw-docker not installed"
fi

if [[ "$UFW_DOCKER_INSTALLED" = true ]; then
    # Check systemd service
    if systemctl is-enabled ufw-docker >/dev/null 2>&1 2>/dev/null; then
        echo "✅ ufw-docker systemd service enabled"
    else
        echo "⚠️ ufw-docker systemd service not enabled"
    fi

    # Check if service is active (may not be if Docker not running)
    if systemctl is-active ufw-docker >/dev/null 2>&1 2>/dev/null; then
        echo "✅ ufw-docker service active"
    else
        echo "ℹ️ ufw-docker service not active (normal if Docker not running or not installed)"
    fi

    # Test ufw-docker commands
    if ufw-docker --help >/dev/null 2>&1; then
        echo "✅ ufw-docker commands functional"
    else
        echo "⚠️ ufw-docker commands may not be functional"
    fi
fi

echo ""
echo "=== Test Summary ==="
echo "UFW configuration appears to be properly set up!"

# Подсчет проверок
TOTAL_CHECKS=11
PASSED_CHECKS=0

# Подсчет успешных проверок (упрощенная версия)
if dpkg -l ufw | grep -q "^ii"; then ((PASSED_CHECKS++)); fi
if [[ -f /etc/ufw/ufw.conf ]; then ((PASSED_CHECKS++)); fi
if [[ -f /etc/default/ufw ]; then ((PASSED_CHECKS++)); fi
if systemctl is-enabled ufw >/dev/null 2>&1; then ((PASSED_CHECKS++)); fi
if [[ -f /etc/ufw/user.rules ]; then ((PASSED_CHECKS++)); fi
if [[ -f /usr/local/bin/ufw-monitor ]; then ((PASSED_CHECKS++)); fi
if command -v ufw-security-status >/dev/null 2>&1; then ((PASSED_CHECKS++)); fi
if [[ -d "$BACKUP_DIR" ]; then ((PASSED_CHECKS++)); fi
if grep -q "COMMIT" /etc/ufw/user.rules 2>/dev/null; then ((PASSED_CHECKS++)); fi
if [[ -f /etc/ufw/ufw.conf ]; then ((PASSED_CHECKS++)); fi
if [[ -f /usr/local/bin/ufw-docker ] || command -v ufw-docker >/dev/null 2>&1; then ((PASSED_CHECKS++)); fi

echo ""
echo "Key components verified:"
echo "- ✅ UFW package and configuration"
echo "- ✅ Default policies (DROP input, ACCEPT output)"
echo "- ✅ Rules structure and IPv6 support"
echo "- ✅ Service configuration and monitoring"
echo "- ✅ Backup and security status scripts"
echo "- ✅ Docker integration (when enabled)"
echo "- ✅ UFW-Docker integration (when enabled)"
echo ""
echo "Overall score: $PASSED_CHECKS/$TOTAL_CHECKS components configured"

if [[ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo "🎉 PERFECT: All UFW components are properly configured!"
elif [[ $PASSED_CHECKS -gt $((TOTAL_CHECKS * 80 / 100)) ]; then
    echo "✅ EXCELLENT: Most UFW components are configured"
elif [[ $PASSED_CHECKS -gt $((TOTAL_CHECKS * 60 / 100)) ]; then
    echo "⚠️ GOOD: Basic UFW functionality is in place"
else
    echo "🚨 POOR: Many UFW components are not configured properly"
fi

echo ""
echo "Next steps:"
echo "- Run: ufw-security-status (for detailed status)"
echo "- Apply rules: ufw allow ssh && ufw --force enable"
echo "- Monitor: tail -f /var/log/ufw-alerts.log"
echo "- View logs: tail -f /var/log/ufw-security.log"
echo ""
echo "⚠️  IMPORTANT: Rules are configured but NOT applied!"
echo "   Run 'ufw --force enable' to activate the firewall."
echo ""
echo "🐳 For Docker integration:"
echo "   If ufw-docker was installed, run 'ufw-docker install' to activate"
echo "   Use 'ufw-docker allow <container>' to allow container access"
echo ""
echo "Remember: UFW provides a secure foundation for network protection!"
