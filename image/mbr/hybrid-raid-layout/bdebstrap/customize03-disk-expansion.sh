#!/bin/bash
# Disk expansion service setup hook
# Включает сервис автоматического расширения дисков при первой загрузке

set -euo pipefail

chroot_path="$1"

echo "📈 Setting up disk expansion service"

# Enable disk expansion service
chroot "$chroot_path" systemctl enable disk-expansion.service

echo "✅ Disk expansion service enabled"
