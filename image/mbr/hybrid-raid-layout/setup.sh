#!/bin/bash
# =============================================================================
# SETUP SCRIPT FOR HYBRID RAID LAYOUT
# =============================================================================
# Настраивает разделы и конфигурации для гибридной SD + RAID1 системы

set -euo pipefail

# === ГЛОБАЛЬНЫЕ ФУНКЦИИ И ПЕРЕМЕННЫЕ ===

# Enhanced error handling with context
die() {
    echo "ERROR: $*" >&2
    echo "ERROR: Script failed at line ${BASH_LINENO[0]}" >&2
    exit 1
}

# Logging functions
log_info() { echo "ℹ️  $*" >&2; }
log_warn() { echo "⚠️  $*" >&2; }
log_success() { echo "✅ $*" >&2; }
log_error() { echo "❌ $*" >&2; }

# === ВАЛИДАЦИЯ ПАРАМЕТРОВ ===

validate_parameters() {
    log_info "Validating setup parameters..."

    # Required parameters validation with detailed error messages
    if [[ -z "${1:-}" ]]; then
        die "LABEL parameter is required (first argument)"
    fi

    if [[ -z "${2:-}" ]]; then
        die "BOOTUUID parameter is required (second argument)"
    fi

    if [[ -z "${3:-}" ]]; then
        die "ROOTUUID parameter is required (third argument)"
    fi

    if [[ -z "${4:-}" ]]; then
        die "CRYPTUUID parameter is required (fourth argument)"
    fi

    if [[ -z "${5:-}" ]]; then
        die "RAIDUUID parameter is required (fifth argument)"
    fi

    # Validate LABEL parameter
    case "$1" in
        BOOT|ROOT)
            ;;
        *)
            die "Invalid LABEL parameter: '$1'. Must be 'BOOT' or 'ROOT'"
            ;;
    esac

    log_success "Parameters validated successfully"
}

# === ЗАГРУЗКА КОНФИГУРАЦИИ ===

load_configuration() {
    log_info "Loading configuration..."

    # Load UUIDs and encryption settings from saved configuration
    if [[ -f "${genimg_in:-}/img_uuids" ]]; then
        source "${genimg_in}/img_uuids"
        log_success "Configuration loaded from ${genimg_in}/img_uuids"
    else
        log_warn "Configuration file not found: ${genimg_in:-}/img_uuids"
        ENCRYPTION_ENABLED="${ENCRYPTION_ENABLED:-n}"
    fi

    # Set encryption flag
    encryption_enabled="${ENCRYPTION_ENABLED:-n}"

    log_info "Encryption enabled: ${encryption_enabled}"
}

# === НАСТРОЙКА ROOT РАЗДЕЛА ===

setup_root_partition() {
    local label="$1"
    local boot_uuid="$2"
    local root_uuid="$3"
    local crypt_uuid="$4"
    local raid_uuid="$5"

    log_info "Setting up ROOT partition configuration..."

    # Validate filesystem type
    local rootfs_type
    case "${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" in
        ext4)
            rootfs_type="ext4"
            ;;
        btrfs)
            rootfs_type="btrfs"
            ;;
        f2fs)
            rootfs_type="f2fs"
            ;;
        *)
            die "Unsupported filesystem type: ${IGconf_hybrid_raid_luks_rootfs_type}"
            ;;
    esac

    # Generate root filesystem entry based on encryption
    local root_entry
    local mount_options

    case "$rootfs_type" in
        ext4)
            mount_options="defaults,noatime,errors=remount-ro"
            ;;
        btrfs)
            mount_options="defaults,noatime,compress=zstd"
            ;;
        f2fs)
            mount_options="defaults,noatime"
            ;;
    esac

    if [[ "$encryption_enabled" == "y" ]]; then
        root_entry="/dev/mapper/cryptroot / $rootfs_type $mount_options 0 1"
    else
        root_entry="UUID=$raid_uuid / $rootfs_type $mount_options 0 1"
    fi

    # Create /etc/fstab
    local fstab_file="$IMAGEMOUNTPATH/etc/fstab"
    log_info "Creating fstab: $fstab_file"

    cat > "$fstab_file" << EOF
# /etc/fstab - Hybrid RAID Layout
# Boot partition
UUID=$boot_uuid /boot/firmware vfat defaults 0 2

# Root partition
$root_entry
EOF

    log_success "fstab created with $rootfs_type filesystem"

    # Configure mdadm for non-encrypted setups
    if [[ "$encryption_enabled" != "y" ]]; then
        local mdadm_conf="$IMAGEMOUNTPATH/etc/mdadm/mdadm.conf"
        log_info "Creating mdadm configuration: $mdadm_conf"

        cat > "$mdadm_conf" << EOF
# /etc/mdadm/mdadm.conf - Hybrid RAID Layout
DEVICE partitions
CREATE owner=root group=disk mode=0660 auto=yes
HOMEHOST <system>
MAILADDR root

ARRAY /dev/md0 level=raid1 num-devices=2 UUID=$raid_uuid
EOF

        log_success "mdadm configuration created for RAID1"
    else
        log_info "Skipping mdadm configuration (encryption enabled)"
    fi
}

# === НАСТРОЙКА BOOT РАЗДЕЛА ===

setup_boot_partition() {
    local raid_uuid="$5"

    log_info "Setting up BOOT partition configuration..."

    local cmdline_file="$IMAGEMOUNTPATH/cmdline.txt"

    if [[ ! -f "$cmdline_file" ]]; then
        die "cmdline.txt file not found: $cmdline_file"
    fi

    log_info "Updating cmdline.txt: $cmdline_file"

    # Configure root parameter based on encryption
    if [[ "$encryption_enabled" == "y" ]]; then
        # Encrypted: root=/dev/mapper/cryptroot + cryptdevice
        if grep -q "root=" "$cmdline_file"; then
            sed -i 's|root=[^[:space:]]*|root=/dev/mapper/cryptroot|g' "$cmdline_file"
        fi

        if ! grep -q "cryptdevice" "$cmdline_file"; then
            sed -i "s|root=/dev/mapper/cryptroot|root=/dev/mapper/cryptroot cryptdevice=UUID=$raid_uuid:cryptroot|g" "$cmdline_file"
        fi

        log_success "Configured encrypted boot parameters"
    else
        # Plain RAID: root=UUID=$RAID_UUID
        if grep -q "root=" "$cmdline_file"; then
            sed -i "s|root=[^[:space:]]*|root=UUID=$raid_uuid|g" "$cmdline_file"
        fi

        log_success "Configured plain RAID boot parameters"
    fi

    # Add initrd parameter if not present
    if ! grep -q "initrd" "$cmdline_file"; then
        sed -i 's|$| initrd=initrd.img|' "$cmdline_file"
        log_success "Added initrd parameter"
    fi

    # Add rootdelay for stable device detection
    if ! grep -q "rootdelay" "$cmdline_file"; then
        sed -i 's|initrd=initrd\.img|initrd=initrd.img rootdelay=5|g' "$cmdline_file"
        log_success "Added rootdelay=5 for stable device detection"
    fi

    log_info "Boot partition configuration completed"
}

# === ОСНОВНАЯ ФУНКЦИЯ ===

main() {
    # Validate arguments count
    if [[ $# -ne 5 ]]; then
        die "Usage: $0 <LABEL> <BOOTUUID> <ROOTUUID> <CRYPTUUID> <RAIDUUID>"
    fi

    # Parse arguments
    local label="$1"
    local boot_uuid="$2"
    local root_uuid="$3"
    local crypt_uuid="$4"
    local raid_uuid="$5"

    log_info "Starting setup script for Hybrid RAID Layout"
    log_info "Partition label: $label"

    # Execute setup steps
    validate_parameters "$@"
    load_configuration

    # Process partition-specific setup
    case "$label" in
        ROOT)
            setup_root_partition "$label" "$boot_uuid" "$root_uuid" "$crypt_uuid" "$raid_uuid"
            ;;
        BOOT)
            setup_boot_partition "$label" "$boot_uuid" "$root_uuid" "$crypt_uuid" "$raid_uuid"
            ;;
        *)
            die "Unsupported partition label: $label"
            ;;
    esac

    log_success "Setup completed successfully for $label partition"
}

# === ЗАПУСК ===

main "$@"
