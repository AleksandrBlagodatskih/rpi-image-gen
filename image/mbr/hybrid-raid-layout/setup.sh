#!/bin/bash
# Setup script for Hybrid RAID Layout

set -euo pipefail

# Parse arguments
partition_type="$1"
boot_uuid="$2"
root_uuid="$3"
crypt_uuid="$4"
raid_uuid="$5"

# Load configuration
genimg_in="${genimg_in:-}"
if [[ -n "$genimg_in" && -d "$genimg_in" && -f "${genimg_in}/img_uuids" ]]; then
    source "${genimg_in}/img_uuids"
fi
encryption_enabled="${ENCRYPTION_ENABLED:-n}"

# Validate IMAGEMOUNTPATH
if [[ ! -d "${IMAGEMOUNTPATH:-}" ]]; then
    echo "Error: IMAGEMOUNTPATH not set or not a directory" >&2
    exit 1
fi

case "$partition_type" in
    ROOT)
        # Setup fstab
        rootfs_type="${IGconf_hybrid_raid_luks_rootfs_type:-ext4}"
        case "$rootfs_type" in
            ext4) opts="defaults,noatime,errors=remount-ro" ;;
            btrfs) opts="defaults,noatime,compress=zstd" ;;
            f2fs) opts="defaults,noatime" ;;
            *) echo "Error: Unsupported rootfs_type: $rootfs_type" >&2; exit 1 ;;
        esac

        # Use UUID of LUKS container for encrypted root (requires systemd that can open LUKS by UUID)
        root_entry=$([[ "$encryption_enabled" == "y" ]] && echo "UUID=$crypt_uuid / $rootfs_type $opts 0 1" || echo "UUID=$raid_uuid / $rootfs_type $opts 0 1")

        cat > "$IMAGEMOUNTPATH/etc/fstab" << EOF
UUID=$boot_uuid /boot/firmware vfat defaults 0 2
$root_entry
EOF

        # Setup mdadm.conf for non-encrypted
        [[ "$encryption_enabled" != "y" ]] && cat > "$IMAGEMOUNTPATH/etc/mdadm/mdadm.conf" << EOF
DEVICE partitions
CREATE owner=root group=disk mode=0660 auto=yes
HOMEHOST <system>
MAILADDR root
ARRAY /dev/md0 level=raid1 num-devices=2 UUID=$raid_uuid
EOF
        ;;

    BOOT)
        # Update cmdline.txt
        cmdline_file="$IMAGEMOUNTPATH/cmdline.txt"

        if [[ "$encryption_enabled" == "y" ]]; then
            # Use UUID of the LUKS container for root (requires initrd that can open LUKS by UUID)
            sed -i "s|root=[^[:space:]]*|root=UUID=$crypt_uuid|" "$cmdline_file"
            grep -q "cryptdevice" "$cmdline_file" || sed -i "s|root=UUID=$crypt_uuid|root=UUID=$crypt_uuid cryptdevice=UUID=$raid_uuid:cryptroot|" "$cmdline_file"
        else
            sed -i "s|root=[^[:space:]]*|root=UUID=$raid_uuid|" "$cmdline_file"
        fi

        grep -q "initrd" "$cmdline_file" || sed -i 's|$| initrd=initrd.img|' "$cmdline_file"
        grep -q "rootdelay" "$cmdline_file" || sed -i 's|initrd=initrd\.img|initrd=initrd.img rootdelay=5|' "$cmdline_file"
        ;;
    *)
        echo "Error: Invalid partition type: $partition_type. Must be ROOT or BOOT" >&2
        exit 1
        ;;
esac
