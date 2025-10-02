# Миграция слоёв безопасности

## 📢 ВАЖНО: Breaking Change

Структура слоёв безопасности была **полностью реорганизована** для упрощения и соответствия стандартам rpi-image-gen.

---

## 🔄 Что изменилось

### ❌ Старая структура (5 уровней вложенности)

```
layer/security/
├── access-control/
│   ├── account-security/
│   │   └── password-policies.yaml
│   ├── authentication-hardening/
│   │   └── pam-hardening.yaml
│   ├── mandatory-access-control/
│   │   └── apparmor.yaml
│   └── privileged-operations-audit/
│       └── sudo-logging.yaml
├── monitoring/
│   ├── compliance-auditing/
│   │   └── auditd.yaml
│   ├── network-time-protocol/
│   │   └── time-sync.yaml  # ❌ УДАЛЁН (перемещён в sys-apps)
│   └── system-monitoring/
├── network-defense/
│   ├── firewall-management/
│   │   └── ufw.yaml
│   └── intrusion-prevention/
│       └── fail2ban.yaml
├── system-hardening/
│   ├── kernel-security-tuning/
│   │   └── sysctl-hardening.yaml
│   └── security-updates-automation/
│       └── unattended-upgrades.yaml
└── security.yaml
```

### ✅ Новая структура (3 уровня, плоская иерархия)

```
layer/security/
├── apparmor/
│   ├── apparmor.yaml
│   ├── README.adoc
│   ├── example-config.yaml          # ✨ НОВЫЙ
│   ├── hooks/
│   │   ├── essential10-apparmor-setup
│   │   ├── customize10-apparmor-profiles
│   │   └── cleanup01-apparmor-finalize
│   └── profiles/
│       ├── sbin.init
│       ├── usr.bin.containerd
│       └── usr.sbin.monitoring
│
├── auditd/
│   ├── auditd.yaml
│   ├── README.adoc
│   ├── example-config.yaml          # ✨ НОВЫЙ
│   ├── PRODUCTION-README.md
│   ├── audit-rules-analysis.adoc
│   ├── compliance-reports-examples.adoc
│   ├── custom-rules-examples.adoc
│   ├── enterprise-performance-analysis.adoc
│   └── siem-integration.adoc
│
├── fail2ban/
│   ├── fail2ban.yaml
│   └── example-config.yaml          # ✨ НОВЫЙ
│
├── pam-hardening/
│   ├── pam-hardening.yaml
│   ├── README.adoc
│   └── example-config.yaml          # ✨ НОВЫЙ
│
├── password-policies/
│   ├── password-policies.yaml
│   ├── README.adoc
│   └── example-config.yaml          # ✨ НОВЫЙ
│
├── sudo-logging/
│   ├── sudo-logging.yaml
│   ├── README.adoc
│   └── example-config.yaml          # ✨ НОВЫЙ
│
├── sysctl-hardening/
│   ├── sysctl-hardening.yaml
│   ├── README.adoc
│   └── example-config.yaml          # ✨ НОВЫЙ
│
├── ufw/
│   ├── ufw.yaml
│   ├── README.adoc
│   └── example-config.yaml          # ✨ НОВЫЙ
│
├── unattended-upgrades/
│   ├── unattended-upgrades.yaml
│   └── example-config.yaml          # ✨ НОВЫЙ
│
├── security-suite.yaml              # ✨ Мета-слой (переименован из security.yaml)
├── README.adoc
└── example-config.yaml              # ✨ НОВЫЙ (для мета-слоя)
```

---

## 📋 Таблица миграции

| Старый путь | Новый путь | Действие |
|-------------|------------|----------|
| `security/access-control/mandatory-access-control/apparmor.yaml` | `security/apparmor/apparmor.yaml` | ✅ Переименован |
| `security/monitoring/compliance-auditing/auditd.yaml` | `security/auditd/auditd.yaml` | ✅ Переименован |
| `security/network-defense/intrusion-prevention/fail2ban.yaml` | `security/fail2ban/fail2ban.yaml` | ✅ Переименован |
| `security/access-control/authentication-hardening/pam-hardening.yaml` | `security/pam-hardening/pam-hardening.yaml` | ✅ Переименован |
| `security/access-control/account-security/password-policies.yaml` | `security/password-policies/password-policies.yaml` | ✅ Переименован |
| `security/access-control/privileged-operations-audit/sudo-logging.yaml` | `security/sudo-logging/sudo-logging.yaml` | ✅ Переименован |
| `security/system-hardening/kernel-security-tuning/sysctl-hardening.yaml` | `security/sysctl-hardening/sysctl-hardening.yaml` | ✅ Переименован |
| `security/network-defense/firewall-management/ufw.yaml` | `security/ufw/ufw.yaml` | ✅ Переименован |
| `security/system-hardening/security-updates-automation/unattended-upgrades.yaml` | `security/unattended-upgrades/unattended-upgrades.yaml` | ✅ Переименован |
| `security/monitoring/network-time-protocol/time-sync.yaml` | `sys-apps/time-sync/time-sync.yaml` | ❌ УДАЛЁН из security |
| `security/security.yaml` | `security/security-suite.yaml` | ✅ Переименован (мета-слой) |

---

## 🔧 Как мигрировать свои конфигурации

### 1. Если вы используете полный слой `security`

**Старая конфигурация:**
```yaml
layers:
  - security

variables:
  system_monitoring_enable: y
  system_monitoring_apparmor_enable: y
  system_monitoring_auditd_enable: y
```

**Новая конфигурация:**
```yaml
# Слой переименован: security → security-suite
layers:
  - security-suite

variables:
  system_monitoring_enable: y
  system_monitoring_apparmor_enable: y
  system_monitoring_auditd_enable: y
```

⚠️ **Требуется обновление:** `security` → `security-suite`

---

### 2. Если вы используете отдельные слои

**❌ Старая конфигурация (НЕ РАБОТАЕТ):**
```yaml
layers:
  - security/access-control/mandatory-access-control
  - security/monitoring/compliance-auditing
  - security/network-defense/firewall-management
```

**✅ Новая конфигурация:**
```yaml
layers:
  - apparmor
  - auditd
  - ufw
```

---

### 3. Примеры миграции

#### Пример 1: Минимальная безопасность

**Было:**
```yaml
layers:
  - security/network-defense/firewall-management
  - security/network-defense/intrusion-prevention

variables:
  ufw_enable: y
  ufw_allow_ssh: y
  fail2ban_enable: y
```

**Стало:**
```yaml
layers:
  - ufw
  - fail2ban

variables:
  ufw_enable: y
  ufw_allow_ssh: y
  fail2ban_enable: y
```

---

#### Пример 2: Enterprise безопасность

**Было:**
```yaml
layers:
  - security/access-control/mandatory-access-control
  - security/monitoring/compliance-auditing
  - security/access-control/authentication-hardening
  - security/access-control/account-security
  - security/network-defense/firewall-management
  - security/system-hardening/kernel-security-tuning

variables:
  apparmor_enable: y
  auditd_enable: y
  pam_hardening_enable: y
  password_policies_enable: y
  ufw_enable: y
  sysctl_hardening_enable: y
```

**Стало:**
```yaml
layers:
  - apparmor
  - auditd
  - pam-hardening
  - password-policies
  - ufw
  - sysctl-hardening

variables:
  apparmor_enable: y
  auditd_enable: y
  pam_hardening_enable: y
  password_policies_enable: y
  ufw_enable: y
  sysctl_hardening_enable: y
```

---

#### Пример 3: Использование мета-слоя (рекомендуется)

**Вместо перечисления отдельных слоёв используйте мета-слой security-suite:**

```yaml
layers:
  - security-suite

variables:
  system_monitoring_enable: y
  system_monitoring_apparmor_enable: y
  system_monitoring_auditd_enable: y
  system_monitoring_fail2ban_enable: y
  system_monitoring_authentication_monitoring: y
  system_monitoring_file_access_monitoring: y
  system_monitoring_privilege_monitoring: y
  system_monitoring_network_monitoring: y
```

Это автоматически настроит AppArmor, auditd и Fail2Ban с интеграцией.

---

## 🗑️ Удалённые компоненты

### `time-sync` перемещён в `sys-apps`

**Причина:** Синхронизация времени не является функцией безопасности напрямую.

**Было:**
```yaml
layers:
  - security/monitoring/network-time-protocol
```

**Стало:**
```yaml
layers:
  - time-sync  # Теперь в layer/sys-apps/time-sync/
```

Или используйте `systemd-chrony-min`:
```yaml
layers:
  - systemd-chrony-min
```

---

## ✨ Новые возможности

### 1. Example-config.yaml для всех слоёв

Каждый слой теперь имеет файл `example-config.yaml` с примерами использования:

```bash
# Посмотреть пример конфигурации для AppArmor
cat layer/security/apparmor/example-config.yaml

# Посмотреть пример для auditd
cat layer/security/auditd/example-config.yaml
```

### 2. Улучшенная документация

- Каждый слой имеет README.adoc
- Auditd имеет расширенную enterprise документацию
- Добавлены примеры для compliance (CIS, PCI-DSS, HIPAA, GDPR)

### 3. Упрощённая навигация

```bash
# Было (5 уровней):
cd layer/security/access-control/mandatory-access-control/

# Стало (3 уровня):
cd layer/security/apparmor/
```

---

## 🧪 Тестирование миграции

### Шаг 1: Проверьте валидацию

```bash
# Проверить все слои безопасности
for yaml in layer/security/*/*.yaml; do
  if [[ "$yaml" != *"example-config"* ]]; then
    echo "Checking $yaml"
    ./rpi-image-gen metadata --lint "$yaml"
  fi
done
```

### Шаг 2: Тестовая сборка

```bash
# Создайте тестовую конфигурацию
cat > test-security-migration.yaml << EOF
layers:
  - apparmor
  - auditd
  - ufw

variables:
  apparmor_enable: y
  auditd_enable: y
  ufw_enable: y
  ufw_allow_ssh: y
EOF

# Запустите сборку
./rpi-image-gen build -c test-security-migration.yaml
```

### Шаг 3: Проверьте логи

```bash
# Проверьте логи сборки на наличие ошибок
tail -n 100 work/*/build.log | grep -i error
```

---

## 📦 Резервная копия

Старая структура сохранена в `layer/security.backup/` и `layer/security.old/`:

```bash
# Если нужно откатиться к старой структуре
rm -rf layer/security
mv layer/security.backup layer/security
```

⚠️ **Примечание:** Откат не рекомендуется. Используйте новую структуру.

---

## 🆘 Помощь

### Часто задаваемые вопросы

**Q: Мои старые конфигурации не работают!**  
A: Обновите пути к слоям согласно таблице миграции выше.

**Q: Где теперь time-sync?**  
A: Перемещён в `layer/sys-apps/time-sync/` или используйте `systemd-chrony-min`.

**Q: Как использовать compliance мониторинг?**  
A: См. `layer/security/auditd/example-config.yaml` и документацию.

**Q: Нужно ли обновлять переменные?**  
A: Нет, имена переменных не изменились. Только пути к слоям.

---

## 📚 Дополнительные ресурсы

- `layer/security/README.adoc` - Общая документация по безопасности
- `layer/security/example-config.yaml` - Примеры комплексной конфигурации
- `layer/security/auditd/PRODUCTION-README.md` - Enterprise руководство
- `LAYER_ANALYSIS_REPORT.md` - Подробный анализ слоёв

---

## ✅ Чеклист миграции

- [ ] Прочитал документацию по миграции
- [ ] Обновил пути к слоям в своих конфигурациях
- [ ] Заменил `time-sync` на `systemd-chrony-min` или переместил в `sys-apps`
- [ ] Запустил валидацию конфигураций
- [ ] Выполнил тестовую сборку
- [ ] Проверил логи на наличие ошибок
- [ ] Обновил документацию проекта

---

**Дата миграции:** 2 октября 2025  
**Версия:** 1.0.0  
**Автор:** rpi-image-gen team

