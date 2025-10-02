# SHA256 Verification для Base Images

**Дата:** 2 октября 2025  
**Цель:** Обеспечение целостности и безопасности загружаемых образов

---

## 🎯 Зачем нужна проверка SHA256?

SHA256 checksum проверка критически важна для безопасности:

1. **Целостность** - Гарантия что файл не был повреждён при загрузке
2. **Аутентичность** - Подтверждение что файл не был подменён
3. **Безопасность** - Защита от Man-in-the-Middle атак
4. **Compliance** - Требование многих security стандартов

---

## 🔧 Способы указания SHA256

### Метод 1: Прямое указание checksum

Укажите SHA256 напрямую в конфигурации:

```yaml
image:
  base_image_url: https://example.com/image.img.xz
  base_image_sha256: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd"
```

**Преимущества:**
- Быстро - нет дополнительных загрузок
- Надёжно - checksum зашит в конфигурацию
- Offline - работает без интернета (после загрузки образа)

**Недостатки:**
- Нужно вручную получать checksum
- Нужно обновлять при изменении образа

---

### Метод 2: URL к файлу SHA256

Укажите URL к файлу с SHA256:

```yaml
image:
  base_image_url: https://example.com/image.img.xz
  base_image_sha256_url: https://example.com/image.img.xz.sha256
```

**Преимущества:**
- Автоматическая загрузка checksum
- Всегда актуальный checksum
- Поддержка разных форматов файлов

**Недостатки:**
- Требует дополнительную загрузку
- Зависит от доступности URL

---

## 📋 Поддерживаемые форматы SHA256 файлов

Скрипт автоматически определяет формат и извлекает checksum:

### Формат 1: Только checksum
```
a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd
```

### Формат 2: Checksum + filename (стандарт sha256sum)
```
a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd  image.img.xz
```

### Формат 3: Несколько файлов
```
a1b2c3d4e5f678...  file1.img.xz
b2c3d4e5f67890...  file2.img.xz
c3d4e5f6789012...  file3.img.xz
```
*(автоматически найдёт нужный по имени файла)*

### Формат 4: Filename: checksum
```
image.img.xz: a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd
```

### Формат 5: Filename = checksum
```
image.img.xz = a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd
```

---

## 🚀 Примеры использования

### Raspberry Pi OS Trixie с SHA256

```yaml
device:
  layer: rpi5

image:
  layer: mdraid1-external-root
  name: secure-trixie
  
  # Официальный образ
  base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
  
  # Автоматическая проверка SHA256
  base_image_sha256_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256
  
  # RAID configuration
  mdraid1_external_root_rootfs_type: f2fs
  mdraid1_external_root_raid_level: RAID1
  mdraid1_external_root_raid_devices: 2
  mdraid1_external_root_encryption_enabled: y

layers:
  - security-suite
```

---

### С прямым указанием SHA256

```yaml
device:
  layer: rpi5

image:
  layer: mdraid1-external-root
  name: verified-trixie
  
  base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
  
  # Прямой checksum (получен заранее)
  base_image_sha256: "abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234"
  
  mdraid1_external_root_rootfs_type: ext4
  mdraid1_external_root_raid_level: RAID1
  mdraid1_external_root_raid_devices: 2

layers:
  - security-suite
```

---

### Enterprise с обязательной проверкой

```yaml
device:
  layer: rpi-cm5
  variant: 8G

image:
  layer: mdraid1-external-root
  name: enterprise-verified
  
  base_image_url: https://internal-mirror.company.com/raspios-trixie.img.xz
  
  # Обязательная SHA256 проверка для compliance
  base_image_sha256: "1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890"
  
  mdraid1_external_root_rootfs_type: f2fs
  mdraid1_external_root_encryption_enabled: y
  mdraid1_external_root_key_method: tpm

layers:
  - security-suite
  - cockpit

compliance:
  generate_sbom: y
  verify_checksums: y  # Строгая проверка всех checksums
  cis_benchmark: y
```

---

## 🔍 Как получить SHA256 checksum

### Способ 1: Официальный сайт

```bash
# Скачайте файл SHA256 с официального сайта
wget https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

# Посмотрите содержимое
cat 2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256
```

### Способ 2: Вычислить локально

```bash
# Скачайте образ
wget https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz

# Вычислите SHA256
sha256sum 2025-10-01-raspios-trixie-arm64-lite.img.xz

# Результат:
# a1b2c3d4e5f6... 2025-10-01-raspios-trixie-arm64-lite.img.xz
```

### Способ 3: Проверить существующий файл

```bash
# Если уже есть файл SHA256
sha256sum -c 2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

# Результат:
# 2025-10-01-raspios-trixie-arm64-lite.img.xz: OK
```

---

## 🛡️ Процесс верификации

Скрипт `apply-layers-to-base-image.sh` выполняет следующие шаги:

### 1. Загрузка SHA256 (если указан URL)

```
[INFO] SHA256 URL provided: https://...sha256
[INFO] Downloading SHA256 checksum...
[INFO] SHA256 file downloaded: cache/image.img.xz.sha256
```

### 2. Загрузка образа

```
[INFO] Downloading base image...
[INFO] URL: https://...img.xz
[INFO] Download completed: cache/image.img.xz
```

### 3. Извлечение образа

```
[INFO] Extracting image...
[INFO] Extraction completed: cache/image.img
```

### 4. Проверка SHA256

```
[INFO] Verifying image integrity...
[INFO] Image size: 2500 MB
[INFO] Verifying SHA256 checksum...
[INFO] Expected: a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd
[INFO] Actual:   a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd
[INFO] ✓ SHA256 checksum verified: OK
```

### 5. В случае ошибки

```
[ERROR] SHA256 checksum mismatch!
[ERROR]   Expected: a1b2c3d4e5f6...
[ERROR]   Actual:   b2c3d4e5f678...
[ERROR]
[ERROR] This could indicate:
[ERROR]   - Download was corrupted
[ERROR]   - File was modified
[ERROR]   - Wrong checksum provided
```

---

## 📊 Environment Variables

Можно задать через переменные окружения:

```bash
# Метод 1: Прямой checksum
export BASE_IMAGE_SHA256="a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd"
./scripts/apply-layers-to-base-image.sh config.yaml

# Метод 2: URL к SHA256
export BASE_IMAGE_SHA256_URL="https://example.com/image.img.xz.sha256"
./scripts/apply-layers-to-base-image.sh config.yaml

# Метод 3: Оба (приоритет у прямого checksum)
export BASE_IMAGE_SHA256="a1b2c3d4e5f6..."
export BASE_IMAGE_SHA256_URL="https://example.com/image.sha256"
./scripts/apply-layers-to-base-image.sh config.yaml
```

---

## ⚠️ Важные замечания

### Безопасность

1. **Всегда проверяйте SHA256** для production систем
2. **Используйте HTTPS** для загрузки SHA256 файлов
3. **Храните checksums в безопасном месте** (version control, password manager)
4. **Не отключайте проверку** в production

### Performance

1. **Кеширование** - SHA256 файлы кешируются в `cache/`
2. **Пропуск повторных проверок** - уже проверенные образы не проверяются снова
3. **Параллельная загрузка** - SHA256 загружается параллельно с образом

### Troubleshooting

**Проблема: SHA256 mismatch**
```bash
# Решение 1: Перезагрузите образ
rm cache/image.img.xz
./scripts/apply-layers-to-base-image.sh config.yaml

# Решение 2: Проверьте SHA256 вручную
sha256sum cache/image.img.xz
cat cache/image.img.xz.sha256

# Решение 3: Получите актуальный SHA256
wget https://official-site.com/image.img.xz.sha256 -O - | cat
```

**Проблема: SHA256 URL недоступен**
```bash
# Решение: Используйте прямой checksum
# В конфигурации:
base_image_sha256: "a1b2c3d4e5f6..."
# Удалите или закомментируйте:
# base_image_sha256_url: ...
```

---

## 📝 Best Practices

### 1. Для разработки

```yaml
# Можно пропустить проверку для быстрого тестирования
image:
  base_image_url: https://example.com/test-image.img.xz
  # Без SHA256 - появится warning, но продолжит работу
```

### 2. Для staging

```yaml
# Рекомендуется использовать SHA256 URL
image:
  base_image_url: https://example.com/staging-image.img.xz
  base_image_sha256_url: https://example.com/staging-image.img.xz.sha256
```

### 3. Для production

```yaml
# ОБЯЗАТЕЛЬНО используйте прямой SHA256
image:
  base_image_url: https://example.com/production-image.img.xz
  base_image_sha256: "verified_checksum_from_secure_source"
  # Храните checksum в version control вместе с конфигурацией
```

### 4. Для enterprise/compliance

```yaml
# Используйте оба метода для максимальной безопасности
image:
  base_image_url: https://internal-mirror.company.com/image.img.xz
  base_image_sha256: "primary_checksum_from_audit_trail"
  base_image_sha256_url: https://internal-mirror.company.com/checksums/image.sha256
  # Скрипт проверит оба и сравнит их между собой
```

---

## ✅ Checklist

Перед использованием в production:

- [ ] SHA256 checksum указан в конфигурации
- [ ] Checksum получен из надёжного источника
- [ ] Checksum сохранён в version control
- [ ] HTTPS используется для загрузки образа
- [ ] HTTPS используется для загрузки SHA256
- [ ] Протестирована успешная проверка
- [ ] Протестирована реакция на неправильный checksum
- [ ] Документирован источник checksum
- [ ] Настроен мониторинг ошибок верификации

---

## 📚 Дополнительные ресурсы

### Документация:
- `docs/TRIXIE_BASE_IMAGE.md` - Использование Trixie образов
- `README.adoc` - Общая документация
- `scripts/apply-layers-to-base-image.sh` - Исходный код

### Инструменты:
- `sha256sum` - Вычисление и проверка SHA256
- `openssl dgst -sha256` - Альтернативный метод
- `rhash --sha256` - Ещё один инструмент

### Стандарты:
- FIPS 180-4 - SHA-2 specification
- NIST - Guidelines for cryptographic hashing
- CIS Benchmarks - Security verification requirements

---

**Обновлено:** 2 октября 2025  
**Версия:** 1.0.0

