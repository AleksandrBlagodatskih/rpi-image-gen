# Изменения в RAID функциональности

## Обзор изменений

Функциональность слоя `mdadm` была перенесена в overlay слой `raid/` для консолидации RAID поддержки в одном месте.

## Перенесенная функциональность

### Из `layer/sys-apps/software-raid/mdadm.yaml`:

1. **Установка пакета mdadm**
   - Добавлена проверка и установка пакета mdadm в `customize07-raid-overlay`

2. **Initramfs RAID поддержка**
   - Включение модулей ядра: `md_mod`, `raid0`, `raid1`, `raid10`, `raid456`
   - Перегенерация initramfs с RAID поддержкой

3. **Базовая конфигурация mdadm**
   - Создание `/etc/mdadm/mdadm.conf` с настройками сканирования
   - Настройка HOMEHOST и MAILADDR

4. **Системные сервисы**
   - Включение `mdmonitor`, `mdcheck`, `mdadm-waitidle`

## Удаленный слой

**Удален:** `layer/sys-apps/software-raid/mdadm/`

Причина: Функциональность консолидирована в `raid/` overlay для:
- Упрощения архитектуры
- Избежания дублирования
- Специфичной настройки для RAID образов

## Новый workflow

```yaml
# Ранее (с отдельными слоями):
layer:
  base: bookworm-minbase
  sys-apps: mdadm        # Отдельный слой для mdadm
  image: image-rpios     # Обычный образ

# Теперь (с RAID overlay):
layer:
  base: bookworm-minbase
  image: raid            # RAID overlay включает всю функциональность
```

## Преимущества

1. **Консолидация**: Вся RAID функциональность в одном overlay слое
2. **Специфичность**: Настройки оптимизированы для multi-image RAID сценариев
3. **Простота**: Меньше слоев для управления
4. **Гибкость**: RAID overlay можно использовать только когда нужно

## Проверка работоспособности

```bash
# Проверить слой
./rpi-image-gen layer --describe raid

# Протестировать конфигурацию
./rpi-image-gen build -c raid-config.yaml -f
```

## Документация

- Все RAID инструменты: `raid-status`, `raid-recovery`
- Автоматическая настройка initramfs для RAID загрузки
- Поддержка RAID0 и RAID1
- Multi-device image generation
