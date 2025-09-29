# Установка и закрепление genimage из Debian Unstable

Этот репозиторий содержит скрипты для установки и закрепления (pinning) genimage только из репозитория Debian Unstable.

## Что делает скрипт

- ✅ Добавляет репозиторий Debian Unstable (если его нет)
- ✅ Создает APT pinning для genimage с приоритетом 900 из unstable
- ✅ Устанавливает genimage только из unstable репозитория
- ✅ Запрещает установку других пакетов из unstable (приоритет -1)
- ✅ Показывает подробную информацию о процессе

## Выбор скрипта

### `install-genimage-unstable.sh` (для root пользователей)
```bash
# Запустите от пользователя root
sudo -i
./install-genimage-unstable.sh
```

### `install-genimage-unstable-sudo.sh` (для пользователей с sudo)
```bash
# Запустите от обычного пользователя с доступом к sudo
./install-genimage-unstable-sudo.sh
```

## Как работает pinning

Создается файл `/etc/apt/preferences.d/genimage-unstable-pin`:

```apt
# Pin genimage to Debian Unstable
Package: genimage
Pin: release a=unstable
Pin-Priority: 900

# Pin dependencies that might be needed for genimage
Package: *
Pin: release a=unstable
Pin-Priority: -1
```

Это означает:
- genimage всегда устанавливается из unstable (приоритет 900)
- Все остальные пакеты из unstable запрещены (приоритет -1)

## Проверка установки

После установки проверьте:

```bash
# Проверка версии и источника
apt-cache policy genimage

# Должно показать что genimage установлен из unstable
genimage:
  Installed: 18-1
  Candidate: 18-1
  Version table:
 *** 18-1 900
        500 http://deb.debian.org/debian unstable/main amd64 Packages
        100 /var/lib/dpkg/status
```

## Обновление genimage

Для обновления только genimage из unstable:

```bash
# Для root пользователей
apt install genimage

# Для пользователей с sudo
sudo apt install genimage
```

## Удаление pinning

Если нужно вернуться к стандартным репозиториям:

```bash
# Удалить файл pinning
sudo rm /etc/apt/preferences.d/genimage-unstable-pin

# Удалить репозиторий unstable (если не используется для других целей)
sudo rm /etc/apt/sources.list.d/debian-unstable.list

# Обновить кэш пакетов
sudo apt update
```

## Возможные проблемы

### "Package genimage not found"
- Убедитесь что репозиторий unstable добавлен корректно
- Проверьте что сеть доступна для deb.debian.org

### "Permission denied"
- Убедитесь что скрипт запущен от root или через sudo
- Проверьте права доступа к /etc/apt/

### Конфликты с другими pinning файлами
- Если есть другие файлы в /etc/apt/preferences.d/, они могут влиять на выбор пакетов
- Проверьте все файлы в этой директории

## Поддерживаемые архитектуры

Скрипты работают на всех архитектурах, поддерживаемых Debian:
- amd64, i386, arm64, armhf, armel
- И другие архитектуры, для которых доступен genimage в unstable
