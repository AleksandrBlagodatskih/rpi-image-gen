#!/bin/bash

set -eu

fs=$1
genimg_in=$2

[[ -d "$fs" ]] || exit 0

# RAID overlay - generate our own configuration instead of using parent
# RAID-specific UUID generation and configuration
case $IGconf_raid_level in
    RAID0)
        RAID_DEVICES_MIN=2
        MDADM_LEVEL=0
        ;;
    RAID1)
        RAID_DEVICES_MIN=2
        MDADM_LEVEL=1
        ;;
    *)
        echo "Unsupported RAID level: $IGconf_raid_level" >&2
        exit 1
        ;;
esac

# Validate device count
if [[ $IGconf_raid_devices -lt $RAID_DEVICES_MIN ]]; then
    echo "RAID$MDADM_LEVEL requires at least $RAID_DEVICES_MIN devices, got $IGconf_raid_devices" >&2
    exit 1
fi

# Generate additional UUIDs for external drives
for i in $(seq 1 $IGconf_raid_devices); do
    eval "EXT${i}_UUID=\$(uuidgen)"
    eval "EXT${i}_LABEL=\"EXT${i}\""
done

# Update UUID file with external drive UUIDs
for i in $(seq 1 $IGconf_raid_devices); do
    for var in "EXT${i}_UUID" "EXT${i}_LABEL"; do
        eval "val=\$$var"
        echo "$var=$val" >> "${IGconf_image_outputdir}/img_uuids"
    done
done

# Generate RAID configuration
RAID_CONFIG_FILE="${IGconf_image_outputdir}/raid_config.sh"
cat > "$RAID_CONFIG_FILE" << EOF
#!/bin/bash
set -eu

# RAID configuration for level $IGconf_raid_level with $IGconf_raid_devices devices
RAID_LEVEL=$MDADM_LEVEL
RAID_DEVICES=$IGconf_raid_devices
RAID_UUID=$RAID_UUID

# Device mapping for external drives
EOF

# Add device mapping to RAID config
for i in $(seq 1 $IGconf_raid_devices); do
    echo "EXT${i}_DEVICE=/dev/external${i}" >> "$RAID_CONFIG_FILE"
    echo "EXT${i}_PARTITION=\${EXT${i}_DEVICE}p1" >> "$RAID_CONFIG_FILE"
done

# Generate RAID creation commands
cat >> "$RAID_CONFIG_FILE" << EOF

# Create RAID array
create_raid_array() {
    local raid_device=\$1
    local level=\$RAID_LEVEL
    local devices=\$RAID_DEVICES
    local uuid=\$RAID_UUID

    echo "Creating RAID\$level array \$raid_device with \$devices devices"

    # Build device list
    local device_list=""
    for i in \$(seq 1 \$devices); do
        eval "part=\${EXT\${i}_PARTITION}"
        device_list="\$device_list \$part"
    done

    # Create RAID array
    mdadm --create --verbose \$raid_device \\
        --level=\$level \\
        --raid-devices=\$devices \\
        --uuid=\$uuid \\
        \$device_list

    # Wait for RAID initialization
    sleep 2

    # Update mdadm.conf
    mkdir -p /etc/mdadm
    echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
    mdadm --detail --scan >> /etc/mdadm/mdadm.conf
}

# Initialize RAID array for root filesystem
create_raid_array /dev/md0

echo "RAID\$RAID_LEVEL setup completed with \$RAID_DEVICES devices"
EOF

chmod +x "$RAID_CONFIG_FILE"

# Generate base UUIDs (similar to simple_dual)
BOOT_LABEL=$(uuidgen | sed 's/-.*//' | tr 'a-f' 'A-F')
BOOT_UUID=$(echo "$BOOT_LABEL" | sed 's/^\(....\)\(....\)$/\1-\2/')
RAID_UUID=$(uuidgen)

# Calculate RAID partition sizes
RAID_PART_SIZE=$(($(echo "${IGconf_raid_external_size}" | sed 's/%$//') / $IGconf_raid_devices))%

# Update UUID file
rm -f "${IGconf_image_outputdir}/img_uuids"
for v in BOOT_LABEL BOOT_UUID RAID_UUID; do
    eval "val=\$$v"
    echo "$v=$val" >> "${IGconf_image_outputdir}/img_uuids"
done

# Generate genimage template
cat genimage.cfg.in.$IGconf_image_rootfs_type | sed \
   -e "s|<IMAGE_DIR>|$IGconf_image_outputdir|g" \
   -e "s|<IMAGE_NAME>|$IGconf_image_name|g" \
   -e "s|<IMAGE_SUFFIX>|$IGconf_image_suffix|g" \
   -e "s|<RAID_SDCARD_SIZE>|$IGconf_raid_sdcard_size|g" \
   -e "s|<RAID_PART_SIZE>|$RAID_PART_SIZE|g" \
   -e "s|<SECTOR_SIZE>|$IGconf_device_sector_size|g" \
   -e "s|<SETUP>|'$(readlink -ef setup.sh)'|g" \
   -e "s|<MKE2FSCONF>|'$(readlink -ef ../simple_dual/mke2fs.conf)'|g" \
   -e "s|<BOOT_LABEL>|$BOOT_LABEL|g" \
   -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
   -e "s|<RAID_UUID>|$RAID_UUID|g" \
   -e "s|<RAID_LEVEL>|$IGconf_raid_level|g" \
   > "${genimg_in}/genimage.cfg"

echo "RAID overlay pre-image.sh completed"
