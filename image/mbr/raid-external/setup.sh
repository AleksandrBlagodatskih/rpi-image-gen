#!/bin/bash

set -eu

LABEL="$1"
BOOTUUID="$2"
ROOTUUID="$3"

case $LABEL in
   ROOT)
      # Setup RAID1 root filesystem (using /dev/md0 instead of single partition)
      case $IGconf_image_rootfs_type in
         ext4)
            cat << EOF > $IMAGEMOUNTPATH/etc/fstab
/dev/md0 /               ext4 rw,relatime,errors=remount-ro,commit=30 0 1
EOF
            ;;
         btrfs)
            cat << EOF > $IMAGEMOUNTPATH/etc/fstab
/dev/md0 /               btrfs defaults 0 0
EOF
            ;;
         *)
            ;;
      esac

      # Add boot partition
      cat << EOF >> $IMAGEMOUNTPATH/etc/fstab
UUID=${BOOTUUID} /boot/firmware  vfat defaults,rw,noatime,errors=remount-ro 0 2
EOF

      # Note: cmdline.txt is updated in BOOT case, not here

      # Create RAID monitoring configuration
      cat << EOF > $IMAGEMOUNTPATH/etc/default/mdadm
# mdadm defaults for RAID$IGconf_image_raid_level
INITRDSTART='all'
AUTOSTART=true
AUTOCHECK=true
START_DAEMON=true
DAEMON_OPTIONS="--syslog"
EOF

      # Add RAID devices to fstab for monitoring
      # Read UUIDs from img_uuids file
      if [[ -f "${IGconf_image_outputdir}/img_uuids" ]]; then
         for i in $(seq 1 $IGconf_image_raid_devices); do
            ext_uuid=$(grep "^EXT${i}_UUID=" "${IGconf_image_outputdir}/img_uuids" | cut -d= -f2)
            if [[ -n "$ext_uuid" ]]; then
               echo "# RAID device $i" >> $IMAGEMOUNTPATH/etc/fstab
               echo "UUID=$ext_uuid none auto 0 0" >> $IMAGEMOUNTPATH/etc/fstab
            fi
         done
      fi
      ;;
   RAID1P1|RAID1P2|RAID1P3|RAID1P4)
      # RAID partitions don't need individual fstab entries
      # They are part of the RAID array
      ;;
   BOOT)
      # Boot partition setup - update cmdline.txt for RAID boot
      sed -i "s|root=\([^ ]*\)|root=/dev/md0|" $IMAGEMOUNTPATH/cmdline.txt
      ;;
   *)
      ;;
esac
