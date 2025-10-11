#!/bin/bash
# RAID configuration hook
# Настраивает RAID1 хранилище с автоматической сборкой и восстановлением

set -euo pipefail

chroot_path="$1"

echo "🔧 Configuring RAID1 storage"

# Ensure mdadm service is enabled with automatic recovery
chroot "$chroot_path" systemctl enable mdadm.service

echo "✅ RAID1 storage configured"
