# Raspberry Pi OS Base Image Layer

**Дата:** 2 октября 2025  
**Версия:** 1.0.0  
**Категория:** base-image

---

## 🎯 Описание

Слой **`raspios-base`** позволяет использовать **официальные образы Raspberry Pi OS** в качестве базы для дальнейшей кастомизации. Вместо сборки с нуля, вы начинаете с готового, протестированного и официально поддерживаемого образа.

---

## ✨ Преимущества

### Скорость
- ⚡ **5-10 минут** вместо 30-60 минут сборки с нуля
- ⚡ Кеширование загрузок
- ⚡ Только добавление слоёв поверх готового образа

### Надёжность
- ✅ Официальные образы от Raspberry Pi Foundation
- ✅ Предварительно сконфигурированные и протестированные
- ✅ Регулярные обновления безопасности
- ✅ Полная совместимость с Raspberry Pi

### Безопасность
- 🔒 SHA256 верификация
- 🔒 Автоматическая загрузка checksums
- 🔒 Защита от повреждённых образов
- 🔒 Возможность использования внутренних mirrors

### Гибкость
- 🔧 Применяйте любые слои поверх базы
- 🔧 Поддержка всех версий Raspberry Pi OS
- 🔧 Работа с внутренними mirrors
- 🔧 Полная интеграция с rpi-image-gen

---

## 📦 Поддерживаемые образы

### Raspberry Pi OS Lite (ARM64) - Рекомендуется

**Последний релиз:** Trixie (2025-10-01)

**URL:**
```
https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
```

**SHA256:**
```
https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256
```

**Характеристики:**
- Минимальная установка
- Без графического окружения
- Идеально для серверов
- ~500 MB (сжато)
- Linux 6.12.47
- Debian Trixie (13)

### Raspberry Pi OS Desktop (ARM64)

**URL:** https://downloads.raspberrypi.com/raspios_arm64/images/

**Характеристики:**
- Полное графическое окружение
- Рекомендуемые приложения
- ~1.2 GB (сжато)

### Raspberry Pi OS Full (ARM64)

**URL:** https://downloads.raspberrypi.com/raspios_full_arm64/images/

**Характеристики:**
- Полный набор приложений
- Инструменты разработки
- ~2.5 GB (сжато)

### Legacy Releases

**Bullseye (Debian 11):** https://downloads.raspberrypi.com/raspios_oldstable_lite_arm64/images/  
**Bookworm (Debian 12):** https://downloads.raspberrypi.com/raspios_oldstable_lite_arm64/images/

---

## 🚀 Быстрый старт

### 1. Минимальная конфигурация

```yaml
device:
  layer: rpi5

image:
  layer: standard
  name: my-raspios

layer:
  base: raspios-base

raspios_base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256
```

### 2. Сборка

```bash
./rpi-image-gen build -c config.yaml
```

### 3. Результат

Готовый образ с применёнными слоями будет в `./work/image-*/`.

---

## 🔧 Переменные конфигурации

| Переменная | Значение по умолчанию | Обязательна | Описание |
|------------|----------------------|-------------|----------|
| `raspios_base_image_url` | - | **Да** | URL образа Raspberry Pi OS |
| `raspios_base_image_sha256` | - | Нет | SHA256 checksum (прямой) |
| `raspios_base_image_sha256_url` | - | Нет | URL к SHA256 файлу |
| `raspios_base_cache_dir` | `./cache` | Нет | Директория кеша |
| `raspios_base_verify_checksum` | `y` | Нет | Проверять SHA256 |
| `raspios_base_force_redownload` | `n` | Нет | Принудительная загрузка |
| `raspios_base_extract_format` | `auto` | Нет | Формат сжатия |
| `raspios_base_target_device` | `rpi5` | Нет | Целевое устройство |

---

## 📚 Примеры использования

### Пример 1: Минимальная безопасная система

```yaml
device:
  layer: rpi5

image:
  layer: standard
  name: raspios-minimal

layer:
  base: raspios-base

raspios_base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

layers:
  - security/ufw
  - security/unattended-upgrades
```

**Время сборки:** ~7 минут

---

### Пример 2: Полная защита

```yaml
device:
  layer: rpi5

image:
  layer: standard
  name: raspios-secure

layer:
  base: raspios-base

raspios_base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

layers:
  - security-suite

security_suite_mode: hardened
```

**Время сборки:** ~10 минут

---

### Пример 3: С веб-управлением

```yaml
device:
  layer: rpi5

image:
  layer: standard
  name: raspios-cockpit

layer:
  base: raspios-base

raspios_base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

layers:
  - security/apparmor
  - security/ufw
  - net-misc/cockpit

cockpit_enable: y
ufw_allow_ports: "22,9090"
```

**Доступ:** https://raspberry-ip:9090

---

### Пример 4: Enterprise с внутренним mirror

```yaml
device:
  layer: rpi-cm5
  variant: 8G

image:
  layer: standard
  name: raspios-enterprise

layer:
  base: raspios-base

# Внутренний mirror компании
raspios_base_image_url: https://mirror.company.internal/raspios/trixie-arm64-lite.img.xz
raspios_base_image_sha256: "verified_checksum_from_security_audit_12345abcdef..."
raspios_base_verify_checksum: y
raspios_base_cache_dir: /opt/cache

layers:
  - security-suite
  - net-misc/cockpit
  - app-misc/rpi5-server-config

security_suite_mode: enterprise
```

---

## 🔒 SHA256 Verification

### Автоматическая проверка (рекомендуется)

```yaml
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/.../image.img.xz.sha256
```

Слой автоматически:
1. Загрузит SHA256 файл
2. Извлечёт checksum (5 форматов)
3. Проверит целостность образа
4. Остановится при ошибке

### Прямой checksum

```yaml
raspios_base_image_sha256: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd"
```

### Получение SHA256

```bash
# С официального сайта
wget https://downloads.raspberrypi.com/.../image.img.xz.sha256 -O - | cat

# Локально
sha256sum ./cache/image.img.xz

# Проверка
sha256sum -c image.img.xz.sha256
```

---

## 📊 Производительность

| Операция | Время | Примечания |
|----------|-------|------------|
| Загрузка (кеш) | 0s | Мгновенно |
| Загрузка (новая) | 2-5 мин | Зависит от связи |
| Извлечение | 1-2 мин | xz декомпрессия |
| Верификация | 30-60s | SHA256 |
| Применение слоёв | 2-5 мин | Зависит от слоёв |
| **Итого (первый раз)** | **5-12 мин** | vs 30-60 мин с нуля |
| **Итого (кеш)** | **3-7 мин** | Только слои |

---

## 🔧 Расширенная конфигурация

### Кеширование

```yaml
# Использовать большое хранилище
raspios_base_cache_dir: /mnt/storage/cache

# Принудительная загрузка
raspios_base_force_redownload: y
```

### Формат сжатия

```yaml
# Автоопределение (по умолчанию)
raspios_base_extract_format: auto

# Явное указание
raspios_base_extract_format: xz  # или gz, zip, none
```

### Пропуск верификации (НЕ рекомендуется)

```yaml
# Только для dev!
raspios_base_verify_checksum: n
```

---

## 🌐 Работа с mirrors

### Официальный mirror

```yaml
raspios_base_image_url: https://downloads.raspberrypi.com/.../image.img.xz
```

### Внутренний mirror компании

```yaml
# HTTP mirror
raspios_base_image_url: http://mirror.company.internal/images/raspios-trixie.img.xz
raspios_base_image_sha256: "verified_checksum"

# HTTPS mirror
raspios_base_image_url: https://secure-mirror.company.internal/images/raspios-trixie.img.xz
raspios_base_image_sha256: "verified_checksum"
```

### Локальный файл

```yaml
# Файловый путь
raspios_base_image_url: file:///opt/images/raspios-trixie-arm64-lite.img.xz
raspios_base_verify_checksum: n
```

---

## 🐛 Troubleshooting

### Ошибка загрузки

**Проблема:** Не удаётся загрузить образ

**Решение:**
```bash
# Проверьте URL
curl -I https://downloads.raspberrypi.com/.../image.img.xz

# Проверьте сеть
ping downloads.raspberrypi.com

# Используйте другой mirror
raspios_base_image_url: <alternative_url>
```

### SHA256 не совпадает

**Проблема:** Checksum mismatch

**Решение:**
```bash
# Удалите кеш
rm -rf ./cache/*

# Принудительная загрузка
raspios_base_force_redownload: y

# Проверьте вручную
sha256sum ./cache/image.img.xz
```

### Не хватает места

**Проблема:** Disk full

**Решение:**
```bash
# Очистите кеш
rm -rf ./cache/*

# Используйте другое хранилище
raspios_base_cache_dir: /mnt/large-storage/cache
```

### Ошибка извлечения

**Проблема:** Extraction failed

**Решение:**
```yaml
# Укажите формат явно
raspios_base_extract_format: xz

# Проверьте, что образ не повреждён
raspios_base_verify_checksum: y
```

---

## 📖 Интеграция с другими слоями

### Security Suite

```yaml
layer:
  base: raspios-base

layers:
  - security-suite
```

### RAID

```yaml
layer:
  base: raspios-base

image:
  layer: mdraid1-external-root
  
layers:
  - security-suite
```

### Containers

```yaml
layer:
  base: raspios-base

layers:
  - app-container/distrobox
  - security/apparmor
```

---

## ✅ Best Practices

### Для разработки
```yaml
raspios_base_verify_checksum: n  # Можно пропустить
raspios_base_force_redownload: n  # Использовать кеш
```

### Для staging
```yaml
raspios_base_verify_checksum: y  # Рекомендуется
raspios_base_image_sha256_url: https://...  # Auto-download
```

### Для production
```yaml
raspios_base_verify_checksum: y  # Обязательно
raspios_base_image_sha256: "verified..."  # Прямой checksum
# Храните checksum в version control
```

### Для enterprise
```yaml
# Используйте внутренний mirror
raspios_base_image_url: https://internal-mirror.company/...
raspios_base_image_sha256: "audited_checksum"
raspios_base_verify_checksum: y
# Аудит и документирование обязательны
```

---

## 📚 Связанная документация

- [SHA256 Verification](./SHA256_VERIFICATION.md)
- [Trixie Base Image](./TRIXIE_BASE_IMAGE.md)
- [Security Suite](../layer/security/security-suite.yaml)
- [Layer Best Practices](../layer/LAYER_BEST_PRACTICES)
- [Raspberry Pi OS Downloads](https://www.raspberrypi.com/software/operating-systems/)

---

## 🎯 Сравнение подходов

| Характеристика | Сборка с нуля | raspios-base слой |
|----------------|---------------|-------------------|
| Время сборки | 30-60 минут | 5-12 минут |
| Официальный образ | Нет | Да |
| Кастомизация | Полная | Слои поверх базы |
| Обновления | Пересборка | Новый base + слои |
| Сложность | Высокая | Низкая |
| Надёжность | Зависит | Высокая |
| Тестирование | Требуется | Минимально |

---

## ⚡ Готовые конфигурации

В проекте доступны готовые конфигурации:

- `config/raspios-base-minimal.yaml` - Минимальная система
- `config/raspios-base-secure.yaml` - С полной защитой
- `examples/raspios-base-with-cockpit.yaml` - С веб-управлением
- `layer/base-image/raspios/example-config.yaml` - Подробные примеры

---

**Создано:** 2 октября 2025  
**Версия:** 1.0.0  
**Статус:** ✅ Production Ready  
**Категория:** base-image  
**Слой:** raspios-base

