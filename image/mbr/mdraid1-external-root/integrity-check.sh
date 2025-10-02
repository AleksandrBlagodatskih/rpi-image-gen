#!/bin/bash
#
# Integrity Verification for RAID External Layer
# Performs comprehensive integrity checks on built images and filesystems
#

set -eu

# ============================================================================
# Integrity Check Functions
# ============================================================================

check_file_integrity() {
    local file="$1"
    local expected_hash="${2:-}"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file"
        return 1
    fi

    if [[ -n "$expected_hash" ]]; then
        local actual_hash
        actual_hash=$(sha256sum "$file" | cut -d' ' -f1)

        if [[ "$actual_hash" != "$expected_hash" ]]; then
            echo "ERROR: Hash mismatch for $file"
            echo "  Expected: $expected_hash"
            echo "  Actual:   $actual_hash"
            return 1
        fi
    fi

    echo "File integrity check passed: $file"
    return 0
}

check_filesystem_integrity() {
    local mount_point="$1"
    local device="$2"

    echo "Checking filesystem integrity on $device at $mount_point..."

    # Check if mount point exists and is accessible
    if [[ ! -d "$mount_point" ]]; then
        echo "ERROR: Mount point not accessible: $mount_point"
        return 1
    fi

    # Check filesystem type
    local fs_type
    fs_type=$(df -T "$mount_point" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")

    case "$fs_type" in
        ext4)
            # Check ext4 filesystem
            if ! e2fsck -n "$device" >/dev/null 2>&1; then
                echo "ERROR: ext4 filesystem check failed on $device"
                return 1
            fi
            ;;
        btrfs)
            # Check btrfs filesystem
            if ! btrfs check --readonly "$device" >/dev/null 2>&1; then
                echo "ERROR: btrfs filesystem check failed on $device"
                return 1
            fi
            ;;
        f2fs)
            # Check f2fs filesystem
            if ! fsck.f2fs -a "$device" >/dev/null 2>&1; then
                echo "ERROR: f2fs filesystem check failed on $device"
                return 1
            fi
            ;;
        *)
            echo "Warning: Unsupported filesystem type for integrity check: $fs_type"
            ;;
    esac

    echo "Filesystem integrity check passed: $device ($fs_type)"
    return 0
}

check_raid_integrity() {
    local raid_device="$1"

    echo "Checking RAID array integrity on $raid_device..."

    if [[ ! -e "$raid_device" ]]; then
        echo "ERROR: RAID device not found: $raid_device"
        return 1
    fi

    # Check RAID status
    if ! mdadm --detail "$raid_device" >/dev/null 2>&1; then
        echo "ERROR: RAID array check failed on $raid_device"
        return 1
    fi

    # Check for degraded arrays
    local raid_status
    raid_status=$(cat /proc/mdstat 2>/dev/null | grep -A 10 "$(basename "$raid_device")" | head -1 || echo "")

    if [[ "$raid_status" == *"_ "* ]]; then
        echo "ERROR: RAID array is degraded: $raid_device"
        return 1
    fi

    echo "RAID integrity check passed: $raid_device"
    return 0
}

check_encryption_integrity() {
    local encrypted_device="$1"

    echo "Checking encryption integrity on $encrypted_device..."

    if [[ ! -e "$encrypted_device" ]]; then
        echo "ERROR: Encrypted device not found: $encrypted_device"
        return 1
    fi

    # Check LUKS header
    if ! cryptsetup luksDump "$encrypted_device" >/dev/null 2>&1; then
        echo "ERROR: LUKS header check failed on $encrypted_device"
        return 1
    fi

    # Check if encryption key is available
    if [[ -n "$IGconf_mdraid1_external_root_key_file" ]] && [[ -f "$IGconf_mdraid1_external_root_key_file" ]]; then
        if ! cryptsetup luksOpen --test-passphrase "$encrypted_device" --key-file "$IGconf_mdraid1_external_root_key_file" >/dev/null 2>&1; then
            echo "ERROR: Encryption key test failed on $encrypted_device"
            return 1
        fi
    fi

    echo "Encryption integrity check passed: $encrypted_device"
    return 0
}

verify_image_integrity() {
    local image_file="$1"
    local manifest_file="$2"

    echo "Verifying image integrity: $image_file"

    # Check if image file exists
    if [[ ! -f "$image_file" ]]; then
        echo "ERROR: Image file not found: $image_file"
        return 1
    fi

    # Check if manifest exists
    if [[ ! -f "$manifest_file" ]]; then
        echo "ERROR: Manifest file not found: $manifest_file"
        return 1
    fi

    # Verify image size matches manifest
    local image_size
    local manifest_size
    image_size=$(stat -c %s "$image_file" 2>/dev/null || echo "0")
    manifest_size=$(grep -o '"size":[0-9]*' "$manifest_file" | grep -o '[0-9]*' || echo "0")

    if [[ "$image_size" != "$manifest_size" ]]; then
        echo "ERROR: Image size mismatch"
        echo "  File: $image_size bytes"
        echo "  Manifest: $manifest_size bytes"
        return 1
    fi

    # Verify checksums if available in manifest
    if command -v sha256sum >/dev/null 2>&1; then
        local manifest_checksum
        manifest_checksum=$(grep -o '"sha256":"[^"]*"' "$manifest_file" | grep -o '[a-f0-9]*' || echo "")

        if [[ -n "$manifest_checksum" ]]; then
            local actual_checksum
            actual_checksum=$(sha256sum "$image_file" | cut -d' ' -f1)

            if [[ "$actual_checksum" != "$manifest_checksum" ]]; then
                echo "ERROR: Checksum mismatch for $image_file"
                echo "  Expected: $manifest_checksum"
                echo "  Actual:   $actual_checksum"
                return 1
            fi
        fi
    fi

    echo "Image integrity verification passed: $image_file"
    return 0
}

# ============================================================================
# Main Integrity Verification Function
# ============================================================================

perform_integrity_checks() {
    local image_dir="$1"
    local mount_points=("${@:2}")

    echo "Performing comprehensive integrity checks..."

    local all_checks_passed=true

    # Check image files
    echo "Checking image files..."
    for image_file in "$image_dir"/*.img "$image_dir"/*.img.sparse; do
        [[ -f "$image_file" ]] || continue

        local manifest_file="$image_dir/deployed.json"

        if ! verify_image_integrity "$image_file" "$manifest_file"; then
            all_checks_passed=false
        fi
    done

    # Check mounted filesystems
    echo "Checking mounted filesystems..."
    for mount_point in "${mount_points[@]}"; do
        if [[ -d "$mount_point" ]]; then
            local device
            device=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null || echo "")

            if [[ -n "$device" ]]; then
                # Check filesystem integrity
                if ! check_filesystem_integrity "$mount_point" "$device"; then
                    all_checks_passed=false
                fi

                # Check RAID integrity if applicable
                if [[ "$device" == /dev/md* ]]; then
                    if ! check_raid_integrity "$device"; then
                        all_checks_passed=false
                    fi
                fi

                # Check encryption integrity if applicable
                if [[ "$device" == /dev/mapper/* ]]; then
                    local underlying_device="${device#/dev/mapper/}"
                    if [[ -e "/dev/mapper/$underlying_device" ]]; then
                        if ! check_encryption_integrity "/dev/mapper/$underlying_device"; then
                            all_checks_passed=false
                        fi
                    fi
                fi
            fi
        fi
    done

    if [[ "$all_checks_passed" == "true" ]]; then
        echo "All integrity checks passed successfully"
        return 0
    else
        echo "Some integrity checks failed"
        return 1
    fi
}

# ============================================================================
# Export function for use by other scripts
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <image_dir> [mount_point1] [mount_point2] ..."
        exit 1
    fi

    perform_integrity_checks "$@"
fi
