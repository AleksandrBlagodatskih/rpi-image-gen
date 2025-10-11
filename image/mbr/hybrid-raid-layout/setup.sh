#!/bin/bash
set -euo pipefail

# Function for error handling
die() { echo "ERROR: $*" >&2; exit 1; }

# Parameter expansion validation + assignment
: "${1:?"LABEL parameter required"}" && LABEL="$1"
: "${2:?"BOOTUUID parameter required"}" && BOOTUUID="$2"
: "${3:?"ROOTUUID parameter required"}" && ROOTUUID="$3"
: "${4:?"CRYPTUUID parameter required"}" && CRYPTUUID="$4"
: "${5:?"RAIDUUID parameter required"}" && RAIDUUID="$5"

BOOT_UUID="$BOOTUUID"
ROOT_UUID="$ROOTUUID"
RAID_UUID="$RAIDUUID"

# Load encryption settings - compact command chaining
[[ -f "${genimg_in:-}/img_uuids" ]] && source "${genimg_in}/img_uuids"
encryption_enabled="${ENCRYPTION_ENABLED:-n}"

case "$LABEL" in
   ROOT)
      # Inline case with filesystem type validation + conditional root entry
      case "${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" in
         ext4|btrfs|f2fs)
            rootfs_type="${IGconf_hybrid_raid_luks_rootfs_type:-ext4}"
            root_entry="${encryption_enabled:+/dev/mapper/cryptroot}${encryption_enabled:-UUID=$RAID_UUID} / $rootfs_type ${rootfs_type:+defaults,noatime}${rootfs_type:+,errors=remount-ro}${rootfs_type:+,compress=zstd} 0 1"
            ;;
         *) die "Unsupported filesystem type: $IGconf_hybrid_raid_luks_rootfs_type" ;;
      esac

      # Single conditional heredoc for fstab - compact
      cat > "$IMAGEMOUNTPATH/etc/fstab" << EOF
UUID=$BOOT_UUID /boot/firmware vfat defaults 0 2
$root_entry
EOF

      # RAID config - conditional command chaining
      [[ "$encryption_enabled" != "y" ]] && cat > "$IMAGEMOUNTPATH/etc/mdadm/mdadm.conf" << EOF
DEVICE partitions
CREATE owner=root group=disk mode=0660 auto=yes
HOMEHOST <system>
MAILADDR root

ARRAY /dev/md0 level=raid1 num-devices=2 UUID=$RAID_UUID
EOF

      # Note: initramfs-tools configuration and service setup is handled by extension layer via overlay files
      ;;
   BOOT)
      # Update cmdline.txt - direct inline editing without temp files
      cmdline_file="$IMAGEMOUNTPATH/cmdline.txt"

      [[ "$encryption_enabled" == "y" ]] && {
         # Encrypted: root=/dev/mapper/cryptroot + cryptdevice
         grep -q "root=" "$cmdline_file" && sed -i 's|root=[^[:space:]]*|root=/dev/mapper/cryptroot|g' "$cmdline_file"
         ! grep -q "cryptdevice" "$cmdline_file" && sed -i "s|root=/dev/mapper/cryptroot|root=/dev/mapper/cryptroot cryptdevice=UUID=$RAID_UUID:cryptroot|g" "$cmdline_file"
      } || {
         # Plain RAID: root=UUID=$RAID_UUID
         grep -q "root=" "$cmdline_file" && sed -i "s|root=[^[:space:]]*|root=UUID=$RAID_UUID|g" "$cmdline_file"
      }

      # Add initrd - direct sed
      ! grep -q "initrd" "$cmdline_file" && sed -i 's|$| initrd=initrd.img|' "$cmdline_file"

      # Add rootdelay - direct sed
      ! grep -q "rootdelay" "$cmdline_file" && sed -i 's|initrd=initrd\.img|initrd=initrd.img rootdelay=5|g' "$cmdline_file"
      ;;
   *)
      ;;
esac
