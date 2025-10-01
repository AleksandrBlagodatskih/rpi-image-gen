#!/bin/bash
#
# Secure Key Management for RAID External Layer
# Handles encryption key generation, storage, and provisioning
#

set -eu

# ============================================================================
# Key Generation and Management Functions
# ============================================================================

generate_random_key() {
    local key_size="$1"
    local key_file="$2"

    echo "Generating random $key_size-bit encryption key..."

    case "$key_size" in
        256)
            openssl rand -hex 32 > "$key_file"
            ;;
        512)
            openssl rand -hex 64 > "$key_file"
            ;;
        1024)
            openssl rand -hex 128 > "$key_file"
            ;;
        *)
            echo "ERROR: Unsupported key size: $key_size"
            exit 1
            ;;
    esac

    chmod 600 "$key_file"
    echo "Key generated and saved to: $key_file"
}

read_key_from_file() {
    local key_file="$1"

    if [[ ! -f "$key_file" ]]; then
        echo "ERROR: Key file not found: $key_file"
        exit 1
    fi

    if [[ ! -r "$key_file" ]]; then
        echo "ERROR: Cannot read key file: $key_file"
        exit 1
    fi

    cat "$key_file"
}

read_key_from_env() {
    local env_var="$1"

    if [[ -z "${!env_var:-}" ]]; then
        echo "ERROR: Environment variable $env_var is not set"
        exit 1
    fi

    echo "${!env_var}"
}

validate_key_strength() {
    local key="$1"
    local key_size="$2"

    # Basic validation - key should not be empty and have minimum entropy
    if [[ -z "$key" ]]; then
        echo "ERROR: Empty key provided"
        exit 1
    fi

    # Check key length based on expected size
    local expected_bytes
    case "$key_size" in
        256) expected_bytes=64 ;;  # 32 bytes hex = 64 chars
        512) expected_bytes=128 ;; # 64 bytes hex = 128 chars
        1024) expected_bytes=256 ;; # 128 bytes hex = 256 chars
        *) echo "ERROR: Invalid key size for validation: $key_size"; exit 1 ;;
    esac

    if [[ ${#key} -ne "$expected_bytes" ]]; then
        echo "ERROR: Key length mismatch. Expected $expected_bytes chars, got ${#key}"
        exit 1
    fi

    # Check for sufficient entropy (not all same characters)
    if [[ "$key" == "$(printf '%*s' "${#key}" | tr ' ' "${key:0:1}")" ]]; then
        echo "ERROR: Key appears to have insufficient entropy"
        exit 1
    fi

    echo "Key validation passed"
}

setup_key_in_boot() {
    local key="$1"
    local boot_mount="$2"
    local key_filename="${3:-luks-key}"

    local key_path="$boot_mount/$key_filename"

    echo "Setting up encryption key in boot partition..."

    # Create key file with proper permissions
    echo -n "$key" > "$key_path"
    chmod 600 "$key_path"

    # Update initramfs configuration to include key
    if [[ -d "$boot_mount/etc/initramfs-tools" ]]; then
        cat >> "$boot_mount/etc/initramfs-tools/conf.d/luks-key" << EOF
# LUKS key configuration for RAID external
LUKS_KEY_PATH=/boot/$key_filename
LUKS_KEY_SIZE=${#key}
EOF
    fi

    echo "Encryption key configured at: $key_path"
}

# ============================================================================
# Main Key Management Function
# ============================================================================

manage_encryption_key() {
    local key_method="$IGconf_raid_external_key_method"
    local key_size="$IGconf_raid_external_key_size"
    local boot_mount="$1"

    echo "Managing encryption key using method: $key_method"

    local encryption_key=""

    case "$key_method" in
        random)
            local temp_key_file="/tmp/luks-key-$$"
            generate_random_key "$key_size" "$temp_key_file"
            encryption_key=$(cat "$temp_key_file")
            rm -f "$temp_key_file"
            ;;
        file)
            if [[ -z "$IGconf_raid_external_key_file" ]]; then
                echo "ERROR: Key file not specified for method=file"
                exit 1
            fi
            encryption_key=$(read_key_from_file "$IGconf_raid_external_key_file")
            ;;
        env)
            if [[ -z "$IGconf_raid_external_key_env" ]]; then
                echo "ERROR: Environment variable not specified for method=env"
                exit 1
            fi
            encryption_key=$(read_key_from_env "$IGconf_raid_external_key_env")
            ;;
        tpm)
            echo "TPM key storage not yet implemented"
            exit 1
            ;;
        *)
            echo "ERROR: Unknown key method: $key_method"
            exit 1
            ;;
    esac

    # Validate the key
    validate_key_strength "$encryption_key" "$key_size"

    # Set up key in boot partition
    setup_key_in_boot "$encryption_key" "$boot_mount"

    # Return the key for use in provisioning
    echo "$encryption_key"
}

# ============================================================================
# Export function for use by other scripts
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <boot_mount_point>"
        exit 1
    fi

    manage_encryption_key "$1"
fi
