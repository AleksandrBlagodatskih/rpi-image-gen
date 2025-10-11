#!/bin/bash
# =============================================================================
# PRE-IMAGE SCRIPT FOR HYBRID RAID LAYOUT
# =============================================================================
# Настраивает гибридную конфигурацию SD + RAID1 с опциональным LUKS2 шифрованием

set -euo pipefail

# === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ И ФУНКЦИИ ===

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

# UUID validation
validate_uuid() {
    local uuid="$1" name="$2"
    if ! [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        die "Invalid ${name} UUID format: ${uuid}"
    fi
}

# === ВАЛИДАЦИЯ КОНФИГУРАЦИИ ===

validate_configuration() {
    log_info "Validating configuration..."

    # Required parameters
    : "${IGconf_hybrid_raid_luks_ssd_ids:?"ssd_ids not configured"}"

    # Validate encryption_enabled
    case "${IGconf_hybrid_raid_luks_encryption_enabled:-n}" in
        y|n) ;;
        *) die "encryption_enabled must be 'y' or 'n', got: ${IGconf_hybrid_raid_luks_encryption_enabled}" ;;
    esac

    # Validate rootfs_type
    case "${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" in
        ext4|btrfs|f2fs) ;;
        *) die "Unsupported rootfs_type: ${IGconf_hybrid_raid_luks_rootfs_type}. Supported: ext4, btrfs, f2fs" ;;
    esac

    # Validate pmap
    case "${IGconf_hybrid_raid_luks_pmap:-clear}" in
        clear|crypt) ;;
        *) die "pmap must be 'clear' or 'crypt', got: ${IGconf_hybrid_raid_luks_pmap}" ;;
    esac

    # Encryption-specific validation
    if [ "${IGconf_hybrid_raid_luks_encryption_enabled:-n}" = "y" ]; then
        case "${IGconf_hybrid_raid_luks_key_method:-file}" in
            file) ;;
            *) die "Only 'file' key method is supported for security reasons" ;;
        esac

        # Validate key_size
        local key_size="${IGconf_hybrid_raid_luks_key_size:-512}"
        if ! [[ "$key_size" =~ ^[0-9]+$ ]] || (( key_size < 256 || key_size > 8192 )); then
            die "key_size must be integer between 256 and 8192, got: ${key_size}"
        fi
    fi

    log_success "Configuration validation passed"
}

# === ГЕНЕРАЦИЯ UUID ===

generate_uuids() {
    log_info "Generating UUIDs for partitions..."

    # Generate UUIDs for partitions (batch generation for performance)
    mapfile -t uuids < <(uuidgen && uuidgen && uuidgen)
    BOOT_UUID=${uuids[0]}
    ROOT_UUID=${uuids[1]}
    RAID_UUID=${uuids[2]}

    # Validate all UUIDs
    validate_uuid "$BOOT_UUID" "BOOT"
    validate_uuid "$ROOT_UUID" "ROOT"
    validate_uuid "$RAID_UUID" "RAID"

    log_success "Generated and validated UUIDs"
}

# === НАСТРОЙКА ШИФРОВАНИЯ ===

setup_encryption() {
    local encryption_enabled="${IGconf_hybrid_raid_luks_encryption_enabled:-n}"

    if [[ "$encryption_enabled" != "y" ]]; then
        log_info "Encryption disabled, skipping LUKS setup"
        return 0
    fi

    log_info "Setting up LUKS2 encryption configuration..."

    # Generate CRYPT UUID
    CRYPT_UUID=$(uuidgen)
    validate_uuid "$CRYPT_UUID" "CRYPT"

    # Generate LUKS key file
    if ! command -v openssl >/dev/null 2>&1; then
        die "openssl required for LUKS key generation"
    fi

    luks_key_file="${genimg_in}/luks_key.bin"
    if [[ ! -f "$luks_key_file" ]]; then
        openssl rand -out "$luks_key_file" $(( ${IGconf_hybrid_raid_luks_key_size:-512} / 8 ))
        chmod 600 "$luks_key_file"
        log_success "Generated LUKS key file: ${luks_key_file}"
    else
        log_warn "LUKS key file already exists, reusing: ${luks_key_file}"
    fi
}

# === ОБРАБОТКА OVERLAY ШАБЛОНОВ ===

process_overlay_templates() {
    log_info "Processing overlay templates..."

    # Check if overlay files exist before processing
    local overlay_files=(
        "$fs/etc/initramfs-tools/hooks/hybrid-raid"
        "$fs/usr/local/bin/disk-expansion"
        "$fs/etc/systemd/system/disk-expansion.service.d/override.conf"
        "$fs/etc/initramfs-tools/scripts/local-top/rpi-raid"
    )

    for file in "${overlay_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_warn "Overlay file not found: ${file}"
        fi
    done

    # Batch process all SSD template files (suppress errors for missing files)
    sed -i "s|<SSD_IDS>|$IGconf_hybrid_raid_luks_ssd_ids|g" \
        "$fs/etc/initramfs-tools/hooks/hybrid-raid" \
        "$fs/usr/local/bin/disk-expansion" \
        "$fs/etc/systemd/system/disk-expansion.service.d/override.conf" \
        2>/dev/null || true

    # Process RAID template (always required)
    if [[ -f "$fs/etc/initramfs-tools/scripts/local-top/rpi-raid" ]]; then
        sed -i "s|<RAID_UUID>|$RAID_UUID|g" \
            "$fs/etc/initramfs-tools/scripts/local-top/rpi-raid"
        log_success "Processed RAID template"
    else
        die "Required RAID template file not found: $fs/etc/initramfs-tools/scripts/local-top/rpi-raid"
    fi

    # Process LUKS template (encryption-dependent)
    if [[ -n "${CRYPT_UUID:-}" ]]; then
        if [[ -f "$fs/etc/initramfs-tools/scripts/local-top/rpi-luks" ]]; then
            sed -i "s|<CRYPT_UUID>|$CRYPT_UUID|g" \
                "$fs/etc/initramfs-tools/scripts/local-top/rpi-luks"
            log_success "Processed LUKS template"
        else
            die "LUKS template file not found but encryption is enabled: $fs/etc/initramfs-tools/scripts/local-top/rpi-luks"
        fi
    fi
}

# === СОХРАНЕНИЕ КОНФИГУРАЦИИ ===

save_configuration() {
    log_info "Saving configuration for other scripts..."

    # Save essential UUIDs for other scripts
    cat > "${genimg_in}/img_uuids" << EOF
BOOT_UUID=$BOOT_UUID
ROOT_UUID=$ROOT_UUID
${CRYPT_UUID:+CRYPT_UUID=$CRYPT_UUID}
RAID_UUID=$RAID_UUID
ENCRYPTION_ENABLED=$encryption_enabled
EOF

    log_success "Configuration saved to ${genimg_in}/img_uuids"
}

# === ВАЛИДАЦИЯ УСТРОЙСТВ ===

validate_devices() {
    if [[ -z "${IGconf_hybrid_raid_luks_ssd_ids:-}" ]]; then
        log_warn "No SSD device IDs configured"
        return 0
    fi

    log_info "Validating SSD device IDs..."
    local validated_count=0

    IFS=',' read -ra ssd_ids <<< "$IGconf_hybrid_raid_luks_ssd_ids"
    for id in "${ssd_ids[@]}"; do
        local id_path="/dev/disk/by-id/$id"
        if [[ ! -b "$id_path" ]] && [[ ! -L "$id_path" ]]; then
            log_warn "SSD device ID not found during build: ${id} (${id_path})"
            log_warn "This is normal during image build - IDs will be validated at runtime"
        else
            log_success "SSD device ID found: ${id} -> ${id_path}"
            ((validated_count++))
        fi
    done

    if (( validated_count == 0 )); then
        log_warn "No SSD devices found during build - this is expected"
    fi
}

# === ГЕНЕРАЦИЯ GENIMAGE КОНФИГУРАЦИИ ===

generate_genimage_config() {
    log_info "Generating genimage configuration..."

    # Validate template file exists
    if [[ ! -f "genimage.cfg.in" ]]; then
        die "Template file genimage.cfg.in not found"
    fi

    # Validate and set rootfs_type
    local rootfs_type
    case "${IGconf_hybrid_raid_luks_rootfs_type:-ext4}" in
        ext4|btrfs|f2fs)
            rootfs_type="${IGconf_hybrid_raid_luks_rootfs_type:-ext4}"
            ;;
        *)
            die "Unsupported rootfs_type: ${IGconf_hybrid_raid_luks_rootfs_type}"
            ;;
    esac

    # Calculate sizes with overhead considerations
    local root_size="${IGconf_hybrid_raid_luks_root_part_size:-2G}"
    local boot_size="${IGconf_hybrid_raid_luks_boot_part_size:-200M}"
    local raid_partition_size
    local luks_container_size

    # Size calculations with encryption overhead
    if [[ "$encryption_enabled" == "y" ]]; then
        case "$root_size" in
            *G)
                luks_container_size="$(( ${root_size%G} * 1024 + 20 ))M"
                ;;
            *M)
                luks_container_size="$(( ${root_size%M} + 20 ))M"
                ;;
            *)
                die "Unsupported size format: ${root_size}"
                ;;
        esac
        raid_partition_size="$luks_container_size"
        log_info "Calculated LUKS container size: ${luks_container_size}"
    else
        raid_partition_size="$root_size"
    fi

    # Generate sed substitutions
    sed \
        -e "s|<IMAGE_NAME>|\"$IGconf_image_name\"|g" \
        -e "s|<IMAGE_SUFFIX>|\"$IGconf_image_suffix\"|g" \
        -e "s|<BOOT_SIZE>|$boot_size|g" \
        -e "s|<ROOT_SIZE>|$root_size|g" \
        -e "s|<RAID_PARTITION_SIZE>|$raid_partition_size|g" \
        -e "s|<BOOT_UUID>|$BOOT_UUID|g" \
        -e "s|<ROOT_UUID>|$ROOT_UUID|g" \
        -e "s|<RAID_UUID>|$RAID_UUID|g" \
        -e "s|<IGconf_hybrid_raid_luks_rootfs_type>|$rootfs_type|g" \
        -e "s|<ENCRYPTION_ENABLED>|$encryption_enabled|g" \
        -e "s|<LUKS_CONTAINER_SIZE>|${luks_container_size:-}|g" \
        -e "s|<CRYPT_UUID>|${CRYPT_UUID:-}|g" \
        -e "s|<KEY_SIZE>|${IGconf_hybrid_raid_luks_key_size:-512}|g" \
        -e "s|<LUKS_KEY_FILE>|${luks_key_file:-}|g" \
        -e "s|<MKE2FS_CONFIG>|$(readlink -f mke2fs.conf)|g" \
        -e "s|<SETUP>|$(readlink -f setup.sh)|g" \
        "genimage.cfg.in" > "${genimg_in}/genimage.cfg"

    log_success "Generated genimage configuration: ${genimg_in}/genimage.cfg"
}

# === УСТАНОВКА PROVISION MAP ===

install_provision_map() {
    local provisionmap_file="device/provisionmap-${encryption_enabled:+crypt}${encryption_enabled:-clear}.json"

    if [[ -f "$provisionmap_file" ]]; then
        log_info "Installing provision map: ${provisionmap_file}"
        cp "$provisionmap_file" "${IGconf_image_outputdir}/provisionmap.json"

        if [[ "$encryption_enabled" == "y" && -n "${CRYPT_UUID:-}" ]]; then
            sed -i "s|<CRYPT_UUID>|${CRYPT_UUID}|g" "${IGconf_image_outputdir}/provisionmap.json"
            log_success "Updated provision map with CRYPT UUID"
        fi
    else
        log_warn "Provision map file not found: ${provisionmap_file}"
    fi
}

# === ОСНОВНАЯ ФУНКЦИЯ ===

main() {
    # Parse arguments
    local fs="$1"
    local genimg_in="$2"

    # Initialize global variables
    local encryption_enabled="${IGconf_hybrid_raid_luks_encryption_enabled:-n}"

    log_info "Starting pre-image configuration for Hybrid RAID Layout"
    log_info "Encryption: ${encryption_enabled}"
    log_info "Root filesystem: ${IGconf_hybrid_raid_luks_rootfs_type:-ext4}"

    # Execute configuration steps
    validate_configuration
    generate_uuids
    setup_encryption
    process_overlay_templates
    save_configuration
    validate_devices
    generate_genimage_config
    install_provision_map

    log_success "Pre-image configuration completed successfully"
    log_success "Generated genimage configuration for encryption=${encryption_enabled}"
}

# === ЗАПУСК ===

# Validate arguments
if [[ $# -ne 2 ]]; then
    die "Usage: $0 <filesystem_path> <genimage_input_dir>"
fi

# Run main function
main "$@"
