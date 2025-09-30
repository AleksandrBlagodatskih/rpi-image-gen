# Radxa SATA Penta HAT Layer

Этот слой добавляет поддержку Radxa SATA Penta HAT для Raspberry Pi 5 с автоматической настройкой PCIe Gen 3.0 и initramfs SATA инициализацией.

## Описание

Radxa SATA Penta HAT - это высокопроизводительное SATA расширение для Raspberry Pi 5, предоставляющее 5 SATA портов через PCIe контроллер JMB585 Gen 3.0 x2.

## Функции

- ✅ Автоматическая настройка PCIe Gen 3.0 для максимальной производительности
- ✅ Initramfs hooks для ранней загрузки SATA драйверов
- ✅ Поддержка загрузки с SATA дисков
- ✅ GPIO и PCIe модули для управления питанием
- ✅ Полная интеграция с rpi-image-gen

## Требования

- Raspberry Pi 5
- Radxa SATA Penta HAT
- 12V питание (Molex или barrel jack)
- SATA диски (HDD/SSD)
- rpi-image-gen с rpi5 и rpi-linux-v8 слоями

## Быстрый старт

1. **Создайте конфигурацию:**

```yaml
device:
  layer: rpi5
  hostname: sata-server

layer:
  device: radxa-sata-penta-hat

radxa_sata:
  pcie_gen3: y
  initramfs_sata: y
```

2. **Соберите образ:**

```bash
rpi-image-gen build -c config.yaml
```

3. **Прошейте образ на SD-карту**

4. **Подключите оборудование:**
   - FFC кабель к Pi 5 (J6)
   - SATA диски к HAT
   - 12V питание

## Переменные конфигурации

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `radxa_sata_pcie_gen3` | `y` | Включить PCIe Gen 3.0 (`dtparam=pciex1_gen=3`) с поддержкой RP1 |
| `radxa_sata_initramfs_sata` | `y` | Включить initramfs SATA hooks с RP1 модулями |
| `radxa_sata_load_rp1_modules` | `y` | Загружать модули RP1 чипа ввода-вывода |
| `radxa_sata_enable_gpio_power` | `n` | Включить GPIO управление питанием (экспериментально) |

## Аппаратная настройка

### Подключение

1. Подключите FFC кабель между Pi 5 (разъем J6) и HAT
2. Подключите SATA диски к портам HAT (4x SATA + 1x edge)
3. Подключите 12V питание через Molex или barrel jack
4. Вставьте SD-карту с образом
5. Включите питание

### Питание

HAT требует внешнего 12V питания для:
- SATA дисков (особенно при подключении нескольких HDD)
- Опционального питания Raspberry Pi 5 через GPIO
- Стабильной работы высокопроизводительных SSD

## Тестирование

### Проверка обнаружения дисков

```bash
# Проверить SATA диски
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Детальная информация о PCIe
lspci -vvv | grep -A 10 JMB585

# Логи SATA
dmesg | grep -i sata
```

### Производительность

```bash
# Тест скорости чтения/записи
hdparm -tT /dev/sda

# S.M.A.R.T. информация
smartctl -a /dev/sda
```

## Устранение неисправностей

### Диски не обнаруживаются

1. Проверьте 12V питание HAT
2. Проверьте FFC кабель
3. Убедитесь в PCIe Gen 3.0 настройке
4. Проверьте логи: `dmesg | grep -i ahci`

### Низкая производительность

1. Включите PCIe Gen 3.0
2. Проверьте качество SATA кабелей
3. Рассмотрите активное охлаждение
4. Используйте SSD вместо HDD

### Initramfs проблемы

1. Перегенерируйте initramfs: `update-initramfs -u -k all`
2. Проверьте наличие initrd файлов: `ls -la /boot/firmware/initrd*`
3. Проверьте логи загрузки

## Совместимость

- **Аппаратура**: Только Raspberry Pi 5
- **Ядро**: rpi-linux-v8 (64-bit)
- **Дистрибутивы**: Debian Bookworm и производные
- **Файловые системы**: ext4, btrfs, zfs

## Файлы

- `radxa-sata-penta-hat.yaml` - Основной слой
- `radxa-sata-penta-hat.adoc` - Документация
- `example-config.yaml` - Пример конфигурации
- `README.md` - Это руководство

## Ссылки

- [Radxa SATA Penta HAT Discussion](https://github.com/geerlingguy/raspberry-pi-pcie-devices/issues/615)
- [Raspberry Pi 5 Documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
- [Linux Kernel Documentation](https://www.raspberrypi.com/documentation/computers/linux_kernel.html)
- [Raspberry Pi Firmware](https://github.com/raspberrypi/firmware)
