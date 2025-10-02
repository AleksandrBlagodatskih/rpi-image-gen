# План реструктуризации слоёв безопасности

## Проблемы текущей структуры

### 1. Избыточная глубина вложенности (5 уровней)
```
layer/security/access-control/account-security/password-policies.yaml
└── 1       └── 2              └── 3               └── 4
```

**Стандарт rpi-image-gen:** максимум 3 уровня
```
layer/{category}/{layer-name}/layer.yaml
└── 1       └── 2           └── 3
```

### 2. Излишне длинные имена
- `access-control/mandatory-access-control/` → избыточность
- `privileged-operations-audit/` → слишком длинное
- `network-time-protocol/` → не относится к безопасности напрямую

### 3. Дублирующиеся директории
```
layer/security/access-control/account-security/account-security/
                                            └── дубль!
```

### 4. Неоптимальная категоризация
- `time-sync` в `monitoring/network-time-protocol/` - не security функция
- Слишком много подкатегорий для 10 слоёв

---

## Новая структура (плоская и ясная)

```
layer/security/
├── apparmor/                    # MAC (Mandatory Access Control)
│   ├── apparmor.yaml
│   ├── README.adoc
│   ├── example-config.yaml      # [НОВЫЙ]
│   ├── hooks/
│   │   ├── essential10-apparmor-setup
│   │   ├── customize10-apparmor-profiles
│   │   └── cleanup01-apparmor-finalize
│   └── profiles/
│       ├── sbin.init
│       ├── usr.bin.containerd
│       └── usr.sbin.monitoring
│
├── auditd/                      # Аудит и compliance
│   ├── auditd.yaml
│   ├── README.adoc
│   ├── example-config.yaml      # [НОВЫЙ]
│   ├── PRODUCTION-README.md
│   ├── audit-rules-analysis.adoc
│   ├── compliance-reports-examples.adoc
│   ├── custom-rules-examples.adoc
│   ├── enterprise-performance-analysis.adoc
│   └── siem-integration.adoc
│
├── fail2ban/                    # Intrusion Prevention System
│   ├── fail2ban.yaml
│   ├── README.adoc              # [ПЕРЕМЕСТИТЬ]
│   └── example-config.yaml      # [НОВЫЙ]
│
├── pam-hardening/               # Укрепление аутентификации
│   ├── pam-hardening.yaml
│   ├── README.adoc
│   └── example-config.yaml      # [НОВЫЙ]
│
├── password-policies/           # Политики паролей
│   ├── password-policies.yaml
│   ├── README.adoc
│   └── example-config.yaml      # [НОВЫЙ]
│
├── sudo-logging/                # Аудит привилегированных операций
│   ├── sudo-logging.yaml
│   ├── README.adoc
│   └── example-config.yaml      # [НОВЫЙ]
│
├── sysctl-hardening/            # Укрепление ядра
│   ├── sysctl-hardening.yaml
│   ├── README.adoc
│   └── example-config.yaml      # [НОВЫЙ]
│
├── ufw/                         # Firewall
│   ├── ufw.yaml
│   ├── README.adoc
│   └── example-config.yaml      # [НОВЫЙ]
│
├── unattended-upgrades/         # Автоматические обновления безопасности
│   ├── unattended-upgrades.yaml
│   └── example-config.yaml      # [НОВЫЙ]
│
├── security.yaml                # Мета-слой (комплексное решение)
├── README.adoc                  # Общая документация
└── example-config.yaml          # [НОВЫЙ] Пример комплексной конфигурации
```

**УДАЛИТЬ:** `time-sync` → переместить в `layer/sys-apps/` (не security функция)

---

## Преимущества новой структуры

### ✅ Соответствие стандартам rpi-image-gen
- Максимум 3 уровня вложенности
- Ясные имена директорий
- Структура как у других категорий (sys-apps, net-misc)

### ✅ Улучшенная навигация
```bash
# Было (5 уровней):
cd layer/security/access-control/mandatory-access-control/

# Стало (3 уровня):
cd layer/security/apparmor/
```

### ✅ Логическая группировка
- **MAC:** apparmor
- **Аудит:** auditd, sudo-logging
- **Сеть:** fail2ban, ufw
- **Учётные записи:** pam-hardening, password-policies
- **Система:** sysctl-hardening, unattended-upgrades
- **Мета:** security.yaml

### ✅ Упрощённые зависимости
```yaml
# Было:
X-Env-Layer-Requires: security/access-control/mandatory-access-control

# Стало:
X-Env-Layer-Requires: apparmor
```

---

## Миграция зависимостей в других слоях

### Файлы для обновления:
1. `examples/config-*.yaml` - обновить пути к слоям
2. `examples/enterprise/*.yaml` - обновить зависимости
3. `layer/security/security.yaml` - обновить пути к подслоям
4. Все README с примерами конфигураций

---

## Чеклист выполнения

### Этап 1: Подготовка
- [x] Анализ текущей структуры
- [x] Создание плана реструктуризации
- [ ] Создание резервной копии

### Этап 2: Создание новой структуры
- [ ] Создать директории в новой структуре
- [ ] Переместить .yaml файлы
- [ ] Переместить документацию
- [ ] Переместить hooks и profiles
- [ ] Создать example-config.yaml для каждого слоя

### Этап 3: Обновление метаданных
- [ ] Обновить X-Env-Layer-Name в каждом слое
- [ ] Обновить X-Env-Layer-Category
- [ ] Обновить пути в security.yaml
- [ ] Проверить все зависимости

### Этап 4: Обновление примеров
- [ ] Обновить examples/config-*.yaml
- [ ] Обновить examples/enterprise/*.yaml
- [ ] Обновить test/*.yaml

### Этап 5: Переме

щение time-sync
- [ ] Переместить time-sync в layer/sys-apps/
- [ ] Обновить category в метаданных
- [ ] Обновить зависимости

### Этап 6: Удаление старой структуры
- [ ] Удалить пустые директории access-control/
- [ ] Удалить пустые директории monitoring/
- [ ] Удалить пустые директории network-defense/
- [ ] Удалить пустые директории system-hardening/

### Этап 7: Валидация
- [ ] Запустить lint на всех слоях
- [ ] Проверить примеры конфигураций
- [ ] Запустить тестовую сборку

### Этап 8: Документация
- [ ] Обновить layer/security/README.adoc
- [ ] Добавить MIGRATION.md с инструкциями
- [ ] Обновить главный README.adoc

---

## Команды для выполнения

```bash
# Создание резервной копии
cp -r layer/security layer/security.backup

# Создание новой структуры
mkdir -p layer/security/{apparmor,auditd,fail2ban,pam-hardening,password-policies,sudo-logging,sysctl-hardening,ufw,unattended-upgrades}

# Перемещение файлов (будет выполнено скриптом)
```

---

## Обратная совместимость

**НЕТ** - это breaking change.

**Причина:** Изменение путей к слоям требует обновления всех конфигураций.

**Рекомендация:** 
1. Создать MIGRATION.md с инструкциями
2. Обновить все примеры в репозитории
3. Добавить примечание в CHANGELOG

---

## Время выполнения: ~2 часа

1. Автоматическое перемещение файлов: 15 мин
2. Создание example-config.yaml: 30 мин
3. Обновление метаданных и зависимостей: 30 мин
4. Обновление примеров и тестов: 30 мин
5. Валидация и тестирование: 15 мин

