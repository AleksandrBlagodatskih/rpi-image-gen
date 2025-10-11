#!/bin/bash
set -euo pipefail

# Function for error handling
die() { echo "ERROR: $*" >&2; exit 1; }

fs="$1"
genimg_in="$2"

# Basic validation (rpi-image-gen framework handles most validation)
: "${IGconf_hybrid_raid_luks_ssd_ids:?"ssd_ids not configured"}"

# Validate encryption_enabled
case "${IGconf_hybrid_raid_luks_encryption_enabled:-n}" in
    y|n) ;;
    *) die "encryption_enabled must be 'y' or 'n'" ;;
esac

# Validate rootfs_type
case "${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" in
    ext4|btrfs|f2fs) ;;
    *) die "Unsupported rootfs_type: ${IGconf_hybrid_raid_luks_rootfs_type}" ;;
esac

# Validate pmap
case "${IGconf_hybrid_raid_luks_pmap:-clear}" in
    clear|crypt) ;;
    *) die "pmap must be 'clear' or 'crypt'" ;;
esac

# Validate key_method if encryption is enabled
if [ "${IGconf_hybrid_raid_luks_encryption_enabled:-n}" = "y" ]; then
    case "${IGconf_hybrid_raid_luks_key_method:-file}" in
        file) ;;
        *) die "Only 'file' key method is supported" ;;
    esac

    # Validate key_size
    key_size="${IGconf_hybrid_raid_luks_key_size:-512}"
    if ! [[ "$key_size" =~ ^[0-9]+$ ]] || (( key_size < 256 || key_size > 8192 )); then
        die "key_size must be integer between 256 and 8192"
    fi
fi

# Generate UUIDs for partitions (batch generation for performance)
mapfile -t uuids < <(uuidgen && uuidgen && uuidgen && uuidgen)
BOOT_UUID=${uuids[0]}
ROOT_UUID=${uuids[1]}
RAID_UUID=${uuids[3]}

# Validate UUID format
validate_uuid() {
    local uuid="$1" name="$2"
    [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || die "Invalid ${name} UUID format: ${uuid}"
}

# Validate all UUIDs at once
validate_uuid "$BOOT_UUID" "BOOT"
validate_uuid "$ROOT_UUID" "ROOT"
validate_uuid "$RAID_UUID" "RAID"

# Configure overlay templates with actual values (before genimage generation)
if [ -f "configure-overlay.sh" ]; then
    echo "🔧 Configuring overlay templates..."
    bash configure-overlay.sh
else
    echo "WARNING: configure-overlay.sh not found, overlay templates not processed" >&2
fi

# Encryption configuration (optional) - ultra compact
encryption_enabled="${IGconf_hybrid_raid_luks_encryption_enabled:-n}"
[[ "$encryption_enabled" == "y" ]] && {
    # Validation chain
    [[ "${IGconf_hybrid_raid_luks_key_method:-file}" == "file" ]] || die "Only 'file' key method is supported for security reasons"

    # Generate CRYPT UUID
    CRYPT_UUID=$(uuidgen)
    validate_uuid "$CRYPT_UUID" "CRYPT"

    # Generate LUKS key (openssl check + file generation + permissions)
    command -v openssl >/dev/null 2>&1 || die "openssl required for LUKS key generation"
    luks_key_file="${genimg_in}/luks_key.bin"
    [[ ! -f "$luks_key_file" ]] && openssl rand -out "$luks_key_file" $(( ${IGconf_hybrid_raid_luks_key_size:-512} / 8 ))
    chmod 600 "$luks_key_file"
}

# Save essential UUIDs for other scripts - single heredoc with conditional line
cat > "${genimg_in}/img_uuids" << EOF
BOOT_UUID=$BOOT_UUID
ROOT_UUID=$ROOT_UUID
${CRYPT_UUID:+CRYPT_UUID=$CRYPT_UUID}
RAID_UUID=$RAID_UUID
ENCRYPTION_ENABLED=$encryption_enabled
EOF

# Validate SSD device IDs if specified (hybrid-raid-layout specific)
if [ -n "${IGconf_hybrid_raid_luks_ssd_ids:-}" ]; then
    echo "🔍 Validating SSD device IDs..."
    IFS=',' read -ra ssd_ids <<< "$IGconf_hybrid_raid_luks_ssd_ids"
    for id in "${ssd_ids[@]}"; do
        id_path="/dev/disk/by-id/$id"
        if [ ! -b "$id_path" ] && [ ! -L "$id_path" ]; then
            echo "WARNING: SSD device ID not found during build: ${id} (${id_path})" >&2
            echo "This is normal during image build - IDs will be validated at runtime" >&2
        else
            echo "✅ SSD device ID found: ${id} -> ${id_path}"
        fi
    done
fi

# Generate genimage configuration - compact file check
[[ -f "genimage.cfg.in" ]] || die "Template file genimage.cfg.in not found"

# Validate rootfs_type - single line case
case "${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" in
    ext4|btrfs|f2fs) rootfs_type="${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" ;;
    *) die "Unsupported rootfs_type: ${IGconf_hybrid_raid_luks_rootfs_type}" ;;
esac

# Calculate sizes with overhead considerations
root_size="${IGconf_hybrid_raid_luks_root_part_size:-2G}"
boot_size="${IGconf_hybrid_raid_luks_boot_part_size:-200M}"

# Size calculations - ultra compact ternary-style
[[ "$encryption_enabled" == "y" ]] && {
    # Parse size and calculate LUKS overhead in one chain
    case "$root_size" in
        *G) luks_container_size="$(( ${root_size%G} * 1024 + 20 ))M" ;;
        *M) luks_container_size="$(( ${root_size%M} + 20 ))M" ;;
        *) die "Unsupported size format: ${root_size}" ;;
    esac
    raid_partition_size="$luks_container_size"
} || raid_partition_size="$root_size"

# Generate sed substitutions - grouped by type
sed \
    -e "s|<IMAGE_NAME>|\"$IGconf_image_name\"|g" \
    -e "s|<IMAGE_SUFFIX>|\"$IGconf_image_suffix\"|g" \
    -e "s|<BOOT_SIZE>|$boot_size|g" \
    -e "s|<ROOT_SIZE>|$root_size|g" \
    -e "s|<RAID_PARTITION_SIZE>|$raid_partition_size|g" \
    -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
    -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
    -e "s|<RAID_UUID>|$RAID_UUID|g" \
    -e "s|<IGconf_hybrid_raid_luks_rootfs_type>|$rootfs_type|g" \
    -e "s|<ENCRYPTION_ENABLED>|$encryption_enabled|g" \
    -e "s|<LUKS_CONTAINER_SIZE>|${luks_container_size:-}|g" \
    -e "s|<CRYPT_UUID>|${CRYPT_UUID:-}|g" \
    -e "s|<KEY_SIZE>|${IGconf_hybrid_raid_luks_key_size:-512}|g" \
    -e "s|<LUKS_KEY_FILE>|${luks_key_file:-}|g" \
    -e "s|<MKE2FS_CONFIG>|$(readlink -f mke2fs.conf)|g" \
    -e "s|<SETUP>|$(readlink -f setup.sh)|g" \
    "genimage.cfg.in" > "${genimg_in}/genimage.cfg"

# Install provision map - select based on encryption status
provisionmap_file="device/provisionmap-${encryption_enabled:+crypt}${encryption_enabled:-clear}.json"
[[ -f "$provisionmap_file" ]] && {
    cp "$provisionmap_file" "${IGconf_image_outputdir}/provisionmap.json"
    [[ "$encryption_enabled" == "y" && -n "${CRYPT_UUID:-}" ]] && sed -i "s|<CRYPT_UUID>|${CRYPT_UUID}|g" "${IGconf_image_outputdir}/provisionmap.json"
}

# Final status - compact
echo "Generated genimage configuration for encryption=${encryption_enabled}"
