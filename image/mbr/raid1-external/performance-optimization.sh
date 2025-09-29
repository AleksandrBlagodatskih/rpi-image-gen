#!/bin/bash
#
# Performance Optimization for RAID External Layer
# Implements build caching, parallel processing, and image size optimization
#

set -eu

# ============================================================================
# Environment Setup Functions
# ============================================================================

setup_build_environment() {
    echo "Setting up optimized build environment..."

    # Set up APT caching if enabled
    if [[ "$IGconf_raid_external_apt_cache" == "y" ]]; then
        export APT_CACHE_DIR="${IGconf_sys_workroot}/apt-cache"
        mkdir -p "$APT_CACHE_DIR"

        # Configure APT to use cache
        echo "Dir::Cache \"$APT_CACHE_DIR\";" > /etc/apt/apt.conf.d/01-cache
        echo "Dir::Cache::Archives \"$APT_CACHE_DIR/archives\";" >> /etc/apt/apt.conf.d/01-cache
        echo "APT cache configured at: $APT_CACHE_DIR"
    fi

    # Set up ccache if enabled
    if [[ "$IGconf_raid_external_ccache" == "y" ]]; then
        export CCACHE_DIR="${IGconf_sys_workroot}/ccache"
        export CCACHE_MAXSIZE="$IGconf_raid_external_ccache_size"
        mkdir -p "$CCACHE_DIR"

        # Configure ccache
        ccache --set-config=max_size="$IGconf_raid_external_ccache_size"
        ccache --set-config=compression=true
        ccache --set-config=compression_level=6

        echo "ccache configured at: $CCACHE_DIR (max size: $IGconf_raid_external_ccache_size)"
    fi

    # Set up parallel jobs
    if [[ "$IGconf_raid_external_parallel_jobs" -gt 0 ]]; then
        export PARALLEL_JOBS="$IGconf_raid_external_parallel_jobs"
        echo "Parallel jobs set to: $IGconf_raid_external_parallel_jobs"
    else
        # Auto-detect CPU count
        export PARALLEL_JOBS=$(nproc 2>/dev/null || echo "4")
        echo "Auto-detected parallel jobs: $PARALLEL_JOBS"
    fi
}

optimize_image_size() {
    local target_dir="$1"

    echo "Optimizing image size..."

    if [[ ! -d "$target_dir" ]]; then
        echo "Warning: Target directory not found for optimization: $target_dir"
        return 0
    fi

    # Remove unnecessary files
    find "$target_dir" -name "*.pyc" -delete 2>/dev/null || true
    find "$target_dir" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

    # Clean APT cache if it exists
    if [[ -d "$target_dir/var/cache/apt" ]]; then
        chroot "$target_dir" apt-get clean
        chroot "$target_dir" apt-get autoclean
    fi

    # Remove documentation files (optional, for minimal images)
    if [[ "$IGconf_raid_external_image_size_optimization" == "y" ]]; then
        find "$target_dir/usr/share/doc" -type f -delete 2>/dev/null || true
        find "$target_dir/usr/share/man" -type f -delete 2>/dev/null || true
        find "$target_dir/usr/share/info" -type f -delete 2>/dev/null || true
    fi

    echo "Image size optimization completed"
}

setup_apt_proxy() {
    # Configure APT proxy for faster downloads if available
    if [[ -n "${APT_PROXY:-}" ]]; then
        echo "Acquire::http::Proxy \"$APT_PROXY\";" > /etc/apt/apt.conf.d/02-proxy
        echo "APT proxy configured: $APT_PROXY"
    fi
}

enable_build_caching() {
    echo "Enabling build caching..."

    # Create cache directories
    mkdir -p "${IGconf_sys_workroot}/build-cache"
    mkdir -p "${IGconf_sys_workroot}/pkg-cache"

    # Configure dpkg to use cache
    echo "Dir::Cache::pkgcache \"${IGconf_sys_workroot}/pkg-cache\";" >> /etc/apt/apt.conf.d/01-cache
    echo "Dir::Cache::srcpkgcache \"${IGconf_sys_workroot}/pkg-cache\";" >> /etc/apt/apt.conf.d/01-cache

    echo "Build caching enabled"
}

# ============================================================================
# Main Performance Optimization Function
# ============================================================================

perform_performance_optimization() {
    local target_dir="$1"

    echo "Starting performance optimization for RAID external layer..."

    # Set up build environment
    setup_build_environment

    # Set up APT proxy if configured
    setup_apt_proxy

    # Enable build caching
    enable_build_caching

    # Optimize image size at the end
    optimize_image_size "$target_dir"

    # Display optimization summary
    echo "Performance optimization completed:"
    echo "  - APT cache: ${IGconf_raid_external_apt_cache:-disabled}"
    echo "  - ccache: ${IGconf_raid_external_ccache:-disabled}"
    echo "  - Parallel jobs: ${PARALLEL_JOBS:-auto}"
    echo "  - Image size optimization: ${IGconf_raid_external_image_size_optimization:-disabled}"
    echo "  - Compression: ${IGconf_raid_external_compression:-zstd}"
}

# ============================================================================
# Export function for use by other scripts
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <target_directory>"
        exit 1
    fi

    perform_performance_optimization "$1"
fi
