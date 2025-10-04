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
if [[ -z "$IGconf_mdraid1_external_root_raid_devices" ]]; then
    echo "ОШИБКА: Переменная mdraid1_external_root_raid_devices не установлена"
    exit 1
fi

if [[ -z "$IGconf_mdraid1_external_root_raid_level" ]]; then
    echo "ОШИБКА: Переменная mdraid1_external_root_raid_level не установлена"
    exit 1
fi

if [[ -z "$IGconf_mdraid1_external_root_rootfs_type" ]]; then
    echo "ОШИБКА: Переменная mdraid1_external_root_rootfs_type не установлена"
    exit 1
fi

# Check RAID1 requirements
raid_devices="$IGconf_mdraid1_external_root_raid_devices"
raid_level="$IGconf_mdraid1_external_root_raid_level"

if [[ "$raid_devices" -ne 2 ]]; then
    echo "ERROR: RAID1 requires exactly 2 devices, got $raid_devices"
    exit 1
fi

# Check filesystem support
case "$IGconf_mdraid1_external_root_rootfs_type" in
    ext4|btrfs|f2fs)
        echo "Filesystem $IGconf_mdraid1_external_root_rootfs_type is supported"
        ;;
    *)
        echo "ERROR: Unsupported filesystem $IGconf_mdraid1_external_root_rootfs_type"
        exit 1
        ;;
esac

echo "RAID validation completed successfully"

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

# Write genimage template
cat genimage.cfg.in.$IGconf_mdraid1_external_root_rootfs_type | sed \
   -e "s|<IMAGE_DIR>|$IGconf_mdraid1_external_root_assetdir|g" \
   -e "s|<IMAGE_NAME>|$IGconf_image_name|g" \
   -e "s|<IMAGE_SUFFIX>|$IGconf_image_suffix|g" \
   -e "s|<FW_SIZE>|$IGconf_mdraid1_external_root_boot_part_size|g" \
   -e "s|<ROOT_SIZE>|$IGconf_mdraid1_external_root_root_part_size|g" \
   -e "s|<SECTOR_SIZE>|$IGconf_mdraid1_external_root_sector_size|g" \
   -e "s|<SETUP>|'$(readlink -ef setup.sh)'|g" \
   -e "s|<MKE2FS_CONFIG>|'$(readlink -ef mke2fs.conf)'|g" \
   -e "s|<BOOT_LABEL>|$BOOT_LABEL|g" \
   -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
   -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
   -e "s|<DISK1_UUID>|$DISK1_UUID|g" \
   -e "s|<DISK2_UUID>|$DISK2_UUID|g" \
   > ${genimg_in}/genimage.cfg


# Install provision map and set UUIDs
if [[ -n "${IGconf_mdraid1_external_root_pmap:-}" ]]; then
   echo "Setting up provisioning map: ${IGconf_mdraid1_external_root_pmap}"

   # Copy the appropriate provision map
   local pmap_source="./device/provisionmap-${IGconf_mdraid1_external_root_pmap}.json"
   if [[ ! -f "$pmap_source" ]]; then
       echo "ERROR: Provision map not found: $pmap_source"
       exit 1
   fi

   cp "$pmap_source" "${IGconf_mdraid1_external_root_assetdir}/provisionmap.json"

   # Replace basic variables
   sed -i \
      -e "s|<CRYPT_UUID>|$CRYPT_UUID|g" \
      -e "s|<RAID_LEVEL>|$IGconf_mdraid1_external_root_raid_level|g" \
      -e "s|<RAID_DEVICES>|$IGconf_mdraid1_external_root_raid_devices|g" \
      -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
      -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
      -e "s|<DISK1_UUID>|$DISK1_UUID|g" \
      -e "s|<DISK2_UUID>|$DISK2_UUID|g" \
      "${IGconf_mdraid1_external_root_assetdir}/provisionmap.json"

   # Validate generated provisioning map
   if [[ ! -f "${IGconf_mdraid1_external_root_assetdir}/provisionmap.json" ]]; then
       echo "ERROR: Failed to create provisioning map"
       exit 1
   fi

   # Check if provisioning map is valid JSON
   if ! python3 -m json.tool "${IGconf_mdraid1_external_root_assetdir}/provisionmap.json" > /dev/null 2>&1; then
       echo "ERROR: Generated provisioning map is not valid JSON"
       python3 -m json.tool "${IGconf_mdraid1_external_root_assetdir}/provisionmap.json" || true
       exit 1
   fi

   echo "Provisioning map configured successfully"
fi
