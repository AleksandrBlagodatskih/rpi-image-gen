# ✅ Исправление структуры RAID слоёв

**Дата:** 2 октября 2025  
**Задача:** Корректное размещение raid-external и mdraid1-external-root в структуре проекта

---

## 🎯 Проблема

В проекте обнаружено **дублирование и несоответствие** RAID слоёв:

### Найденные проблемы:
1. **Две директории с одним слоем:**
   - `image/mbr/raid-external/` (только image.yaml)
   - `image/mbr/mdraid1-external-root/` (полная реализация)

2. **Несоответствие префиксов переменных:**
   - `raid-external/image.yaml` использовал `raid1_external`
   - `mdraid1-external-root/image.yaml` использовал `mdraid1_external_root`

3. **Несоответствие в конфигурациях:**
   - Тестовые файлы использовали `layer: raid-external`
   - Enterprise примеры использовали `layer: mdraid1-external-root`

4. **Неправильная ссылка в README.adoc:**
   - Указывал на `image/mbr/raid1-external/README.md`
   - Реальный путь: `image/mbr/mdraid1-external-root/README.md`

---

## ✅ Выполненные исправления

### 1. Удален дубликат
```bash
rm -rf image/mbr/raid-external/
```

**Результат:** Осталась только одна директория `image/mbr/mdraid1-external-root/`

---

### 2. Обновлён README.adoc
```diff
- link:./image/mbr/raid1-external/README.md
+ link:./image/mbr/mdraid1-external-root/README.md
```

---

### 3. Обновлены тестовые файлы (2 файла)

#### test-raid-simple.yaml
```diff
image:
-  layer: raid-external
+  layer: mdraid1-external-root
-  raid_external_raid_level: RAID1
+  mdraid1_external_root_raid_level: RAID1
-  raid_external_raid_devices: 2
+  mdraid1_external_root_raid_devices: 2
```

#### test-raid-enterprise.yaml
```diff
image:
-  layer: raid-external
+  layer: mdraid1-external-root
-  raid_external_raid_level: RAID1
+  mdraid1_external_root_raid_level: RAID1
-  raid_external_raid_devices: 2
+  mdraid1_external_root_raid_devices: 2
-  raid_external_sector_size: 4096
+  mdraid1_external_root_sector_size: 4096
-  raid_external_encryption_enabled: y
+  mdraid1_external_root_encryption_enabled: y
```

---

### 4. Обновлён README.md (1 файл)

Исправлены все примеры и таблицы переменных:

**Примеры конфигурации:**
```diff
- layer: raid-external
+ layer: mdraid1-external-root
```

**Таблицы переменных:**
```diff
- raid_external_rootfs_type
+ mdraid1_external_root_rootfs_type

- raid_external_raid_level
+ mdraid1_external_root_raid_level

... (все 14 переменных обновлены)
```

**Debug команды:**
```diff
- rpi-image-gen layer --validate image/mbr/raid-external/image.yaml
+ rpi-image-gen layer --validate image/mbr/mdraid1-external-root/image.yaml

- rpi-image-gen layer --check raid-external
+ rpi-image-gen layer --check mdraid1-external-root
```

---

### 5. Обновлены скрипты (5 файлов)

Все переменные окружения исправлены:

#### integrity-check.sh
```diff
- IGconf_raid_external_key_file
+ IGconf_mdraid1_external_root_key_file
```

#### key-management.sh
```diff
- IGconf_raid_external_key_method
+ IGconf_mdraid1_external_root_key_method
- IGconf_raid_external_key_size
+ IGconf_mdraid1_external_root_key_size
- IGconf_raid_external_key_file
+ IGconf_mdraid1_external_root_key_file
- IGconf_raid_external_key_env
+ IGconf_mdraid1_external_root_key_env
```

#### performance-optimization.sh
```diff
- IGconf_raid_external_apt_cache
+ IGconf_mdraid1_external_root_apt_cache
- IGconf_raid_external_ccache
+ IGconf_mdraid1_external_root_ccache
- IGconf_raid_external_ccache_size
+ IGconf_mdraid1_external_root_ccache_size
- IGconf_raid_external_parallel_jobs
+ IGconf_mdraid1_external_root_parallel_jobs
- IGconf_raid_external_image_size_optimization
+ IGconf_mdraid1_external_root_image_size_optimization
- IGconf_raid_external_compression
+ IGconf_mdraid1_external_root_compression
```

#### setup.sh
```diff
- IGconf_raid1_external_encryption_enabled
+ IGconf_mdraid1_external_root_encryption_enabled
- IGconf_raid1_external_rootfs_type
+ IGconf_mdraid1_external_root_rootfs_type
- IGconf_raid1_external_raid_level
+ IGconf_mdraid1_external_root_raid_level
- IGconf_raid1_external_assetdir
+ IGconf_mdraid1_external_root_assetdir
```

#### pre-image.sh
```diff
- IGconf_raid1_external_raid_devices
+ IGconf_mdraid1_external_root_raid_devices
- IGconf_raid1_external_raid_level
+ IGconf_mdraid1_external_root_raid_level
- IGconf_raid1_external_rootfs_type
+ IGconf_mdraid1_external_root_rootfs_type
- IGconf_raid1_external_boot_part_size
+ IGconf_mdraid1_external_root_boot_part_size
- IGconf_raid1_external_root_part_size
+ IGconf_mdraid1_external_root_root_part_size
- IGconf_raid1_external_sector_size
+ IGconf_mdraid1_external_root_sector_size
- IGconf_raid1_external_assetdir
+ IGconf_mdraid1_external_root_assetdir
- IGconf_raid1_external_pmap
+ IGconf_mdraid1_external_root_pmap
```

---

## 📊 Статистика изменений

| Категория | Количество | Детали |
|-----------|------------|--------|
| **Удалено директорий** | 1 | `image/mbr/raid-external/` |
| **Обновлено файлов** | 9 | README.adoc, README.md, 2 тестовых, 5 скриптов |
| **Заменено переменных** | 40+ | Все префиксы обновлены |
| **Обновлено примеров** | 5 | В README.md и тестовых файлах |

---

## 🎯 Итоговая структура

### ✅ Правильная структура:
```
image/mbr/mdraid1-external-root/
├── bdebstrap/
│   ├── customize05-pkgs
│   └── customize07-raid-external
├── device/
│   ├── provisionmap-clear.json
│   └── provisionmap-crypt.json
├── genimage.cfg.in.btrfs
├── genimage.cfg.in.ext4
├── image.yaml                     # X-Env-Layer-Name: mdraid1-external-root
├── integrity-check.sh             # ✅ Обновлён
├── key-management.sh              # ✅ Обновлён
├── mke2fs.conf
├── performance-optimization.sh    # ✅ Обновлён
├── pre-image.sh                   # ✅ Обновлён
├── README.md                      # ✅ Обновлён
├── setup.sh                       # ✅ Обновлён
├── test-raid-enterprise.yaml      # ✅ Обновлён
├── test-raid-metadata.sh
└── test-raid-simple.yaml          # ✅ Обновлён
```

### ❌ Удалено:
```
image/mbr/raid-external/           # Дубликат с неправильным префиксом
```

---

## 🔍 Проверка корректности

### Единообразие именования:
- ✅ **Имя слоя:** `mdraid1-external-root`
- ✅ **Префикс переменных:** `mdraid1_external_root`
- ✅ **Путь:** `image/mbr/mdraid1-external-root/`

### Обратная совместимость:
- ⚠️ **BREAKING CHANGE:** Префикс переменных изменён
- 📋 **Требуется миграция:** Все конфигурации должны использовать новый префикс

### Документация:
- ✅ README.adoc обновлён
- ✅ README.md обновлён
- ✅ Примеры обновлены

---

## 📝 Рекомендации

### Для пользователей:

1. **Обновите конфигурации:**
   ```yaml
   # Старый формат (НЕ работает):
   image:
     layer: raid-external
     raid_external_raid_level: RAID1
   
   # Новый формат (правильный):
   image:
     layer: mdraid1-external-root
     mdraid1_external_root_raid_level: RAID1
   ```

2. **Проверьте скрипты:**
   - Замените `$IGconf_raid_external_*` на `$IGconf_mdraid1_external_root_*`
   - Замените `$IGconf_raid1_external_*` на `$IGconf_mdraid1_external_root_*`

3. **Обновите документацию:**
   - Используйте путь `image/mbr/mdraid1-external-root/`
   - Ссылайтесь на `mdraid1-external-root` как имя слоя

---

## ✅ Результат

**Структура проекта приведена в соответствие с README.adoc:**
- ✅ Один слой RAID вместо двух дубликатов
- ✅ Единообразное именование во всех файлах
- ✅ Правильные пути и ссылки
- ✅ Корректные переменные окружения
- ✅ Обновлённая документация

**Готово к использованию!** 🎉

---

**Контакты:**
- **GitHub:** https://github.com/raspberrypi/rpi-image-gen
- **Issues:** https://github.com/raspberrypi/rpi-image-gen/issues

