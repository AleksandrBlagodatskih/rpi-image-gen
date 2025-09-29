# RAID External Layer Documentation

## Overview

The RAID External layer provides enterprise-grade RAID1 functionality for Raspberry Pi systems with external drives. It supports RAID1 mirroring with comprehensive encryption, provisioning, and validation features.

## Features

- **RAID1 Mirroring**: Data redundancy with automatic failover support
- **Fixed Configuration**: Optimized for exactly 2 external drives
- **Filesystem Support**: ext4, btrfs with advanced features
- **Enterprise Security**: LUKS2 encryption by default with secure key management
- **Provisioning**: PMAP 1.2.0 with slotted A/B updates and partition mapping
- **Validation**: Comprehensive requirement checking for RAID1 configuration
- **SBOM Integration**: Automatic security scanning and compliance reporting

## Supported Configuration

### RAID1 - Data Safety
```yaml
image:
  layer: raid-external
  raid_external_raid_level: RAID1
  raid_external_raid_devices: 2
  raid_external_encryption_enabled: y  # Production security
```

**Use case**: Production systems requiring data redundancy and reliability

## Configuration

The RAID External layer is configured for exactly 2 external drives with RAID1 mirroring:

- **2 devices**: RAID1 configuration (required for RAID1)
- **Fixed setup**: Optimized configuration for maximum reliability

The layer creates:
- SD card image (`sdcard.img`) with MBR partition table for boot compatibility
- External drive images (`external1.img`, `external2.img`) with GPT partition table for flexibility
- RAID1 member disk images (`raid1-disk1.ext4`, `raid1-disk2.ext4`) created using genimage mdraid
- RAID1 member disk images (`raid1-disk1.btrfs`, `raid1-disk2.btrfs`) for btrfs configurations
- Root filesystem images (`root.ext4`, `raid1.btrfs`) mounted on assembled RAID1 arrays
- Provisioning maps with correct RAID member disk mappings
- Sparse images for efficient storage

## Partition Table Strategy

The layer uses different partition table types for optimal compatibility:

### SD Card (MBR)
- **MBR partition table** for maximum boot compatibility
- **Single boot partition** (FAT32) for Raspberry Pi firmware
- **Legacy BIOS support** for older systems

### External Drives (GPT)
- **GPT partition table** for modern systems and flexibility
- **Linux RAID partition type** (GUID: 0FC63DAF-8483-4772-8E79-3D69D8477DE4)
- **Support for large disks** (>2TB) and multiple partitions
- **UEFI compatibility** for modern firmware

## RAID Architecture

The layer uses genimage's built-in mdraid support for RAID1 creation:

1. **genimage mdraid**: Creates RAID1 member disks with unique disk UUIDs but shared array UUID
2. **Parent/Child Relationship**: First disk defines array configuration, second inherits from it
3. **Role Assignment**: Each disk gets a specific role (0 or 1) in the array
4. **Automatic Assembly**: When both disks are present, Linux automatically assembles the RAID1 array
5. **Device-based Mounting**: Root filesystem mounts /dev/md0 (RAID array device)
6. **Encryption Support**: LUKS encryption can be applied to RAID arrays

## Configuration Variables

### Core Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `raid_external_rootfs_type` | `ext4` | Filesystem type (ext4, btrfs) |
| `raid_external_raid_level` | `RAID1` | RAID level (RAID0, RAID1, RAID5, RAID10) |
| `raid_external_raid_devices` | `2` | Number of external drives (2-4) |
| `raid_external_encryption_enabled` | `y` | Enable LUKS2 encryption |

### Performance Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `raid_external_apt_cache` | `y` | Enable APT package caching |
| `raid_external_ccache` | `y` | Enable ccache for cross-compilation |
| `raid_external_ccache_size` | `5G` | ccache maximum cache size |
| `raid_external_parallel_jobs` | `0` | Parallel build jobs (0 = auto-detect) |
| `raid_external_image_size_optimization` | `y` | Enable image size optimization |

### Advanced Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `raid_external_sector_size` | `512` | Drive sector size (512, 4096) |
| `raid_external_compression` | `zstd` | Image compression (none, zstd, gzip) |
| `raid_external_mbr_type` | `mbr` | Partition table (mbr, gpt) |
| `raid_external_pmap` | `crypt` | Provisioning map (clear, crypt) |

## Examples

### Basic RAID1 Setup
```yaml
# test-raid-simple.yaml
device:
  layer: rpi5

image:
  layer: raid-external
  name: basic-raid1
  raid_external_raid_level: RAID1
  raid_external_raid_devices: 2

layer:
  base: bookworm-minbase
```


## Validation

The layer includes comprehensive validation:

- **RAID1 Requirements**: Exactly 2 devices required
- **Filesystem Support**: Valid filesystem types (ext4, btrfs)
- **Device Count**: Fixed at 2 external drives
- **Configuration Consistency**: All parameters validated

## Building

```bash
# Build RAID1 configuration
rpi-image-gen build -c test-raid-simple.yaml

# Build enterprise RAID1 with security
rpi-image-gen build -c test-raid-enterprise.yaml
```

## Deployment

1. **Generate Provisioning Data**:
   ```bash
   ./bin/image2json -g genimage.cfg -f image.json
   ```

2. **Deploy to Device**:
   ```bash
   ./bin/idp.sh -f image.json
   ```

3. **Verify RAID Status**:
   ```bash
   # On target device
   raid-status  # Custom RAID monitoring script
   cat /proc/mdstat  # Kernel RAID status
   ```

## Troubleshooting

### Common Issues

**"RAID1 requires exactly 2 devices"**
- Ensure `raid_external_raid_devices = 2` for RAID1

**"Unsupported filesystem"**
- Use only `ext4` or `btrfs` for `raid_external_rootfs_type`

### Debug Commands

```bash
# Check layer validation
rpi-image-gen layer --validate image/mbr/raid-external/image.yaml

# Check dependencies
rpi-image-gen layer --check raid-external

# View provisioning map
pmap -f work/deploy-*/provisionmap.json --slotvars
```

## Enterprise Integration

This layer is designed for enterprise use cases with comprehensive examples:

### Enterprise Configuration Examples

- **[Automotive](https://github.com/supernova-project/rpi-image-gen/blob/main/examples/enterprise/automotive-raid-config.yaml)**: Vehicle data logging with CAN bus integration and HIPAA compliance
- **[Industrial](https://github.com/supernova-project/rpi-image-gen/blob/main/examples/enterprise/industrial-raid-config.yaml)**: SCADA systems with PLC integration and safety standards
- **[Medical](https://github.com/supernova-project/rpi-image-gen/blob/main/examples/enterprise/medical-raid-config.yaml)**: Patient monitoring with HIPAA compliance and medical protocols
- **[Infrastructure](https://github.com/supernova-project/rpi-image-gen/blob/main/examples/enterprise/infrastructure-raid-config.yaml)**: Network appliances with high availability and monitoring

### Enterprise Features

- **Compliance Ready**: HIPAA, FDA, IEC 61508, ISO 13849 compliance
- **Security Hardened**: LUKS2 encryption, secure boot, audit trails
- **Monitoring Integration**: Prometheus/Grafana, ELK stack, PagerDuty
- **Deployment Automation**: Ansible, Terraform, Kubernetes ready
- **Asset Management**: ITAM integration for enterprise inventory

## Performance Optimizations

The RAID External layer includes comprehensive performance optimizations:

### Build Caching
- **APT Caching**: Package cache for faster downloads
- **ccache**: Cross-compilation cache for faster builds
- **Build Cache**: Persistent cache for repeated builds

### Parallel Processing
- **Auto-detection**: Automatic CPU core detection
- **Configurable Jobs**: Manual parallel job configuration
- **Optimized Builds**: Batch operations for efficiency

### Image Optimization
- **Size Reduction**: Remove unnecessary files and documentation
- **Compression**: Multiple compression options (zstd, gzip, none)
- **Sparse Images**: Efficient storage format

### Configuration Example
```yaml
image:
  layer: raid-external
  raid_external_apt_cache: y              # Enable APT caching
  raid_external_ccache: y                 # Enable ccache
  raid_external_ccache_size: 10G          # Large cache for enterprise
  raid_external_parallel_jobs: 8          # Maximum parallel jobs
  raid_external_image_size_optimization: y # Optimize for deployment
```

## Security Considerations

- **Encryption**: Enabled by default with LUKS2
- **SBOM**: Automatic generation for compliance
- **Secure Boot**: Compatible with secure boot systems
- **TPM**: Hardware security module support

## Performance Characteristics

| RAID Level | Devices | Read Performance | Write Performance | Redundancy |
|------------|---------|-----------------|-------------------|------------|
| RAID1 | 2 | Good | Good | Single drive failure |

## Support

- **Homepage**: https://github.com/supernova-project/rpi-image-gen
- **Issues**: https://github.com/supernova-project/rpi-image-gen/issues
- **Discussions**: https://github.com/supernova-project/rpi-image-gen/discussions
