# Raspberry Pi OS Base Image Layer

**Category:** `base-image`  
**Layer Name:** `raspios-base`  
**Version:** 1.0.0

---

## 📋 Description

This layer downloads and prepares **official Raspberry Pi OS images** as a base for further customization. Instead of building from scratch, you can start with pre-built, tested, and officially supported images.

### Advantages

✅ **Faster builds** - 5-10 minutes vs 30-60 minutes  
✅ **Official images** - Directly from Raspberry Pi Foundation  
✅ **Pre-configured** - Tested and ready to use  
✅ **Regular updates** - Easy to update to newer versions  
✅ **Security hardening** - Apply additional layers on top  
✅ **SHA256 verification** - Automatic integrity checking  

---

## 🎯 Use Cases

### 1. Quick Prototyping
Start with official image, add your layers, deploy fast.

### 2. Security Hardening
Apply security suite on top of official base.

### 3. Custom Appliances
Build specialized devices based on official images.

### 4. Enterprise Deployments
Use internal mirrors with verified checksums.

---

## 🔧 Configuration Variables

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `raspios_base_image_url` | - | **Yes** | URL to Raspberry Pi OS image |
| `raspios_base_image_sha256` | - | No | SHA256 checksum (direct) |
| `raspios_base_image_sha256_url` | - | No | URL to SHA256 file |
| `raspios_base_cache_dir` | `./cache` | No | Cache directory |
| `raspios_base_verify_checksum` | `y` | No | Verify SHA256 |
| `raspios_base_force_redownload` | `n` | No | Force re-download |
| `raspios_base_extract_format` | `auto` | No | Compression format |
| `raspios_base_target_device` | `rpi5` | No | Target device |

---

## 🚀 Quick Start

### Basic Configuration

```yaml
device:
  layer: rpi5

image:
  layer: standard
  name: my-raspios

layer:
  base: raspios-base

raspios_base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

layers:
  - security-suite
```

### Build

```bash
./rpi-image-gen build -c my-config.yaml
```

---

## 📦 Available Images

### Raspberry Pi OS Lite (ARM64) - Recommended

**Latest:** Trixie (Debian 13)  
**URL:** https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz  
**SHA256:** https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

**Characteristics:**
- Minimal installation
- No desktop environment
- Perfect for servers and headless setups
- ~500 MB compressed

### Raspberry Pi OS Desktop (ARM64)

**URL:** https://downloads.raspberrypi.com/raspios_arm64/images/  
**Characteristics:**
- Full desktop environment
- Recommended applications
- ~1.2 GB compressed

### Raspberry Pi OS Full (ARM64)

**URL:** https://downloads.raspberrypi.com/raspios_full_arm64/images/  
**Characteristics:**
- Complete suite of applications
- Development tools
- ~2.5 GB compressed

### Legacy Releases

**Bullseye:** https://downloads.raspberrypi.com/raspios_oldstable_lite_arm64/images/  
**Bookworm:** https://downloads.raspberrypi.com/raspios_oldstable_lite_arm64/images/

---

## 🔒 SHA256 Verification

### Method 1: Auto-download SHA256 (Recommended)

```yaml
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/.../image.img.xz.sha256
```

The layer will:
1. Download SHA256 file
2. Extract checksum (supports 5 formats)
3. Verify image automatically

### Method 2: Direct SHA256

```yaml
raspios_base_image_sha256: "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd"
```

### Supported SHA256 Formats

1. **Only checksum:** `a1b2c3d4e5f6...`
2. **Checksum + filename:** `a1b2c3d4e5f6...  image.img.xz`
3. **Multiple files:** One checksum per line
4. **Filename: checksum:** `image.img.xz: a1b2c3d4e5f6...`
5. **Filename = checksum:** `image.img.xz = a1b2c3d4e5f6...`

---

## 📚 Examples

### Example 1: Minimal Security-Hardened

```yaml
device:
  layer: rpi5

image:
  layer: standard
  name: secure-raspios

layer:
  base: raspios-base

raspios_base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz.sha256

layers:
  - security-suite
```

### Example 2: Development Environment

```yaml
device:
  layer: rpi5

image:
  layer: standard
  name: dev-raspios

layer:
  base: raspios-base

raspios_base_image_url: https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_verify_checksum: n  # Skip for dev

layers:
  - sys-devel/gnu-common
  - app-container/distrobox
  - net-misc/cockpit
```

### Example 3: Enterprise Production

```yaml
device:
  layer: rpi-cm5
  variant: 8G

image:
  layer: standard
  name: enterprise-raspios

layer:
  base: raspios-base

# Internal mirror with verified checksum
raspios_base_image_url: https://internal-mirror.company.com/raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256: "verified_checksum_from_security_audit"
raspios_base_verify_checksum: y
raspios_base_cache_dir: /var/cache/rpi-images

layers:
  - security-suite
  - net-misc/cockpit
  - app-misc/rpi5-server-config
```

### Example 4: Custom Internal Mirror

```yaml
device:
  layer: rpi4

image:
  layer: standard
  name: internal-mirror

layer:
  base: raspios-base

# Use company internal mirror
raspios_base_image_url: http://mirror.internal.company/raspios/2025-10-01-raspios-trixie-arm64-lite.img.xz
raspios_base_image_sha256: "company_verified_checksum"
raspios_base_cache_dir: /opt/cache
raspios_base_force_redownload: n

layers:
  - security/apparmor
  - security/ufw
```

---

## 🔍 Process Flow

1. **Check Cache**
   - Look for cached image
   - Skip download if exists (unless `force_redownload`)

2. **Download SHA256**
   - If `image_sha256_url` provided
   - Parse and extract checksum

3. **Download Image**
   - Download from `image_url`
   - Show progress
   - Cache in `cache_dir`

4. **Verify Checksum**
   - Compare with expected SHA256
   - Fail if mismatch

5. **Extract Image**
   - Auto-detect format (xz, gz, zip)
   - Extract to cache directory

6. **Prepare for Layers**
   - Export image path
   - Ready for additional layers

---

## 🛠️ Advanced Configuration

### Custom Cache Directory

```yaml
raspios_base_cache_dir: /mnt/storage/cache
```

### Force Re-download

```yaml
raspios_base_force_redownload: y
```

### Skip Verification (NOT Recommended)

```yaml
raspios_base_verify_checksum: n
```

### Specific Compression Format

```yaml
raspios_base_extract_format: xz  # or gz, zip, none
```

---

## 📊 Performance

| Operation | Time | Notes |
|-----------|------|-------|
| Download (cached) | 0s | Instant |
| Download (new) | 2-5 min | Depends on connection |
| Extraction | 1-2 min | xz decompression |
| Verification | 30-60s | SHA256 calculation |
| **Total (first run)** | **3-8 min** | vs 30-60 min from scratch |
| **Total (cached)** | **1-2 min** | Just extraction |

---

## 🔒 Security Considerations

### Always Verify Checksums

```yaml
raspios_base_verify_checksum: y
raspios_base_image_sha256_url: https://...
```

### Use HTTPS

```yaml
raspios_base_image_url: https://downloads.raspberrypi.com/...
raspios_base_image_sha256_url: https://downloads.raspberrypi.com/...
```

### Store Checksums in Version Control

```yaml
raspios_base_image_sha256: "verified_checksum_from_audit"
```

### Internal Mirrors

For enterprise:
1. Download official image
2. Verify SHA256 manually
3. Upload to internal mirror
4. Use direct checksum in config

---

## 🐛 Troubleshooting

### Image Download Fails

**Problem:** Network error or URL changed

**Solution:**
```bash
# Check URL manually
curl -I https://downloads.raspberrypi.com/.../image.img.xz

# Update URL in config
raspios_base_image_url: <new_url>
```

### SHA256 Mismatch

**Problem:** Checksum doesn't match

**Solution:**
```bash
# Verify manually
sha256sum ./cache/image.img.xz

# Compare with official
wget https://downloads.raspberrypi.com/.../image.img.xz.sha256 -O - | cat

# Update checksum or re-download
raspios_base_force_redownload: y
```

### Extraction Fails

**Problem:** Unknown compression format

**Solution:**
```yaml
# Specify format explicitly
raspios_base_extract_format: xz  # or gz, zip, none
```

### Out of Disk Space

**Problem:** Not enough space in cache

**Solution:**
```bash
# Clean old images
rm -rf ./cache/*

# Use different cache location
raspios_base_cache_dir: /mnt/large-storage/cache
```

---

## 📚 Related Documentation

- [SHA256 Verification Guide](../../../docs/SHA256_VERIFICATION.md)
- [Trixie Base Image](../../../docs/TRIXIE_BASE_IMAGE.md)
- [Security Suite](../../security/security-suite.yaml)
- [Layer Best Practices](../../LAYER_BEST_PRACTICES)

---

## ✅ Layer Metadata

```yaml
Name:        raspios-base
Category:    base-image
Version:     1.0.0
Requires:    -
Provides:    base-image, raspios
Conflicts:   -
VarPrefix:   raspios_base
```

---

## 🎯 Next Steps

1. Choose your base image
2. Configure SHA256 verification
3. Add security layers
4. Add application layers
5. Build and deploy

---

**Created:** October 2, 2025  
**Version:** 1.0.0  
**Status:** ✅ Production Ready

