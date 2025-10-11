#!/bin/bash
set -euo pipefail

# Function for error handling
die() {
    echo "ERROR: $*" >&2
    exit 1
}

fs="$1"
genimg_in="$2"

# Basic validation (rpi-image-gen framework handles most validation)
[[ -n "${IGconf_hybrid_raid_luks_ssd_devices:-}" ]] || die "ssd_devices not configured"

# Generate UUIDs for partitions (batch generation for performance)
uuids=$(uuidgen && uuidgen && uuidgen)
BOOT_UUID=$(echo "$uuids" | head -1)
ROOT_UUID=$(echo "$uuids" | head -2 | tail -1)
CRYPT_UUID=$(echo "$uuids" | tail -1)

# Validate UUID format
validate_uuid() {
    local uuid="$1" name="$2"
    [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || die "Invalid $name UUID format: $uuid"
}

validate_uuid "$BOOT_UUID" "BOOT"
validate_uuid "$ROOT_UUID" "ROOT"
validate_uuid "$CRYPT_UUID" "CRYPT"

# Generate LUKS key if encryption is enabled
if [[ "${IGconf_hybrid_raid_luks_encryption_enabled:-n}" == "y" ]]; then
    # Only file-based key storage is supported for security
    key_method="${IGconf_hybrid_raid_luks_key_method:-file}"
    [[ "$key_method" == "file" ]] || die "Only 'file' key method is supported for security reasons"

    # Generate secure LUKS key file for genimage encryption only
    # Note: LUKS key for system boot is handled by extension layer via overlay
    LUKS_KEY_FILE="${genimg_in}/luks-key"

    # Generate cryptographically secure key (64 bytes = 512 bits)
    if command -v openssl >/dev/null 2>&1; then
        openssl rand 64 > "$LUKS_KEY_FILE" 2>/dev/null || die "Failed to generate LUKS key with openssl"
    else
        dd if=/dev/urandom bs=64 count=1 2>/dev/null > "$LUKS_KEY_FILE" || die "Failed to generate LUKS key with dd"
    fi

    # Set secure permissions for genimage process
    chmod 600 "$LUKS_KEY_FILE" || die "Failed to set LUKS key permissions"

    echo "Generated secure LUKS key for image encryption" >&2
else
    LUKS_KEY_FILE="/dev/null"
fi

# Save essential UUIDs for other scripts
cat > "${genimg_in}/img_uuids" << EOF
BOOT_UUID=$BOOT_UUID
ROOT_UUID=$ROOT_UUID
CRYPT_UUID=$CRYPT_UUID
LUKS_KEY_FILE=$LUKS_KEY_FILE
EOF

# Generate genimage configuration
template_file="genimage.cfg.in"
if [[ ! -f "$template_file" ]]; then
    die "Template file $template_file not found"
fi

# Validate rootfs_type
rootfs_type="${IGconf_hybrid_raid_luks_rootfs_type:-ext4}"
case "$rootfs_type" in
    ext4|btrfs|f2fs) ;;
    *) die "Unsupported rootfs_type: $rootfs_type" ;;
esac

# Calculate sizes with overhead considerations
root_size="${IGconf_hybrid_raid_luks_root_part_size:-2G}"
boot_size="${IGconf_hybrid_raid_luks_boot_part_size:-200M}"

# LUKS2 container overhead calculation:
# - LUKS2 header: ~16MB (varies with key size and parameters)
# - Additional safety margin: ~4MB (--reduce-device-size)
# - Total overhead: ~20MB to ensure filesystem fits
case "$root_size" in
    *G) base_size=${root_size%G}; unit="G"; multiplier=1024 ;;
    *M) base_size=${root_size%M}; unit="M"; multiplier=1 ;;
    *) die "Unsupported size format: $root_size" ;;
esac

# Calculate LUKS container size with 2% overhead
luks_container_size_mb=$(( base_size * multiplier + 20 ))
luks_container_size="${luks_container_size_mb}M"

# RAID partition size (same as LUKS container for RAID1)
raid_partition_size="$luks_container_size"

sed \
    -e "s|<IMAGE_NAME>|\"$IGconf_image_name\"|g" \
    -e "s|<IMAGE_SUFFIX>|\"$IGconf_image_suffix\"|g" \
    -e "s|<BOOT_SIZE>|$boot_size|g" \
    -e "s|<ROOT_SIZE>|$root_size|g" \
    -e "s|<LUKS_CONTAINER_SIZE>|$luks_container_size|g" \
    -e "s|<RAID_PARTITION_SIZE>|$raid_partition_size|g" \
    -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
    -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
    -e "s|<CRYPT_UUID>|$CRYPT_UUID|g" \
    -e "s|<LUKS_KEY_FILE>|$LUKS_KEY_FILE|g" \
    -e "s|<SSD_DEVICES>|${IGconf_hybrid_raid_luks_ssd_devices:-/dev/sda,/dev/sdb}|g" \
    -e "s|<KEY_SIZE>|${IGconf_hybrid_raid_luks_key_size:-512}|g" \
    -e "s|<MKE2FS_CONFIG>|$(readlink -f mke2fs.conf)|g" \
    -e "s|<IGconf_hybrid_raid_luks_rootfs_type>|$rootfs_type|g" \
    "$template_file" > "${genimg_in}/genimage.cfg"

# Create provision map if requested (simplified)
if [[ "${IGconf_hybrid_raid_luks_pmap:-clear}" == "crypt" ]]; then
    cp device/provisionmap-crypt.json "${genimg_in}/provisionmap.json"
    # Basic placeholder replacement
    sed -i "s|<CRYPT_UUID>|$CRYPT_UUID|g" "${genimg_in}/provisionmap.json"
    echo "Provision map created for encrypted root filesystem" >&2
fi
