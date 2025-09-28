#!/bin/bash
# Демонстрация генерации образов в rpi-image-gen

set -e

echo "=== Демонстрация генерации образов rpi-image-gen ==="
echo

# Создать минимальную конфигурацию
echo "1. Создание тестовой конфигурации..."
cat > demo-config.yaml << 'EOF'
device:
  layer: rpi5
  hostname: demo-image
  user1: pi

image:
  layer: image-rpios
  name: demo-image
  rootfs_type: ext4

layer:
  base: bookworm-minbase
EOF

echo "✓ Конфигурация создана"
echo

# Проверить слои
echo "2. Проверка зависимостей слоев..."
if ./rpi-image-gen layer --check image-rpios >/dev/null 2>&1; then
    echo "✓ Слои проверены успешно"
else
    echo "✗ Ошибка в зависимостях слоев"
    exit 1
fi
echo

# Показать структуру образов
echo "3. Структура генерируемых образов:"
echo "   work/image-demo-image/"
echo "   ├── demo-image.img         # Основной образ для прошивки"
echo "   ├── demo-image.img.sparse  # Sparse версия"
echo "   ├── boot.vfat.sparse       # Boot раздел"
echo "   └── root.ext4.sparse       # Root раздел"
echo

# Показать процесс сборки
echo "4. Процесс сборки:"
echo "   Этап 1 - Filesystem: ./rpi-image-gen build -c demo-config.yaml -f"
echo "   Этап 2 - Images:     ./rpi-image-gen build -c demo-config.yaml -i"
echo "   Этап 3 - Deploy:     ./rpi-image-gen build -c demo-config.yaml"
echo

# Показать RAID overlay
echo "5. RAID overlay (raid/) генерирует множественные образы:"
echo "   work/image-raid-test/"
echo "   ├── sdcard.img             # SD card с boot"
echo "   ├── external1.img          # External диск 1"
echo "   ├── external2.img          # External диск 2"
echo "   └── raid_config.sh         # RAID setup скрипт"
echo

# Показать команды для использования
echo "6. Использование готовых образов:"
echo "   # Для базового образа:"
echo "   dd if=work/image-demo-image/demo-image.img of=/dev/sdX bs=4M"
echo
echo "   # Для RAID overlay:"
echo "   dd if=work/image-raid-test/sdcard.img of=/dev/mmcblk0 bs=4M"
echo "   dd if=work/image-raid-test/external1.img of=/dev/sda bs=4M"
echo "   dd if=work/image-raid-test/external2.img of=/dev/sdb bs=4M"
echo

echo "=== Демонстрация завершена ==="
echo
echo "Для реальной генерации образов выполните:"
echo "1. ./rpi-image-gen build -c demo-config.yaml -f  # Создать filesystem"
echo "2. ./rpi-image-gen build -c demo-config.yaml -i  # Создать образы"
echo "3. find work -name '*.img'                       # Найти готовые образы"
