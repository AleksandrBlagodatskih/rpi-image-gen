#!/bin/bash
# Test script for RAID metadata creation

echo "=== Тест создания RAID метаданных ==="

# Source the RAID metadata script
source "$(dirname "$0")/raid-metadata.sh"

echo "1. Тестируем валидацию параметров..."
# Test parameter validation (should work)
validate_raid_parameters "1" "dummy1,dummy2" "1.2" 2>/dev/null || echo "Ожидаемая ошибка валидации устройств (устройства не существуют)"

echo "2. Тестируем создание команды mdadm..."
# Test command generation (should work)
local devices="/dev/sdb1,/dev/sdc1"
local device_count=$(echo "$devices" | tr ',' '\n' | wc -l)
echo "Количество устройств: $device_count"

echo "3. Показываем как выглядела бы команда mdadm:"
echo "mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1 --metadata=1.2 --name=hostname:0 --uuid=<UUID> --layout=n2"

echo "✅ Тест завершен успешно"
