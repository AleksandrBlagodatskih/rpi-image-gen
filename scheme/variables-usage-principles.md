# 📋 ПРИНЦИПЫ ИСПОЛЬЗОВАНИЯ ПЕРЕМЕННЫХ В RPI-IMAGE-GEN

## 🎯 ОБЩИЕ ПРИНЦИПЫ

### 🔤 ИМЕНОВАНИЕ ПЕРЕМЕННЫХ

#### Структура именования:
```bash
[ПРЕФИКС]_[КАТЕГОРИЯ]_[ИМЯ_ПЕРЕМЕННОЙ]
```

#### Допустимые символы:
- Буквы: `a-z`, `A-Z`
- Цифры: `0-9` (не в начале)
- Символы: `_` (подчеркивание)

#### Примеры правильных имен:
```bash
IGconf_device_user1           # ✅ Правильно
IGconf_auth_password_min_length  # ✅ Правильно
IGconf_net_ssh_port          # ✅ Правильно
security_kernel_hardening     # ❌ Неправильно (нет префикса IGconf)
user-password                 # ❌ Неправильно (символы кроме _)
```

### 🏷️ ПРЕФИКСЫ ПЕРЕМЕННЫХ

| Префикс | Описание | Пример использования |
|---------|----------|---------------------|
| `IGconf_` | Основной префикс всех переменных | `IGconf_device_user1` |
| `device_` | Переменные устройств | `IGconf_device_user1pass` |
| `auth_` | Аутентификация | `IGconf_auth_password_min_length` |
| `net_` | Сетевые настройки | `IGconf_net_ssh_port` |
| `security_` | Системная безопасность | `IGconf_security_kernel_hardening` |
| `fs_` | Файловые системы | `IGconf_fs_enable_fstab_hardening` |
| `svc_` | Системные сервисы | `IGconf_svc_enable_systemd_hardening` |
| `audit_` | Аудит и логирование | `IGconf_audit_log_retention_days` |

## 🔄 ПРИНЦИПЫ СООТВЕТСТВИЯ ПЕРЕМЕННЫХ

### 📊 КЛАССИФИКАЦИЯ ПЕРЕМЕННЫХ

#### 1. Существующие переменные (основа)
Переменные, определенные в базовых слоях системы:
```bash
IGconf_device_user1           # Имя пользователя
IGconf_device_user1pass       # Пароль пользователя
IGconf_ssh_pubkey_user1       # SSH публичный ключ
IGconf_device_hostname        # Сетевое имя хоста
```

#### 2. Security переменные (дополнение)
Новые переменные для security hardening:
```bash
IGconf_auth_password_min_length   # Усиление требований к паролю
IGconf_net_ssh_port              # Кастомный SSH порт
IGconf_security_kernel_hardening # Kernel hardening
```

### 🎯 ПРИНЦИП "ДОПОЛНЕНИЯ"

**Security переменные НЕ заменяют существующие, а ДОПОЛНЯЮТ их**

#### Правильное использование:
```bash
# 1. Базовые настройки (существующие переменные)
IGconf_device_user1="admin"
IGconf_device_user1pass="MySecurePass123!"

# 2. Дополнительное hardening (security переменные)
IGconf_auth_password_min_length="16"
IGconf_net_ssh_port="2222"
IGconf_layer_additional="user-auth-hardening,network-security-hardening"
```

#### Неправильное использование:
```bash
# ❌ НЕ ДЕЛАЙТЕ ТАК - дублирование функциональности
IGconf_device_user1="admin"
IGconf_auth_user_name="admin"  # Дубликат!
```

## 📝 ПРАВИЛА СОЗДАНИЯ НОВЫХ ПЕРЕМЕННЫХ

### 1. ОПРЕДЕЛЕНИЕ ПРЕФИКСА

#### Для новых категорий слоев:
```yaml
# METABEGIN
# X-Env-VarPrefix: [префикс]
# METAEND
```

#### Примеры префиксов:
```yaml
# Аутентификация
X-Env-VarPrefix: auth

# Сетевая безопасность
X-Env-VarPrefix: net

# Системная безопасность
X-Env-VarPrefix: security
```

### 2. СТРУКТУРА ОПРЕДЕЛЕНИЯ ПЕРЕМЕННОЙ

```yaml
# X-Env-Var-[variable_name]: [default_value]
# X-Env-Var-[variable_name]-Desc: [описание]
# X-Env-Var-[variable_name]-Required: y/n
# X-Env-Var-[variable_name]-Valid: [валидация]
# X-Env-Var-[variable_name]-Set: y/n
```

#### Пример полной структуры:
```yaml
# X-Env-Var-password_min_length: 12
# X-Env-Var-password_min_length-Desc: Минимальная длина пароля
# X-Env-Var-password_min_length-Required: n
# X-Env-Var-password_min_length-Valid: range:8,64
# X-Env-Var-password_min_length-Set: y
```

### 3. ТИПЫ ВАЛИДАЦИИ

#### Ключевые слова:
```yaml
X-Env-Var-[name]-Valid: keywords:y,n,yes,no
```

#### Диапазон значений:
```yaml
X-Env-Var-[name]-Valid: range:1,65535
```

#### Регулярные выражения:
```yaml
X-Env-Var-[name]-Valid: regex:^[a-zA-Z0-9_]+$
```

#### Типы данных:
```yaml
X-Env-Var-[name]-Valid: string
X-Env-Var-[name]-Valid: integer
X-Env-Var-[name]-Valid: boolean
```

## 🚀 ПРАКТИКА ИСПОЛЬЗОВАНИЯ

### 1. МИНИМАЛЬНОЕ ИСПОЛЬЗОВАНИЕ
```bash
# Только базовые настройки
rpi-image-gen build -c config.yaml -- \
  IGconf_device_user1="admin" \
  IGconf_device_user1pass="MyPass123!"
```

### 2. СТАНДАРТНОЕ HARDENING
```bash
# Базовые + security hardening
rpi-image-gen build -c config.yaml -- \
  IGconf_device_user1="admin" \
  IGconf_device_user1pass="MySecurePass123!" \
  IGconf_ssh_pubkey_user1="$(cat ~/.ssh/id_rsa.pub)" \
  IGconf_auth_enable_pam_hardening="y" \
  IGconf_net_enable_iptables_hardening="y" \
  IGconf_layer_additional="user-auth-hardening,network-security-hardening"
```

### 3. МАКСИМАЛЬНОЕ HARDENING
```bash
# Полная настройка
rpi-image-gen build -c config.yaml -- \
  IGconf_device_user1="secureuser" \
  IGconf_device_user1pass="VerySecurePass123!@#" \
  IGconf_ssh_pubkey_only="y" \
  IGconf_net_ssh_port="2222" \
  IGconf_auth_password_min_length="16" \
  IGconf_security_suite_level="full" \
  IGconf_layer_additional="debian-security-suite"
```

## ✅ ПРОВЕРКА И ВАЛИДАЦИЯ

### 1. ПРОВЕРКА СИНТАКСИСА ПЕРЕМЕННЫХ
```bash
# Проверка всех переменных в слое
rpi-image-gen metadata --lint layer/[category]/[layer].yaml

# Проверка конфигурации
rpi-image-gen config --lint config/my-config.yaml
```

### 2. ПРОВЕРКА ЗНАЧЕНИЙ ПЕРЕМЕННЫХ
```bash
# Проверка валидации переменных
igconf isy [префикс]_enable_feature

# Получение значения переменной
igconf getval [префикс]_variable_name
```

### 3. ОТЛАДКА ПЕРЕМЕННЫХ
```bash
# Включение подробного режима
export VERBOSE=1

# Просмотр всех установленных переменных
env | grep IGconf

# Отладка конкретного слоя
rpi-image-gen metadata --debug layer/[category]/[layer].yaml
```

## 📊 ТАБЛИЦА СООТВЕТСТВИЯ ПЕРЕМЕННЫХ

### 🔐 АУТЕНТИФИКАЦИЯ
| Существующие | Security | Связь | Описание |
|--------------|----------|-------|----------|
| `IGconf_device_user1` | - | Основа | Имя пользователя |
| `IGconf_device_user1pass` | `IGconf_auth_password_min_length` | Дополнение | Пароль + требования |
| - | `IGconf_auth_enable_pam_hardening` | Добавление | PAM hardening |
| - | `IGconf_auth_enable_sudo_hardening` | Добавление | Sudo hardening |

### 🌐 СЕТЬ И SSH
| Существующие | Security | Связь | Описание |
|--------------|----------|-------|----------|
| `IGconf_ssh_pubkey_user1` | - | Основа | SSH публичный ключ |
| `IGconf_ssh_pubkey_only` | - | Основа | Только SSH ключи |
| - | `IGconf_net_ssh_port` | Добавление | Кастомный SSH порт |
| - | `IGconf_net_enable_iptables_hardening` | Добавление | iptables hardening |
| - | `IGconf_net_enable_tcp_wrappers` | Добавление | TCP wrappers |

### 🖥️ СИСТЕМА
| Существующие | Security | Связь | Описание |
|--------------|----------|-------|----------|
| `IGconf_device_hostname` | - | Основа | Сетевое имя |
| - | `IGconf_security_kernel_hardening` | Добавление | Kernel hardening |
| - | `IGconf_svc_enable_systemd_hardening` | Добавление | systemd hardening |
| - | `IGconf_svc_enable_cron_hardening` | Добавление | cron hardening |

## 🎯 РЕКОМЕНДАЦИИ

### 1. НАЧИНАЙТЕ С БАЗОВЫХ ПЕРЕМЕННЫХ
```bash
# Сначала настройте базовую функциональность
IGconf_device_user1="admin"
IGconf_device_user1pass="password123"
```

### 2. ДОБАВЛЯЙТЕ SECURITY ПОСТЕПЕННО
```bash
# Затем добавляйте hardening
IGconf_auth_enable_pam_hardening="y"
IGconf_net_enable_iptables_hardening="y"
```

### 3. ТЕСТИРУЙТЕ КОНФИГУРАЦИИ
```bash
# Всегда проверяйте перед использованием
rpi-image-gen config --lint config.yaml
rpi-image-gen build --dry-run -c config.yaml
```

### 4. ДОКУМЕНТИРУЙТЕ ИЗМЕНЕНИЯ
```yaml
# В комментариях указывайте цель изменений
# X-Env-Var-custom_var: "value"  # Усиление безопасности
```

## 📚 ССЫЛКИ

- [Общая схема проекта](../../README.md)
- [Шаблоны слоев](../layer/yaml-layer-template.md)
- [Примеры использования](../examples/)
- [Конфигурации](../config/)

## 📝 ИСТОРИЯ ИЗМЕНЕНИЙ

### v1.0.0 (2024-01-XX)
- Создание принципов использования переменных
- Определение префиксов и правил именования
- Классификация переменных на существующие и security
- Принцип "дополнения" вместо "замены"

### v0.9.0 (2023-XX-XX)
- Начальное определение переменных в базовых слоях
- Введение префикса IGconf_
- Базовая валидация переменных

---

*Этот документ определяет принципы использования переменных в системе rpi-image-gen и обеспечивает согласованность между существующими и новыми переменными security hardening.*
