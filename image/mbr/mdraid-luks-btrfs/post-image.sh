#!/bin/bash

# Post-image hook for MD RAID1 + LUKS2 + Btrfs setup
# This script runs after genimage creates the SD card image
# It prepares the system for provisioning on real hardware

set -eu

echo "Setting up MD RAID1 + LUKS2 + Btrfs post-image configuration..."

# MD RAID1 is created in genimage, LUKS is applied during provisioning
# We just need to ensure initramfs has required modules for decryption

# Note: mdadm layer already handles RAID detection and initramfs regeneration

# Note: All initramfs modules are configured by dedicated layers:
# - cryptsetup layer handles dm_crypt/dm_mod
# - mdadm layer handles md_mod/raid1/etc
# - btrfs layer handles btrfs module

echo "Post-image setup complete for MD RAID1 + LUKS2 + Btrfs"
