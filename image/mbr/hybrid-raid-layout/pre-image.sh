#!/bin/bash
# Pre-image script for Hybrid RAID Layout

set -euo pipefail

# Validate arguments
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <filesystem_path> <genimage_input_dir>" >&2
    exit 1
fi

fs="$1"
genimg_in="$2"

# Validate directories
if [[ ! -d "$fs" ]]; then
    echo "Error: filesystem path '$fs' is not a directory" >&2
    exit 1
fi

if [[ ! -d "$genimg_in" ]]; then
    echo "Error: genimage input dir '$genimg_in' is not a directory" >&2
    exit 1
fi

# Config validation
: "${IGconf_hybrid_raid_luks_ssd_ids:?"ssd_ids not configured"}"
encryption_enabled="${IGconf_hybrid_raid_luks_encryption_enabled:-n}"
rootfs_type="${IGconf_hybrid_raid_luks_rootfs_type:-ext4}"

case "$encryption_enabled" in y|n) ;; *) echo "Error: encryption_enabled must be 'y' or 'n'" >&2; exit 1 ;; esac
case "$rootfs_type" in ext4|btrfs|f2fs) ;; *) echo "Error: unsupported rootfs_type '$rootfs_type'" >&2; exit 1 ;; esac

# Generate UUIDs
mapfile -t uuids < <(uuidgen && uuidgen && uuidgen)
BOOT_UUID=${uuids[0]}
ROOT_UUID=${uuids[1]}
RAID_UUID=${uuids[2]}

# Setup encryption if enabled
if [[ "$encryption_enabled" == "y" ]]; then
    CRYPT_UUID=$(uuidgen)
    openssl rand -out "${genimg_in}/luks_key.bin" $(( ${IGconf_hybrid_raid_luks_key_size:-512} / 8 ))
    chmod 600 "${genimg_in}/luks_key.bin"
fi

# Process templates
sed -i "s|<SSD_IDS>|$IGconf_hybrid_raid_luks_ssd_ids|g" "$fs/etc/initramfs-tools/hooks/hybrid-raid" 2>/dev/null || true
sed -i "s|<RAID_UUID>|$RAID_UUID|g" "$fs/etc/initramfs-tools/scripts/local-top/rpi-raid" 2>/dev/null || true
[[ -n "${CRYPT_UUID:-}" ]] && sed -i "s|<CRYPT_UUID>|$CRYPT_UUID|g" "$fs/etc/initramfs-tools/scripts/local-top/rpi-luks" 2>/dev/null || true

# Save config
cat > "${genimg_in}/img_uuids" << EOF
BOOT_UUID=$BOOT_UUID
ROOT_UUID=$ROOT_UUID
${CRYPT_UUID:+CRYPT_UUID=$CRYPT_UUID}
RAID_UUID=$RAID_UUID
ENCRYPTION_ENABLED=$encryption_enabled
EOF

# Generate genimage config
boot_size="${IGconf_hybrid_raid_luks_boot_part_size:-200M}"
root_size="${IGconf_hybrid_raid_luks_root_part_size:-2G}"

if [[ "$encryption_enabled" == "y" ]]; then
    case "$root_size" in
        *G) luks_size="$(( ${root_size%G} * 1024 + 20 ))M" ;;
        *M) luks_size="$(( ${root_size%M} + 20 ))M" ;;
    esac
    raid_size="$luks_size"
else
    raid_size="$root_size"
fi

sed \
    -e "s|<BOOT_SIZE>|$boot_size|g" \
    -e "s|<ROOT_SIZE>|$root_size|g" \
    -e "s|<RAID_PARTITION_SIZE>|$raid_size|g" \
    -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
    -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
    -e "s|<RAID_UUID>|$RAID_UUID|g" \
    -e "s|<IGconf_hybrid_raid_luks_rootfs_type>|$rootfs_type|g" \
    -e "s|<ENCRYPTION_ENABLED>|$encryption_enabled|g" \
    -e "s|<LUKS_CONTAINER_SIZE>|${luks_size:-}|g" \
    -e "s|<CRYPT_UUID>|${CRYPT_UUID:-}|g" \
    -e "s|<KEY_SIZE>|${IGconf_hybrid_raid_luks_key_size:-512}|g" \
    -e "s|<LUKS_KEY_FILE>|${genimg_in}/luks_key.bin|g" \
    -e "s|<MKE2FS_CONFIG>|$(readlink -f mke2fs.conf)|g" \
    -e "s|<SETUP>|$(readlink -f setup.sh)|g" \
    "genimage.cfg.in" > "${genimg_in}/genimage.cfg"

# Install provision map
if [[ -n "${IGconf_image_outputdir:-}" && -d "$IGconf_image_outputdir" ]]; then
    provisionmap_file="device/provisionmap-${encryption_enabled:+crypt}${encryption_enabled:-clear}.json"
    if [[ -f "$provisionmap_file" ]]; then
        cp "$provisionmap_file" "${IGconf_image_outputdir}/provisionmap.json"
        [[ "$encryption_enabled" == "y" && -n "${CRYPT_UUID:-}" ]] && sed -i "s|<CRYPT_UUID>|${CRYPT_UUID}|g" "${IGconf_image_outputdir}/provisionmap.json"
    fi
fi
