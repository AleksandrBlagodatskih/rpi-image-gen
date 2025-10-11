#!/bin/bash
set -euo pipefail

# Function for error handling
die() {
    echo "ERROR: $*" >&2
    exit 1
}

LABEL="$1"
BOOTUUID="$2"
ROOTUUID="$3"

BOOT_UUID="$BOOTUUID"
ROOT_UUID="$ROOTUUID"
CRYPT_UUID="${CRYPT_UUID:-$ROOT_UUID}"

case "$LABEL" in
   ROOT)

      case "${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" in
         ext4)
            cat << EOF > "$IMAGEMOUNTPATH/etc/fstab"
UUID=$BOOT_UUID /boot/firmware vfat defaults 0 2
UUID=$CRYPT_UUID / ext4 rw,relatime 0 1
EOF
            ;;
         btrfs)
            cat << EOF > "$IMAGEMOUNTPATH/etc/fstab"
UUID=$BOOT_UUID /boot/firmware vfat defaults 0 2
UUID=$CRYPT_UUID / btrfs rw,relatime,compress=zstd 0 0
EOF
            ;;
         f2fs)
            cat << EOF > "$IMAGEMOUNTPATH/etc/fstab"
UUID=$BOOT_UUID /boot/firmware vfat defaults 0 2
UUID=$CRYPT_UUID / f2fs rw,relatime,compress_algorithm=zstd 0 0
EOF
            ;;
         *)
            echo "Unsupported filesystem type: \"$IGconf_hybrid_raid_luks_rootfs_type\"" >&2
            exit 1
            ;;
      esac

      [ "${IGconf_hybrid_raid_luks_encryption_enabled:-n}" = "y" ] && cat << EOF > "$IMAGEMOUNTPATH/etc/crypttab"
UUID=$CRYPT_UUID /usr/bin/rpi-raid luks,discard
EOF

      cat << EOF > "$IMAGEMOUNTPATH/etc/mdadm/mdadm.conf"
DEVICE partitions
CREATE owner=root group=disk mode=0660 auto=yes
HOMEHOST <system>
MAILADDR root

ARRAY /dev/md0 level=raid1 num-devices=2 UUID=$ROOTUUID
EOF

      # Note: LUKS key permissions are handled by extension layer via overlay files

      # Note: initramfs-tools configuration and service setup is handled by extension layer via overlay files
      ;;
   BOOT)
      # Safely update root parameter using awk for better control
      awk -v crypt_uuid="$CRYPT_UUID" '
      {
          # Replace any root= parameter with UUID-based root
          if ($0 ~ /root=/) {
              sub(/root=[^[:space:]]*/, "root=UUID=" crypt_uuid)
          }
          print $0
      }
      ' "$IMAGEMOUNTPATH/cmdline.txt" > "$IMAGEMOUNTPATH/cmdline.txt.tmp" && \
      mv "$IMAGEMOUNTPATH/cmdline.txt.tmp" "$IMAGEMOUNTPATH/cmdline.txt" || \
      die "Failed to update cmdline.txt root parameter"

      [ "${IGconf_hybrid_raid_luks_encryption_enabled:-n}" = "y" ] && {
         # Safely add initrd parameter if not present
         if ! grep -q "initrd" "$IMAGEMOUNTPATH/cmdline.txt"; then
            # Use awk for safer string manipulation
            awk '
            {
                # Add initrd.img to the end of the line if not present
                if ($0 !~ /initrd/) {
                    print $0 " initrd=initrd.img"
                } else {
                    print $0
                }
            }
            ' "$IMAGEMOUNTPATH/cmdline.txt" > "$IMAGEMOUNTPATH/cmdline.txt.tmp" && \
            mv "$IMAGEMOUNTPATH/cmdline.txt.tmp" "$IMAGEMOUNTPATH/cmdline.txt" || \
            die "Failed to add initrd to cmdline.txt"
         fi

         # Safely add rootdelay parameter if not present
         if ! grep -q "rootdelay" "$IMAGEMOUNTPATH/cmdline.txt"; then
            # Use awk for safer replacement
            awk '
            {
                # Replace "initrd=initrd.img" with "initrd=initrd.img rootdelay=5"
                if ($0 ~ /initrd=initrd\.img/ && $0 !~ /rootdelay/) {
                    sub(/initrd=initrd\.img/, "initrd=initrd.img rootdelay=5")
                }
                print $0
            }
            ' "$IMAGEMOUNTPATH/cmdline.txt" > "$IMAGEMOUNTPATH/cmdline.txt.tmp" && \
            mv "$IMAGEMOUNTPATH/cmdline.txt.tmp" "$IMAGEMOUNTPATH/cmdline.txt" || \
            die "Failed to add rootdelay to cmdline.txt"
         fi
      }
      ;;
   *)
      ;;
esac
