# Radxa SATA Penta HAT Example

Этот пример демонстрирует создание полнофункционального NAS/storage сервера с использованием Radxa SATA Penta HAT на Raspberry Pi 5.

## Что включает конфигурация

- **Radxa SATA Penta HAT** с PCIe Gen 3.0 и initramfs SATA поддержкой
- **NAS сервисы**: Samba, NFS для сетевого доступа
- **Мониторинг**: Prometheus, Node Exporter, SMART monitoring
- **Безопасность**: Шифрование, secure boot, hardening
- **Хранение**: ZFS, mergerfs, SnapRAID для защиты данных
- **Инструменты**: SMART monitoring, hdparm, iotop, ncdu

## Быстрый старт

```bash
# Собрать образ
rpi-image-gen build -c examples/radxa-sata-penta-hat/config.yaml

# Прошить на SD-карту (используйте полученный .img файл)
# Подключить оборудование согласно инструкциям в документации HAT

# Первый запуск - сменить пароль по умолчанию!
ssh nasadmin@radxa-sata-nas.local
passwd  # Сменить пароль
```

## После первого запуска

### Настройка дисков

```bash
# Проверить диски
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,VENDOR,MODEL

# Создать ZFS pool (пример)
zpool create tank raidz2 /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde

# Создать filesystem
zfs create tank/data
zfs set compression=lz4 tank/data
zfs set atime=off tank/data
```

### Настройка Samba

```bash
# Создать шару
mkdir /tank/data/share
chmod 777 /tank/data/share

# Настроить Samba в /etc/samba/smb.conf
[share]
   path = /tank/data/share
   browseable = yes
   writable = yes
   guest ok = no
   valid users = nasadmin

# Добавить пользователя Samba
smbpasswd -a nasadmin

# Перезапустить Samba
systemctl restart smbd nmbd
```

### Настройка NFS

```bash
# Экспортировать filesystem
echo "/tank/data/share *(rw,sync,no_subtree_check)" >> /etc/exports

# Перезапустить NFS
systemctl restart nfs-kernel-server
```

## Мониторинг

### Доступ к Prometheus

```
http://radxa-sata-nas.local:9090
```

### SMART monitoring

```bash
# Проверить все диски
smartctl --scan | xargs -n 1 smartctl -a

# Настроить автоматический мониторинг
cp /usr/share/doc/smartmontools/examples/smartd.conf /etc/smartd.conf
systemctl restart smartmontools
```

## Производительность

### Тестирование скорости

```bash
# ZFS benchmark
zfs create -V 10G tank/test
fio --name=randread --rw=randread --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting --directory=/tank/test

# Очистить тест
zfs destroy tank/test
```

### Оптимизация

```bash
# ZFS tuning
zfs set recordsize=1M tank/data  # Для больших файлов
zfs set compression=zstd tank/data  # Лучшее сжатие

# Network tuning для Gigabit Ethernet
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
sysctl -p
```

## Безопасность

### Firewall (опционально)

```bash
# Установить ufw
apt install ufw

# Настроить правила
ufw allow ssh
ufw allow samba
ufw allow 9090  # Prometheus
ufw --force enable
```

### Шифрование (опционально)

```bash
# Создать encrypted dataset
zfs create -o encryption=aes-256-gcm -o keylocation=prompt -o keyformat=passphrase tank/encrypted
```

## Резервное копирование

```bash
# Rsync backup script
cat > /usr/local/bin/backup.sh << 'EOF'
#!/bin/bash
rsync -av --delete /tank/data/ /mnt/backup/
EOF

chmod +x /usr/local/bin/backup.sh

# Добавить в cron
echo "0 2 * * * /usr/local/bin/backup.sh" | crontab -
```

## Устранение неисправностей

### Диски не монтируются

```bash
# Проверить ZFS
zpool status
zpool import

# Проверить dmesg
dmesg | grep -i zfs
```

### Сеть недоступна

```bash
# Проверить network
ip addr show
systemctl status systemd-networkd

# Проверить hostname
hostnamectl
```

### Высокая нагрузка

```bash
# Проверить процессы
top
iotop

# Проверить ZFS
zpool iostat 1
```

## Апгрейд

```bash
# Обновить систему
apt update && apt upgrade

# Обновить ZFS (если используется)
apt install --only-upgrade zfsutils-linux

# Перезагрузить
reboot
```

## Ссылки

- [Radxa SATA Penta HAT](https://github.com/geerlingguy/raspberry-pi-pcie-devices/issues/615)
- [ZFS on Linux](https://openzfs.github.io/openzfs-docs/)
- [Samba Documentation](https://www.samba.org/samba/docs/)
- [Raspberry Pi 5](https://www.raspberrypi.com/products/raspberry-pi-5/)
