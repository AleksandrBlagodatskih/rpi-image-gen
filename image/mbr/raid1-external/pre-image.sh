#!/bin/bash

set -eu

fs=$1
genimg_in=$2

[[ -d "$fs" ]] || exit 0

# ============================================================================
# RAID Requirements Validation
# ============================================================================

echo "Validating RAID requirements..."

# Validate required variables are set
if [[ -z "$IGconf_raid1_external_raid_devices" ]]; then
    echo "ERROR: raid1_external_raid_devices variable is not set"
    exit 1
fi

if [[ -z "$IGconf_raid1_external_raid_level" ]]; then
    echo "ERROR: raid1_external_raid_level variable is not set"
    exit 1
fi

if [[ -z "$IGconf_raid1_external_rootfs_type" ]]; then
    echo "ERROR: raid1_external_rootfs_type variable is not set"
    exit 1
fi

# Check RAID1 requirements
raid_devices="$IGconf_raid1_external_raid_devices"
raid_level="$IGconf_raid1_external_raid_level"

if [[ "$raid_devices" -ne 2 ]]; then
    echo "ERROR: RAID1 requires exactly 2 devices, got $raid_devices"
    exit 1
fi

# Check filesystem support
case "$IGconf_raid1_external_rootfs_type" in
    ext4|btrfs)
        echo "Filesystem $IGconf_raid1_external_rootfs_type is supported"
        ;;
    *)
        echo "ERROR: Unsupported filesystem $IGconf_raid1_external_rootfs_type"
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
cat genimage.cfg.in.$IGconf_raid1_external_rootfs_type | sed \
   -e "s|<IMAGE_DIR>|$IGconf_raid1_external_assetdir|g" \
   -e "s|<IMAGE_NAME>|$IGconf_image_name|g" \
   -e "s|<IMAGE_SUFFIX>|$IGconf_image_suffix|g" \
   -e "s|<FW_SIZE>|$IGconf_raid1_external_boot_part_size|g" \
   -e "s|<ROOT_SIZE>|$IGconf_raid1_external_root_part_size|g" \
   -e "s|<SECTOR_SIZE>|$IGconf_raid1_external_sector_size|g" \
   -e "s|<SETUP_SCRIPT>|'$(readlink -ef setup.sh)'|g" \
   -e "s|<MKE2FS_CONFIG>|'$(readlink -ef mke2fs.conf)'|g" \
   -e "s|<BOOT_LABEL>|$BOOT_LABEL|g" \
   -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
   -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
   -e "s|<DISK1_UUID>|$DISK1_UUID|g" \
   -e "s|<DISK2_UUID>|$DISK2_UUID|g" \
   > ${genimg_in}/genimage.cfg


# Install provision map and set UUIDs
if igconf isset raid1_external_pmap ; then
   cp ./device/provisionmap-${IGconf_raid1_external_pmap}.json ${IGconf_raid1_external_assetdir}/provisionmap.json

   # Replace basic variables
   sed -i \
      -e "s|<CRYPT_UUID>|$CRYPT_UUID|g" \
      -e "s|<RAID_LEVEL>|$IGconf_raid1_external_raid_level|g" \
      -e "s|<RAID_DEVICES>|$IGconf_raid1_external_raid_devices|g" ${IGconf_raid1_external_assetdir}/provisionmap.json

   # Generate external devices for RAID1 (2 devices)
   external_devices_json=", \"external1\": {\"partitions\": [{\"image\": \"raid1-disk1\"}]}, \"external2\": {\"partitions\": [{\"image\": \"raid1-disk2\"}]}"
   raid_partitions_json=", {\"image\": \"raid1-disk1\"}, {\"image\": \"raid1-disk2\"}"
   encrypted_raid_partitions_json=", {\"image\": \"raid1-disk1\"}, {\"image\": \"raid1-disk2\"}"

   # Insert external devices into provision map
   sed -i "s|\"sdcard\": {\"partitions\": \[{\"image\": \"boot\"}\]}|\"sdcard\": {\"partitions\": [{\"image\": \"boot\"}]${external_devices_json:+, $external_devices_json}}|" "${IGconf_raid1_external_assetdir}/provisionmap.json"

   # Add RAID partitions to appropriate section based on encryption
   if [[ "${IGconf_raid1_external_pmap}" == "crypt" ]]; then
       # For encrypted version, add to encrypted.partitions
       sed -i "s|<RAID_PARTITIONS>|$raid_partitions_json|g" "${IGconf_raid1_external_assetdir}/provisionmap.json"
       sed -i "s|<ENCRYPTED_RAID_PARTITIONS>|$encrypted_raid_partitions_json|g" "${IGconf_raid1_external_assetdir}/provisionmap.json"
   else
       # For clear version, add to top-level partitions
       sed -i "s|<RAID_PARTITIONS>|$raid_partitions_json|g" "${IGconf_raid1_external_assetdir}/provisionmap.json"
       sed -i "s|<ENCRYPTED_RAID_PARTITIONS>||g" "${IGconf_raid1_external_assetdir}/provisionmap.json"
   fi

   # Clean up empty partitions arrays if no RAID partitions
   if [[ -z "$raid_partitions_json" ]]; then
       sed -i 's|,\s*<RAID_PARTITIONS>||g' "${IGconf_raid1_external_assetdir}/provisionmap.json"
       sed -i 's|<RAID_PARTITIONS>||g' "${IGconf_raid1_external_assetdir}/provisionmap.json"
   fi

   # Validate generated provisioning map
   if [[ ! -f "${IGconf_raid1_external_assetdir}/provisionmap.json" ]]; then
       echo "ERROR: Failed to create provisioning map"
       exit 1
   fi

   # Check if provisioning map is valid JSON
   if ! python3 -m json.tool "${IGconf_raid1_external_assetdir}/provisionmap.json" > /dev/null 2>&1; then
       echo "ERROR: Generated provisioning map is not valid JSON"
       exit 1
   fi
fi
