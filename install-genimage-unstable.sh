#!/bin/bash
#
# Скрипт установки и закрепления genimage из Debian Unstable
# Устанавливает genimage только из репозитория unstable и закрепляет версию
#

set -eu

echo "=== Установка и закрепление genimage из Debian Unstable ==="

# Проверяем, запущен ли скрипт от root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен от root пользователя"
   exit 1
fi

# Определяем архитектуру системы
ARCH=$(dpkg --print-architecture)
echo "Архитектура системы: $ARCH"

# Добавляем репозиторий Debian Unstable, если его нет
UNSTABLE_SOURCES="/etc/apt/sources.list.d/debian-unstable.list"
if [[ ! -f "$UNSTABLE_SOURCES" ]]; then
    echo "Добавляем репозиторий Debian Unstable..."
    cat > "$UNSTABLE_SOURCES" << EOF
# Debian Unstable repository for genimage
deb http://deb.debian.org/debian unstable main
deb-src http://deb.debian.org/debian unstable main
EOF
    echo "Репозиторий Debian Unstable добавлен в $UNSTABLE_SOURCES"
else
    echo "Репозиторий Debian Unstable уже добавлен"
fi

# Обновляем список пакетов
echo "Обновляем список пакетов..."
apt update

# Создаем файл pinning для genimage из unstable
PIN_FILE="/etc/apt/preferences.d/genimage-unstable-pin"
echo "Создаем pinning для genimage из unstable..."

cat > "$PIN_FILE" << EOF
# Pin genimage to Debian Unstable
Package: genimage
Pin: release a=unstable
Pin-Priority: 900

# Pin dependencies that might be needed for genimage
Package: *
Pin: release a=unstable
Pin-Priority: -1
EOF

echo "Pinning создан в $PIN_FILE"
echo "genimage будет установлен только из Debian Unstable"

# Устанавливаем genimage
echo "Устанавливаем genimage из Debian Unstable..."
apt install -y genimage

# Проверяем установленную версию
echo "Проверяем установленную версию genimage..."
VERSION=$(dpkg -l genimage | grep -E "^ii" | awk '{print $3}')
SOURCE=$(apt-cache policy genimage | grep -A 5 " 900 " | grep -o "unstable.*" | head -1)

echo "Установлена версия: $VERSION"
echo "Источник: $SOURCE"

# Показываем текущие настройки pinning
echo "Текущие настройки pinning:"
apt-cache policy genimage

echo "=== Установка завершена ==="
echo "genimage установлен и закреплен из Debian Unstable"
echo "Для обновления только genimage из unstable используйте: apt install genimage"
echo "Для полной проверки: apt-cache policy genimage"
