#!/bin/bash
#
# Apply security and RAID layers to official Raspberry Pi OS Trixie image
# This script downloads the base image and applies configured layers
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_IMAGE_URL="${BASE_IMAGE_URL:-https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz}"
BASE_IMAGE_SHA256_URL="${BASE_IMAGE_SHA256_URL:-}"
BASE_IMAGE_SHA256="${BASE_IMAGE_SHA256:-}"
CACHE_DIR="${CACHE_DIR:-./cache}"
WORK_DIR="${WORK_DIR:-./work}"

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# Download SHA256 Checksum
# ============================================================================

download_sha256() {
    local url="$1"
    local output_dir="$2"
    
    if [[ -z "$url" ]]; then
        return 0
    fi
    
    echo_info "Downloading SHA256 checksum..."
    echo_info "URL: $url"
    
    mkdir -p "$output_dir"
    
    local filename=$(basename "$url")
    local output_file="$output_dir/$filename"
    
    if [[ -f "$output_file" ]]; then
        echo_info "SHA256 file already exists: $output_file"
        cat "$output_file"
        return 0
    fi
    
    # Download with curl or wget
    if command -v curl &> /dev/null; then
        curl -L -s -o "$output_file" "$url"
    elif command -v wget &> /dev/null; then
        wget -q -O "$output_file" "$url"
    else
        echo_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    echo_info "SHA256 file downloaded: $output_file"
    cat "$output_file"
}

# ============================================================================
# Extract SHA256 from file
# ============================================================================

extract_sha256_from_file() {
    local sha256_file="$1"
    local image_filename="$2"
    
    if [[ ! -f "$sha256_file" ]]; then
        return 1
    fi
    
    # Try different SHA256 file formats:
    # 1. Single line with just checksum
    # 2. checksum filename
    # 3. filename: checksum
    # 4. Multiple lines with checksums
    
    local checksum=""
    
    # If file contains only hex characters and is 64 chars (SHA256 length)
    if grep -qE '^[a-fA-F0-9]{64}$' "$sha256_file"; then
        checksum=$(cat "$sha256_file")
    # Format: checksum filename
    elif grep -qE '^[a-fA-F0-9]{64}[[:space:]]' "$sha256_file"; then
        if [[ -n "$image_filename" ]]; then
            checksum=$(grep "$image_filename" "$sha256_file" | awk '{print $1}')
        fi
        # If no filename match, take first line
        if [[ -z "$checksum" ]]; then
            checksum=$(head -1 "$sha256_file" | awk '{print $1}')
        fi
    # Format: filename: checksum or filename = checksum
    elif grep -qE '[[:space:]]*[:=][[:space:]]*[a-fA-F0-9]{64}' "$sha256_file"; then
        checksum=$(grep -oE '[a-fA-F0-9]{64}' "$sha256_file" | head -1)
    fi
    
    echo "$checksum"
}

# ============================================================================
# Download Base Image
# ============================================================================

download_base_image() {
    local url="$1"
    local output_dir="$2"
    
    echo_info "Downloading base image..."
    echo_info "URL: $url"
    
    mkdir -p "$output_dir"
    
    local filename=$(basename "$url")
    local output_file="$output_dir/$filename"
    
    if [[ -f "$output_file" ]]; then
        echo_info "Base image already exists: $output_file"
        return 0
    fi
    
    # Download with curl or wget
    if command -v curl &> /dev/null; then
        curl -L -o "$output_file" "$url" --progress-bar
    elif command -v wget &> /dev/null; then
        wget -O "$output_file" "$url"
    else
        echo_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    echo_info "Download completed: $output_file"
}

# ============================================================================
# Extract Image
# ============================================================================

extract_image() {
    local compressed_file="$1"
    local output_dir="$2"
    
    echo_info "Extracting image..."
    
    local filename=$(basename "$compressed_file")
    local extracted_file="${filename%.xz}"
    local output_file="$output_dir/$extracted_file"
    
    if [[ -f "$output_file" ]]; then
        echo_info "Image already extracted: $output_file"
        echo "$output_file"
        return 0
    fi
    
    case "$compressed_file" in
        *.xz)
            xz -d -k -c "$compressed_file" > "$output_file"
            ;;
        *.gz)
            gunzip -c "$compressed_file" > "$output_file"
            ;;
        *.zip)
            unzip -p "$compressed_file" > "$output_file"
            ;;
        *)
            echo_error "Unsupported compression format: $compressed_file"
            exit 1
            ;;
    esac
    
    echo_info "Extraction completed: $output_file"
    echo "$output_file"
}

# ============================================================================
# Verify Image
# ============================================================================

verify_image() {
    local image_file="$1"
    local checksum="${2:-}"
    local sha256_url="${3:-}"
    local sha256_file_path="${4:-}"
    
    echo_info "Verifying image integrity..."
    
    if [[ ! -f "$image_file" ]]; then
        echo_error "Image file not found: $image_file"
        exit 1
    fi
    
    # Basic file check
    local file_type=$(file "$image_file" 2>/dev/null || echo "unknown")
    if [[ ! "$file_type" =~ "DOS/MBR boot sector" ]] && [[ ! "$file_type" =~ "compress" ]]; then
        echo_warn "Image may not be a valid disk image: $file_type"
    fi
    
    # Check size
    local size=$(stat -c%s "$image_file" 2>/dev/null || stat -f%z "$image_file" 2>/dev/null)
    local size_mb=$((size / 1024 / 1024))
    echo_info "Image size: ${size_mb} MB"
    
    # Determine checksum to use
    local expected_checksum="$checksum"
    
    # If checksum not provided but SHA256 URL is available, download it
    if [[ -z "$expected_checksum" ]] && [[ -n "$sha256_url" ]]; then
        echo_info "Downloading SHA256 checksum from URL..."
        local sha256_content=$(download_sha256 "$sha256_url" "$CACHE_DIR")
        local image_filename=$(basename "$image_file")
        expected_checksum=$(extract_sha256_from_file "$sha256_file_path" "$image_filename")
        
        if [[ -n "$expected_checksum" ]]; then
            echo_info "SHA256 extracted from downloaded file: ${expected_checksum:0:16}..."
        fi
    fi
    
    # Verify checksum if available
    if [[ -n "$expected_checksum" ]]; then
        echo_info "Verifying SHA256 checksum..."
        echo_info "Expected: $expected_checksum"
        
        local actual_checksum=$(sha256sum "$image_file" | cut -d' ' -f1)
        echo_info "Actual:   $actual_checksum"
        
        if [[ "$actual_checksum" != "$expected_checksum" ]]; then
            echo_error "SHA256 checksum mismatch!"
            echo_error "  Expected: $expected_checksum"
            echo_error "  Actual:   $actual_checksum"
            echo_error ""
            echo_error "This could indicate:"
            echo_error "  - Download was corrupted"
            echo_error "  - File was modified"
            echo_error "  - Wrong checksum provided"
            exit 1
        fi
        echo_info "✓ SHA256 checksum verified: OK"
    else
        echo_warn "No SHA256 checksum provided - skipping verification"
        echo_warn "For security, it's recommended to verify checksums"
    fi
}

# ============================================================================
# Mount Image
# ============================================================================

mount_image() {
    local image_file="$1"
    local mount_point="$2"
    
    echo_info "Mounting image..."
    
    mkdir -p "$mount_point"
    
    # Find next available loop device
    local loop_device=$(sudo losetup -f)
    
    # Setup loop device
    sudo losetup -P "$loop_device" "$image_file"
    
    # Mount partitions
    # Typically partition 1 is boot (FAT32) and partition 2 is root (ext4)
    sudo mount "${loop_device}p2" "$mount_point"
    sudo mount "${loop_device}p1" "$mount_point/boot/firmware"
    
    echo_info "Image mounted at: $mount_point"
    echo_info "Loop device: $loop_device"
    
    # Store loop device for later cleanup
    echo "$loop_device" > "$mount_point/.loop_device"
}

# ============================================================================
# Unmount Image
# ============================================================================

unmount_image() {
    local mount_point="$1"
    
    echo_info "Unmounting image..."
    
    # Read loop device
    local loop_device=$(cat "$mount_point/.loop_device" 2>/dev/null || echo "")
    
    # Unmount partitions
    sudo umount "$mount_point/boot/firmware" 2>/dev/null || true
    sudo umount "$mount_point" 2>/dev/null || true
    
    # Detach loop device
    if [[ -n "$loop_device" ]]; then
        sudo losetup -d "$loop_device" 2>/dev/null || true
    fi
    
    # Cleanup
    rm -f "$mount_point/.loop_device"
    
    echo_info "Image unmounted"
}

# ============================================================================
# Apply Layers
# ============================================================================

apply_layers() {
    local mount_point="$1"
    local config_file="$2"
    
    echo_info "Applying layers from config: $config_file"
    
    # TODO: Implement layer application logic
    # This would involve:
    # 1. Parsing the config file
    # 2. Installing packages
    # 3. Configuring services
    # 4. Running customize hooks
    
    echo_warn "Layer application not yet fully implemented"
    echo_info "You can manually customize the mounted image at: $mount_point"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    local config_file="${1:-config/trixie-raid-security.yaml}"
    
    echo_info "Starting Raspberry Pi OS Trixie layer application"
    echo_info "Config: $config_file"
    echo_info "Cache: $CACHE_DIR"
    echo_info "Work: $WORK_DIR"
    echo ""
    
    # Create directories
    mkdir -p "$CACHE_DIR" "$WORK_DIR"
    
    # Download SHA256 if URL provided
    local sha256_file=""
    if [[ -n "$BASE_IMAGE_SHA256_URL" ]]; then
        echo_info "SHA256 URL provided: $BASE_IMAGE_SHA256_URL"
        download_sha256 "$BASE_IMAGE_SHA256_URL" "$CACHE_DIR"
        sha256_file="$CACHE_DIR/$(basename "$BASE_IMAGE_SHA256_URL")"
    fi
    
    # Download base image
    download_base_image "$BASE_IMAGE_URL" "$CACHE_DIR"
    
    # Extract image
    local compressed_file="$CACHE_DIR/$(basename "$BASE_IMAGE_URL")"
    local extracted_image=$(extract_image "$compressed_file" "$CACHE_DIR")
    
    # Verify image with SHA256
    verify_image "$extracted_image" "$BASE_IMAGE_SHA256" "$BASE_IMAGE_SHA256_URL" "$sha256_file"
    
    # Copy image to work directory
    local work_image="$WORK_DIR/$(basename "$extracted_image")"
    if [[ ! -f "$work_image" ]]; then
        echo_info "Copying image to work directory..."
        cp "$extracted_image" "$work_image"
    fi
    
    # Mount image
    local mount_point="$WORK_DIR/mnt"
    mount_image "$work_image" "$mount_point"
    
    # Apply layers
    apply_layers "$mount_point" "$config_file"
    
    # Unmount image
    unmount_image "$mount_point"
    
    echo_info "Process completed!"
    echo_info "Modified image: $work_image"
}

# ============================================================================
# Cleanup on exit
# ============================================================================

cleanup() {
    if [[ -d "$WORK_DIR/mnt" ]]; then
        unmount_image "$WORK_DIR/mnt" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# ============================================================================
# Entry point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

