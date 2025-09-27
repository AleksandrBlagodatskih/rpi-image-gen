#!/bin/bash

set -eu

LABEL="$1"
BOOTUUID="$2"
CRYPTUUID="$3"

case $LABEL in
   ROOT)
      # Configure fstab for encrypted root filesystem on LUKS container
      cat << EOF > $IMAGEMOUNTPATH/etc/fstab
# Encrypted root filesystem (Btrfs on LUKS2 on MD RAID1)
/dev/mapper/cryptroot /               btrfs defaults 0 0
EOF

      # Add boot partition to fstab
      cat << EOF >> $IMAGEMOUNTPATH/etc/fstab
UUID=${BOOTUUID} /boot/firmware  vfat defaults,rw,noatime,errors=remount-ro 0 2
EOF

      # Configure crypttab for LUKS
      cat << EOF > $IMAGEMOUNTPATH/etc/crypttab
cryptroot UUID=${CRYPTUUID} none luks,discard
EOF
      ;;
   BOOT)
      # Configure cmdline.txt for encrypted root with MD RAID + LUKS + Btrfs
      # Note: The actual root device will be configured during provisioning
      sed -i "s|root=\([^ ]*\)|cryptdevice=UUID=${CRYPTUUID}:cryptroot root=/dev/mapper/cryptroot rootfstype=btrfs rd.md.conf=1|" $IMAGEMOUNTPATH/cmdline.txt

      # Create LUKS keyfile directory
      mkdir -p $IMAGEMOUNTPATH/boot/firmware

      # Note: initramfs modules are configured by mdadm and post-image hooks
      ;;
   *)
      ;;
esac
