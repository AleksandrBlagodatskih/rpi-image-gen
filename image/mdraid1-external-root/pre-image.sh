#!/bin/bash
#
# pre-image.sh - подготовка образов для RAID external
# Валидация требований RAID и генерация конфигурации genimage
#

set -eu

# Параметры скрипта
fs=$1        # Путь к файловой системе
genimg_in=$2 # Директория для выходных файлов genimage

# Проверка существования файловой системы
[[ -d "$fs" ]] || exit 0

# ============================================================================
# Валидация требований RAID
# ============================================================================

echo "Валидация требований RAID..."

# Валидация обязательных переменных
if [[ -z "$IGconf_image_raid_devices" ]]; then
    echo "ОШИБКА: Переменная image_raid_devices не установлена"
    exit 1
fi

if [[ -z "$IGconf_image_raid_level" ]]; then
    echo "ОШИБКА: Переменная image_raid_level не установлена"
    exit 1
fi

if [[ -z "$IGconf_image_rootfs_type" ]]; then
    echo "ОШИБКА: Переменная image_rootfs_type не установлена"
    exit 1
fi

# Check RAID1 requirements
raid_devices="$IGconf_image_raid_devices"
raid_level="$IGconf_image_raid_level"

if [[ "$raid_devices" -ne 2 ]]; then
    echo "ERROR: RAID1 requires exactly 2 devices, got $raid_devices"
    exit 1
fi

# Check filesystem support
case "$IGconf_image_rootfs_type" in
    ext4|btrfs|f2fs)
        echo "Filesystem $IGconf_image_rootfs_type is supported"
        ;;
    *)
        echo "ERROR: Unsupported filesystem $IGconf_image_rootfs_type"
        exit 1
        ;;
esac

echo "RAID validation completed successfully"

# ============================================================================
# Автоматический выбор provision map на основе настроек шифрования
# ============================================================================

# Автоматический выбор provision map на основе шифрования
if [[ "${IGconf_image_encryption_enabled:-n}" == "y" ]]; then
    IGconf_image_pmap="crypt"
    echo "Шифрование включено - выбран provision map: crypt"
else
    IGconf_image_pmap="clear"
    echo "Шифрование отключено - выбран provision map: clear"
fi

# ============================================================================
# Generate pre-defined UUIDs
# ============================================================================

# Check if uuidgen is available
if ! command -v uuidgen &> /dev/null; then
    echo "ERROR: uuidgen command not found. Please install uuid-runtime package."
    exit 1
fi
BOOT_LABEL=$(uuidgen | sed 's/-.*//' | tr 'a-f' 'A-F')
BOOT_UUID=$(echo "$BOOT_LABEL" | sed 's/^\(....\)\(....\)$/\1-\2/')
ROOT_UUID=$(uuidgen)
CRYPT_UUID=$(uuidgen)

# RAID UUID (same as root for simplicity)
RAID_UUID=$ROOT_UUID

# Generate UUIDs for RAID1 disks
DISK1_UUID=$(uuidgen)
DISK2_UUID=$(uuidgen)

# Generate UUIDs for 2 external drives (RAID1)
EXT1_UUID=$(uuidgen)
EXT1_LABEL="EXT1"
EXT2_UUID=$(uuidgen)
EXT2_LABEL="EXT2"

rm -f ${IGconf_image_outputdir}/img_uuids
for v in BOOT_LABEL BOOT_UUID ROOT_UUID RAID_UUID CRYPT_UUID DISK1_UUID DISK2_UUID; do
    eval "val=\$$v"
    echo "$v=$val" >> "${IGconf_image_outputdir}/img_uuids"
done

# Update UUID file with external drive UUIDs
for var in EXT1_UUID EXT1_LABEL EXT2_UUID EXT2_LABEL; do
    eval "val=\$$var"
    echo "$var=$val" >> "${IGconf_image_outputdir}/img_uuids"
done

# Calculate root filesystem size if auto
calculate_root_size() {
    if [[ "${IGconf_image_root_part_size:-auto}" == "auto" ]]; then
        # Calculate size based on chroot content with 50% overhead for safety
        local chroot_size
        chroot_size=$(du -sb "$1" | awk '{print int($1 * 1.5)}')  # 50% overhead

        # Ensure minimum size (256MB) and convert to MB
        local min_size=$((256 * 1024 * 1024))  # 256MB in bytes
        if [[ $chroot_size -lt $min_size ]]; then
            chroot_size=$min_size
        fi

        # Convert to MB and add some padding
        ROOT_SIZE_MB=$(( (chroot_size + 1024*1024 - 1) / (1024*1024) + 128 ))M
        echo "Calculated root size: $ROOT_SIZE_MB (from $(du -sh "$1" | cut -f1))"
    else
        ROOT_SIZE_MB="$IGconf_image_root_part_size"
    fi
}

# Calculate root filesystem size
calculate_root_size "$1"

# Copy mke2fs.conf to genimage working directory
cp "$(readlink -ef mke2fs.conf)" "${genimg_in}/"

# Write genimage template
cat genimage.cfg.in.$IGconf_image_rootfs_type | sed \
   -e "s|<IMAGE_DIR>|$IGconf_image_assetdir|g" \
   -e "s|<IMAGE_NAME>|$IGconf_image_name|g" \
   -e "s|<IMAGE_SUFFIX>|$IGconf_image_suffix|g" \
   -e "s|<FW_SIZE>|$IGconf_image_boot_part_size|g" \
   -e "s|<ROOT_SIZE>|$ROOT_SIZE_MB|g" \
   -e "s|<SECTOR_SIZE>|$IGconf_image_sector_size|g" \
   -e "s|<SETUP>|'$(readlink -ef setup.sh)'|g" \
   -e "s|<MKE2FS_CONFIG>|$(readlink -ef mke2fs.conf)|g" \
   -e "s|<BOOT_LABEL>|$BOOT_LABEL|g" \
   -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
   -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
   -e "s|<DISK1_UUID>|$DISK1_UUID|g" \
   -e "s|<DISK2_UUID>|$DISK2_UUID|g" \
   > ${genimg_in}/genimage.cfg


# Install provision map and set UUIDs
if [[ -n "${IGconf_image_pmap:-}" ]]; then
   echo "Setting up provisioning map: ${IGconf_image_pmap}"

   # Copy the appropriate provision map
   pmap_source="./device/provisionmap-${IGconf_image_pmap}.json"
   if [[ ! -f "$pmap_source" ]]; then
       echo "ERROR: Provision map not found: $pmap_source"
       exit 1
   fi

   cp "$pmap_source" "${IGconf_image_outputdir}/provisionmap.json"

   # Replace basic variables
   sed -i \
      -e "s|<CRYPT_UUID>|$CRYPT_UUID|g" \
      -e "s|<RAID_LEVEL>|$IGconf_image_raid_level|g" \
      -e "s|<RAID_DEVICES>|$IGconf_image_raid_devices|g" \
      -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
      -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
      -e "s|<DISK1_UUID>|$DISK1_UUID|g" \
      -e "s|<DISK2_UUID>|$DISK2_UUID|g" \
      "${IGconf_image_outputdir}/provisionmap.json"

   # Validate generated provisioning map
   if [[ ! -f "${IGconf_image_outputdir}/provisionmap.json" ]]; then
       echo "ERROR: Failed to create provisioning map"
       exit 1
   fi

   # Check if provisioning map is valid JSON
   if ! python3 -m json.tool "${IGconf_image_outputdir}/provisionmap.json" > /dev/null 2>&1; then
       echo "ERROR: Generated provisioning map is not valid JSON"
       python3 -m json.tool "${IGconf_image_outputdir}/provisionmap.json" || true
       exit 1
   fi

   echo "Provisioning map configured successfully"
fi
