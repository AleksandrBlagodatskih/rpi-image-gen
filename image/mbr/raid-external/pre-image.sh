#!/bin/bash

set -eu

fs=$1
genimg_in=$2

[[ -d "$fs" ]] || exit 0


# Generate pre-defined UUIDs
BOOT_LABEL=$(uuidgen | sed 's/-.*//' | tr 'a-f' 'A-F')
BOOT_UUID=$(echo "$BOOT_LABEL" | sed 's/^\(....\)\(....\)$/\1-\2/')
ROOT_UUID=$(uuidgen)
CRYPT_UUID=$(uuidgen)

# RAID UUID (same as root for simplicity)
RAID_UUID=$ROOT_UUID

# Generate additional UUIDs for external drives
for i in $(seq 1 "$IGconf_image_raid_devices"); do
    eval "EXT${i}_UUID=$(uuidgen)"
    eval "EXT${i}_LABEL=EXT${i}"
done

rm -f ${IGconf_image_outputdir}/img_uuids
for v in BOOT_LABEL BOOT_UUID ROOT_UUID RAID_UUID CRYPT_UUID; do
    eval "val=\$$v"
    echo "$v=$val" >> "${IGconf_image_outputdir}/img_uuids"
done

# Update UUID file with external drive UUIDs
for i in $(seq 1 $IGconf_image_raid_devices); do
    for var in "EXT${i}_UUID" "EXT${i}_LABEL"; do
        eval "val=\$$var"
        echo "$var=$val" >> "${IGconf_image_outputdir}/img_uuids"
    done
done

# Write genimage template
cat genimage.cfg.in.$IGconf_image_rootfs_type | sed \
   -e "s|<IMAGE_DIR>|$IGconf_image_outputdir|g" \
   -e "s|<IMAGE_NAME>|$IGconf_image_name|g" \
   -e "s|<IMAGE_SUFFIX>|$IGconf_image_suffix|g" \
   -e "s|<FW_SIZE>|$IGconf_image_boot_part_size|g" \
   -e "s|<ROOT_SIZE>|$IGconf_image_root_part_size|g" \
   -e "s|<SECTOR_SIZE>|$IGconf_device_sector_size|g" \
   -e "s|<SETUP>|'$(readlink -ef setup.sh)'|g" \
   -e "s|<MKE2FSCONF>|'$(readlink -ef mke2fs.conf)'|g" \
   -e "s|<BOOT_LABEL>|$BOOT_LABEL|g" \
   -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
   -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
   > ${genimg_in}/genimage.cfg


# Install provision map and set UUIDs
if igconf isset image_pmap ; then
   cp ./device/provisionmap-${IGconf_image_pmap}.json ${IGconf_image_outputdir}/provisionmap.json

   # Replace basic variables
   sed -i \
      -e "s|<CRYPT_UUID>|$CRYPT_UUID|g" \
      -e "s|<RAID_LEVEL>|$IGconf_image_raid_level|g" \
      -e "s|<RAID_DEVICES>|$IGconf_image_raid_devices|g" ${IGconf_image_outputdir}/provisionmap.json

   # Generate external devices dynamically
   external_devices_json=""
   for i in $(seq 1 "$IGconf_image_raid_devices"); do
       external_devices_json="${external_devices_json}, \"external${i}\": {\"partitions\": [{\"image\": \"raid1_part${i}\"}]}"
   done

   # Insert external devices into provision map
   sed -i "s|\"sdcard\": {\"partitions\": \[{\"image\": \"boot\"}\]}|\"sdcard\": {\"partitions\": [{\"image\": \"boot\"}]}${external_devices_json}|" "${IGconf_image_outputdir}/provisionmap.json"

   # Add RAID partitions to appropriate section based on encryption
   raid_partitions_json=$(printf '{"image": "raid1_part%d"}' $(seq 1 "$IGconf_image_raid_devices") | sed 's/}{/},{/g')

   if [[ "${IGconf_image_pmap}" == "crypt" ]]; then
       # For encrypted version, add to encrypted.partitions
       sed -i "s|\"partitions\": \[\]|\"partitions\": [${raid_partitions_json}]|" "${IGconf_image_outputdir}/provisionmap.json"
   else
       # For clear version, add to top-level partitions
       sed -i "s|\"partitions\": \[\]|\"partitions\": [${raid_partitions_json}]|" "${IGconf_image_outputdir}/provisionmap.json"
   fi
fi
