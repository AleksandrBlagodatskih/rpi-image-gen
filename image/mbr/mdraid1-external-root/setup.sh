#!/bin/bash

set -eu

LABEL="$1"
BOOTUUID="$2"
ROOTUUID="$3"

# Load key management functions
source "$(dirname "$0")/key-management.sh"

case $LABEL in
   ROOT)
      # Setup RAID1 root filesystem (genimage mdraid creates the RAID array)
      # The RAID array is assembled by Linux from the two RAID member disks
      # genimage creates the member disks with proper RAID metadata

      # Determine root device based on encryption flag
      if [[ "${IGconf_mdraid1_external_root_encryption_enabled:-n}" == "y" ]]; then
         echo "Setting up secure key management..."
         manage_encryption_key "$IMAGEMOUNTPATH/boot/firmware"

         # Configure crypttab for encrypted RAID
         echo "Configuring crypttab for encrypted RAID..."
         cat << EOF > $IMAGEMOUNTPATH/etc/crypttab
# Encrypted RAID root filesystem
cryptroot /dev/md0 none luks,discard,keyscript=/bin/manage-encryption-key
EOF

         # For encrypted RAID, we mount the LUKS device
         ROOT_DEVICE="/dev/mapper/cryptroot"
      else
         # For unencrypted RAID, mount the RAID array directly
         ROOT_DEVICE="/dev/md0"
      fi

      # Setup fstab with the correct root device
      case $IGconf_mdraid1_external_root_rootfs_type in
         ext4)
            cat << EOF > $IMAGEMOUNTPATH/etc/fstab
${ROOT_DEVICE} /               ext4 rw,relatime,errors=remount-ro,commit=30 0 1
EOF
            ;;
         btrfs)
            cat << EOF > $IMAGEMOUNTPATH/etc/fstab
${ROOT_DEVICE} /               btrfs defaults 0 0
EOF
            ;;
         f2fs)
            cat << EOF > $IMAGEMOUNTPATH/etc/fstab
${ROOT_DEVICE} /               f2fs rw,relatime,lazytime,background_gc=on,discard,no_heap 0 0
EOF
            ;;
         *)
            ;;
      esac

      # Add boot partition
      cat << EOF >> $IMAGEMOUNTPATH/etc/fstab
UUID=${BOOTUUID} /boot/firmware  vfat defaults,rw,noatime,errors=remount-ro 0 2
EOF

      # Note: cmdline.txt is updated in BOOT case for both encrypted and unencrypted RAID

      # Create RAID monitoring configuration (genimage mdraid handles array creation)
      cat << EOF > $IMAGEMOUNTPATH/etc/default/mdadm
# mdadm defaults for RAID$IGconf_mdraid1_external_root_raid_level (genimage mdraid)
INITRDSTART='all'
AUTOSTART=true
AUTOCHECK=true
START_DAEMON=true
DAEMON_OPTIONS="--syslog"
EOF

      # Add RAID devices to fstab for monitoring
      # Read UUIDs from img_uuids file
      if [[ -f "${IGconf_mdraid1_external_root_assetdir}/img_uuids" ]]; then
         for i in 1 2; do
            ext_uuid=$(grep "^EXT${i}_UUID=" "${IGconf_mdraid1_external_root_assetdir}/img_uuids" | cut -d= -f2)
            if [[ -n "$ext_uuid" ]]; then
               echo "# RAID device $i" >> $IMAGEMOUNTPATH/etc/fstab
               echo "UUID=$ext_uuid none auto 0 0" >> $IMAGEMOUNTPATH/etc/fstab
            fi
         done
      fi
      ;;
   RAID)
      # RAID member disks created by genimage mdraid
      # No additional setup needed - Linux will assemble the array
      echo "RAID member disk configured by genimage mdraid"
      ;;
   BOOT)
      # Boot partition setup - update cmdline.txt for RAID boot
      # Use the same ROOT_DEVICE variable determined in ROOT section
      if [[ "${IGconf_mdraid1_external_root_encryption_enabled:-n}" == "y" ]]; then
         sed -i "s|root=\([^ ]*\)|root=/dev/mapper/cryptroot|" $IMAGEMOUNTPATH/cmdline.txt
         echo "Boot configured for encrypted RAID - using /dev/mapper/cryptroot"
      else
         sed -i "s|root=\([^ ]*\)|root=/dev/md0|" $IMAGEMOUNTPATH/cmdline.txt
         echo "Boot configured for unencrypted RAID - using /dev/md0"
      fi
      ;;
   RAID)
      # RAID array setup - genimage mdraid creates the RAID member disks
      # Linux will automatically assemble the RAID array from the member disks
      echo "RAID member disks created by genimage mdraid"
      ;;
   *)
      ;;
esac
