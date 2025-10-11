#!/bin/bash
set -euo pipefail

# Function for error handling
die() {
    echo "ERROR: $*" >&2
    exit 1
}

echo "🔧 Configuring hybrid-raid-layout overlay templates..."

# Use hybrid_raid_layout ssd_ids variable (should be set by rpi-image-gen)
SSD_IDS="${IGconf_hybrid_raid_luks_ssd_ids:?ssd_ids not configured}"
echo "DEBUG: Using SSD_IDS=${SSD_IDS}"

# Create output directories
mkdir -p device/initramfs-tools/hooks
mkdir -p device/initramfs-tools/scripts/local-top
mkdir -p device/rootfs-overlay/etc/profile.d
mkdir -p device/rootfs-overlay/etc/systemd/system/disk-expansion.service.d
mkdir -p device/rootfs-overlay/usr/local/bin

# Process initramfs-tools templates
echo "Processing initramfs-tools templates..."
if [ -f "templates/initramfs-tools/hooks/hybrid-raid.in" ]; then
    sed "s|__SSD_IDS__|$SSD_IDS|g" templates/initramfs-tools/hooks/hybrid-raid.in > device/initramfs-tools/hooks/hybrid-raid
    chmod +x device/initramfs-tools/hooks/hybrid-raid
fi

if [ -f "templates/initramfs-tools/scripts/local-top/rpi-luks.in" ]; then
    sed "s|__SSD_IDS__|$SSD_IDS|g" templates/initramfs-tools/scripts/local-top/rpi-luks.in > device/initramfs-tools/scripts/local-top/rpi-luks
    chmod +x device/initramfs-tools/scripts/local-top/rpi-luks
fi

if [ -f "templates/initramfs-tools/modules.in" ]; then
    sed "s|__SSD_IDS__|$SSD_IDS|g" templates/initramfs-tools/modules.in > device/initramfs-tools/modules
fi

# Process rootfs-overlay templates
echo "Processing rootfs-overlay templates..."
if [ -f "templates/rootfs-overlay/etc/profile.d/hybrid-raid-status.sh.in" ]; then
    sed "s|__SSD_IDS__|$SSD_IDS|g" templates/rootfs-overlay/etc/profile.d/hybrid-raid-status.sh.in > device/rootfs-overlay/etc/profile.d/hybrid-raid-status.sh
    chmod +x device/rootfs-overlay/etc/profile.d/hybrid-raid-status.sh
fi

if [ -f "templates/rootfs-overlay/etc/systemd/system/disk-expansion.service.d/override.conf.in" ]; then
    sed "s|__SSD_IDS__|$SSD_IDS|g" templates/rootfs-overlay/etc/systemd/system/disk-expansion.service.d/override.conf.in > device/rootfs-overlay/etc/systemd/system/disk-expansion.service.d/override.conf
fi

if [ -f "templates/rootfs-overlay/usr/local/bin/disk-expansion.in" ]; then
    sed "s|__SSD_IDS__|$SSD_IDS|g" templates/rootfs-overlay/usr/local/bin/disk-expansion.in > device/rootfs-overlay/usr/local/bin/disk-expansion
    chmod +x device/rootfs-overlay/usr/local/bin/disk-expansion
fi

echo "✅ Overlay templates configured with SSD IDs: ${SSD_IDS}"
