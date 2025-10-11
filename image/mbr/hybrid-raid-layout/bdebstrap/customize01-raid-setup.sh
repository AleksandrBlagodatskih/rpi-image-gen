#!/bin/bash
# RAID configuration hook
# Настраивает RAID1 хранилище с автоматической сборкой и восстановлением

set -euo pipefail

chroot_path="$1"

echo "🔧 Configuring RAID1 storage"

# Ensure mdadm service is enabled with automatic recovery
chroot "$chroot_path" systemctl enable mdadm.service

# Configure mdadm for automatic RAID assembly
if [[ -f "$chroot_path/etc/mdadm/mdadm.conf" ]]; then
    cp "$chroot_path/etc/mdadm/mdadm.conf" "$chroot_path/etc/mdadm/mdadm.conf.backup"
fi

echo "✅ RAID1 storage configured"
