#!/bin/bash

set -eu

LABEL="$1"
BOOTUUID="$2"
CRYPTUUID="$3"

case $LABEL in
   ROOT)
      # Note: fstab is now handled via rootfs-overlay for Btrfs subvolumes
      # The overlay contains optimized mount options for server workloads

      # Configure crypttab for LUKS container (keyfile will be added during provisioning)
      cat << EOF > $IMAGEMOUNTPATH/etc/crypttab
cryptroot UUID=${CRYPTUUID} none luks,discard
EOF

      ;;
   BOOT)
      # Configure cmdline.txt for encrypted root with MD RAID + LUKS + Btrfs subvolume + Docker cgroups
      # Note: The actual root device will be configured during provisioning
      # Keep original root= from genimage and add encryption parameters
      sed -i "s|root=\([^ ]*\)|root=\1 cryptdevice=UUID=${CRYPTUUID}:cryptroot root=/dev/mapper/cryptroot rootfstype=btrfs rootflags=subvol=@ rd.md.conf=1 systemd.unified_cgroup_hierarchy=1 cgroup_no_v1=all|" $IMAGEMOUNTPATH/cmdline.txt

      # Create LUKS keyfile directory
      mkdir -p $IMAGEMOUNTPATH/boot/firmware

      # Docker daemon.json is now handled via rootfs-overlay
      # The overlay will be applied automatically if Docker provider is available
      if igconf has-provider docker ; then
         echo "Docker provider detected, daemon.json will be applied via rootfs-overlay"
      else
         echo "Docker provider not detected, daemon.json overlay will be skipped"
      fi

      # Note: initramfs modules are configured by mdadm and post-image hooks
      ;;
   *)
      ;;
esac
