#!/bin/bash

set -eu

LABEL="$1"
BOOTUUID="$2"
ROOTUUID="$3"

# Call parent setup.sh first for base functionality
if [[ -f "../simple_dual/setup.sh" ]]; then
    bash "../simple_dual/setup.sh" "$LABEL" "$BOOTUUID" "$ROOTUUID"
fi

# RAID-specific setup
case $LABEL in
   RAID1)
      # Setup RAID1 root filesystem
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
      esac

      # Add boot partition
      cat << EOF >> $IMAGEMOUNTPATH/etc/fstab
UUID=${BOOTUUID} /boot/firmware  vfat defaults,rw,noatime,errors=remount-ro 0 2
EOF

      # Update cmdline.txt for RAID boot
      sed -i "s|root=\([^ ]*\)|root=/dev/md0|" $IMAGEMOUNTPATH/cmdline.txt

      # Create RAID monitoring configuration
      cat << EOF > $IMAGEMOUNTPATH/etc/default/mdadm
# mdadm defaults for RAID$IGconf_raid_level
INITRDSTART='all'
AUTOSTART=true
AUTOCHECK=true
START_DAEMON=true
DAEMON_OPTIONS="--syslog"
EOF

      # Add RAID devices to fstab for monitoring
      for i in $(seq 1 $IGconf_raid_devices); do
         eval "ext_uuid=\${EXT${i}_UUID}"
         echo "# RAID device $i" >> $IMAGEMOUNTPATH/etc/fstab
         echo "UUID=\${ext_uuid} none auto 0 0" >> $IMAGEMOUNTPATH/etc/fstab
      done
      ;;
   RAID1P1|RAID1P2|RAID1P3|RAID1P4)
      # RAID partitions don't need individual fstab entries
      # They are part of the RAID array
      ;;
   BOOT)
      # Boot partition setup handled by parent
      ;;
   *)
      # Unknown label, let parent handle it
      ;;
esac

echo "RAID overlay setup.sh completed for label: $LABEL"
