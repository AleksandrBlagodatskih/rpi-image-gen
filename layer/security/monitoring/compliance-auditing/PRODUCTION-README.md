# 🔐 Auditd Enterprise Production Guide

## Обзор

Auditd слой предоставляет **enterprise-grade** системное логирование для мониторинга безопасности и compliance в production окружениях Raspberry Pi.

## Основные возможности

### 🔍 Комплексный мониторинг
- **Аутентификация**: Отслеживание всех попыток входа в систему
- **Привилегии**: Мониторинг эскалации привилегий и sudo команд
- **Файловые операции**: Контроль изменений критических системных файлов
- **Сеть**: Мониторинг сетевой конфигурации и соединений
- **Системные вызовы**: Отслеживание потенциально опасных операций

### 📊 Compliance & Standards
- **CIS Benchmarks**: Соответствие Center for Internet Security рекомендациям
- **PCI DSS**: Payment Card Industry Data Security Standard compliance
- **HIPAA**: Health Insurance Portability and Accountability Act готовность
- **GDPR**: General Data Protection Regulation совместимость
- **SOX**: Sarbanes-Oxley Act compliance

## Конфигурация для Production

### Минимальная Production Конфигурация

```yaml
device:
  layer: rpi5
  hostname: prod-audit-server

image:
  layer: image-base
  name: production-audit
  compression: zstd

layer:
  base: bookworm-minbase
  security: auditd

# Production настройки аудита
auditd:
  enable: y
  max_log_file: 10
  max_log_file_action: rotate
  space_left: 100
  space_left_action: syslog
  admin_space_left: 75
  admin_space_left_action: single
  disk_full_action: suspend
  disk_error_action: syslog
  flush: incremental_async
  freq: 50
  num_logs: 5
  dispatcher: /sbin/audispd
  name_format: hostname
```

### Enterprise Production Конфигурация

```yaml
# Полная enterprise конфигурация из примеров выше
# config/enterprise-audit-security.yaml
```

## Мониторинг и Алертинг

### Автоматический Мониторинг

```bash
# Запуск мониторинга аудита
./scripts/production-audit-monitor.sh

# Настройка переменных окружения
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
export EMAIL_RECIPIENT="security-team@company.com"
export CHECK_INTERVAL=300  # 5 минут
```

### Алерты и Уведомления

**Критические алерты:**
- Отказ сервиса auditd
- Высокий backlog аудита (>100)
- Изменения критических файлов (passwd, shadow, sudoers)
- Множественные неудачные попытки аутентификации

**Предупреждения:**
- Необычно высокое использование sudo
- Подозрительная сетевая активность
- Высокий backlog аудита

## Анализ и Отчетность

### Ежедневный Анализ

```bash
# Запуск ежедневного анализа
./scripts/audit-analysis.sh

# Результаты сохраняются в текущей директории
ls audit-compliance-report-*.txt
```

### Compliance Отчеты

Автоматически генерируемые отчеты включают:
- Статус аудита и производительность
- Статистику аутентификации
- Анализ использования привилегий
- Мониторинг изменений файлов
- Сетевую активность

## Интеграция с Enterprise Системами

### Prometheus & Grafana

```yaml
# Метрики аудита для мониторинга
monitoring:
  prometheus_enabled: y
  grafana_enabled: y
  audit_metrics: y
  audit_alerts: y
```

### ELK Stack (Elasticsearch, Logstash, Kibana)

```yaml
# Агрегация логов аудита
monitoring:
  elk_stack: y
  audit_log_forwarding: y
  log_retention: 90d
```

### SIEM Интеграция

- **Splunk**: Автоматическая отправка логов аудита
- **ELK Stack**: Агрегация и анализ в реальном времени
- **Graylog**: Централизованное управление логами

## Производительность и Оптимизация

### Рекомендации по Производительности

1. **Асинхронный режим**: `flush = incremental_async`
2. **Оптимизированная частота**: 50-100 записей для баланса
3. **Автоматическая ротация**: Предотвращает переполнение диска
4. **Правильное размещение**: `/var/log/audit` на быстром диске

### Мониторинг Производительности

```bash
# Проверка производительности аудита
sudo auditctl -s

# Мониторинг backlog
watch 'auditctl -s | grep backlog'

# Анализ размера логов
du -sh /var/log/audit/
```

## Troubleshooting Production Issues

### Auditd не запускается

```bash
# Диагностика проблем
sudo systemctl status auditd
sudo journalctl -u auditd --no-pager

# Проверка конфигурации
sudo auditctl -s

# Перезапуск сервиса
sudo systemctl restart auditd
```

### Высокий Backlog

```bash
# Проверка текущего backlog
sudo auditctl -s | grep backlog

# Увеличение буфера (если нужно)
sudo auditctl -b 8192  # Увеличить до 8192 записей

# Оптимизация правил аудита
sudo auditctl -D  # Очистить все правила
# Затем постепенно добавлять только необходимые
```

### Проблемы с Дисковым Пространством

```bash
# Проверка использования диска
df /var/log/audit/

# Настройка более агрессивной ротации
sudo sed -i 's/num_logs = 5/num_logs = 3/' /etc/audit/auditd.conf

# Перезапуск для применения изменений
sudo systemctl restart auditd
```

## Безопасность и Compliance

### CIS Benchmark Соответствие

Auditd слой автоматически настраивает правила для:
- Мониторинга аутентификации (CIS 4.1)
- Контроля привилегий (CIS 4.2)
- Отслеживания сетевой активности (CIS 4.3)
- Мониторинга изменений файлов (CIS 4.4)

### Регуляторные Требования

- **PCI DSS 10.2**: Логирование всех действий администраторов
- **HIPAA 164.312(b)**: Аудит и мониторинг доступа
- **SOX 404**: Контроль доступа к финансовым системам
- **GDPR Article 30**: Запись действий обработки данных

## Масштабирование и High Availability

### Множественные Узлы

Для enterprise окружений рекомендуется:
1. **Центральный сервер аудита** для агрегации логов
2. **Распределенные агенты** на каждом узле
3. **Автоматическая синхронизация** времени
4. **Резервное копирование** логов аудита

### Производительность в Масштабе

- **Оптимизированные правила**: Только необходимые события
- **Эффективная буферизация**: Баланс между производительностью и надежностью
- **Сетевая агрегация**: Передача логов в центральную систему
- **Автоматическая очистка**: Предотвращение накопления старых логов

## Заключение

Auditd слой предоставляет **enterprise-grade** возможности мониторинга и compliance для production окружений Raspberry Pi. Правильная настройка и мониторинг обеспечивают соответствие регуляторным требованиям и эффективное обнаружение угроз безопасности.

**Ключевые преимущества:**
- ✅ Полный аудит системных событий
- ✅ Соответствие CIS и другим стандартам
- ✅ Интеграция с enterprise системами мониторинга
- ✅ Автоматическое алертинг и отчетность
- ✅ Оптимизированная производительность для production использования
