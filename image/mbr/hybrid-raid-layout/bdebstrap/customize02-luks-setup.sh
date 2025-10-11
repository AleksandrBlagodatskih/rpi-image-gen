#!/bin/bash
# LUKS configuration hook
# Настраивает LUKS2 шифрование с необходимыми сервисами и директориями

set -euo pipefail

chroot_path="$1"

echo "🔐 Configuring LUKS2 encryption"

# Ensure cryptsetup target is enabled
chroot "$chroot_path" systemctl enable cryptsetup.target

# Create LUKS key directory if it doesn't exist
mkdir -p "$chroot_path/etc/luks"
chmod 700 "$chroot_path/etc/luks"

echo "✅ LUKS2 encryption configured"
