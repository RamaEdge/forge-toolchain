# ForgeOS Toolchain Package Management

**Version**: 1.0.0  
**Last Updated**: 2025-01-01  
**Status**: Complete

## Overview

This document describes the comprehensive package management system for ForgeOS toolchain builds, including package sources, download processes, integrity verification, and integration with the forge-packages repository.

## Table of Contents

1. [Package Sources](#package-sources)
2. [Download Process](#download-process)
3. [Integrity Verification](#integrity-verification)
4. [forge-packages Integration](#forge-packages-integration)
5. [Offline Build Support](#offline-build-support)
6. [Package Configuration](#package-configuration)
7. [Troubleshooting](#troubleshooting)

## Package Sources

### 1. forge-packages Repository (Primary)

**URL**: `https://github.com/your-org/forge-packages.git`  
**Purpose**: Centralized package management for ForgeOS ecosystem  
**Benefits**: Offline builds, integrity verification, version pinning

#### Repository Structure

```
forge-packages/
├── packages/                    # Package source tarballs
│   ├── toolchain/              # Toolchain packages
│   │   ├── binutils-2.42.tar.xz
│   │   ├── gcc-13.2.0.tar.xz
│   │   ├── musl-1.2.4.tar.gz
│   │   ├── glibc-2.38.tar.xz
│   │   └── musl-cross-make-0.9.11.tar.gz
│   ├── kernel/                 # Kernel packages
│   │   └── linux-6.6.0.tar.xz
│   ├── userland/               # Userland packages
│   │   ├── busybox-1.36.1.tar.bz2
│   │   ├── iproute2-6.1.0.tar.xz
│   │   └── chrony-4.3.tar.gz
│   └── system/                 # System packages
│       ├── dropbear-2022.83.tar.bz2
│       ├── nftables-1.0.7.tar.bz2
│       └── apk-tools-2.14.0.tar.gz
├── metadata/                   # Package metadata
│   ├── packages.json          # Package manifest
│   ├── checksums.json         # SHA256 checksums
│   └── signatures/            # GPG signatures
└── scripts/                    # Package management scripts
    ├── download_packages.sh   # Download manager
    ├── verify_packages.sh     # Integrity verification
    └── update_packages.sh     # Package updates
```

#### Package Categories

**Toolchain Packages**:
- **binutils**: GNU binary utilities (2.42)
- **gcc**: GNU Compiler Collection (13.2.0)
- **musl**: Lightweight C library (1.2.4)
- **glibc**: GNU C library (2.38)
- **musl-cross-make**: Cross-compilation toolchain builder (0.9.11)

**Kernel Packages**:
- **linux**: Linux kernel source (6.6.0)
- **linux-headers**: Kernel headers (6.6.0)

**Userland Packages**:
- **busybox**: Lightweight Unix utilities (1.36.1)
- **iproute2**: Network utilities (6.1.0)
- **chrony**: Time synchronization (4.3)

**System Packages**:
- **dropbear**: Lightweight SSH server (2022.83)
- **nftables**: Firewall management (1.0.7)
- **apk-tools**: Alpine package manager (2.14.0)

### 2. Internet Downloads (Fallback)

**Purpose**: Fallback when forge-packages not available  
**Benefits**: Always up-to-date, no dependency on forge-packages

#### Download Sources

**GNU Packages**:
- **URL**: `https://ftp.gnu.org/gnu/`
- **Packages**: binutils, gcc, glibc
- **Verification**: SHA256 checksums, GPG signatures

**Kernel Packages**:
- **URL**: `https://www.kernel.org/pub/linux/kernel/`
- **Packages**: Linux kernel, headers
- **Verification**: SHA256 checksums, GPG signatures

**GitHub Packages**:
- **URL**: `https://github.com/`
- **Packages**: musl-cross-make, project-specific
- **Verification**: GitHub release signatures

**Project Sites**:
- **URL**: Official project websites
- **Packages**: busybox, iproute2, chrony, dropbear
- **Verification**: Project-specific verification

## Download Process

### Step 1: Package Source Detection

```bash
# Check forge-packages availability
if [[ -d "packages/forge-packages" ]]; then
    echo "forge-packages available"
    PACKAGE_SOURCE="forge-packages"
else
    echo "forge-packages not available, using internet"
    PACKAGE_SOURCE="internet"
fi
```

### Step 2: Package Download

#### From forge-packages

```bash
# Download from forge-packages
./scripts/download_packages.sh

# Download specific category
./scripts/download_packages.sh toolchain

# Download with force update
./scripts/download_packages.sh --force
```

**Process**:
1. **Clone/Update Repository**: Git clone or pull updates
2. **Load Package Manifest**: Parse packages.json
3. **Copy Packages**: Copy to local downloads directory
4. **Verify Integrity**: Check SHA256 checksums
5. **Create Info File**: Generate package information

#### From Internet

```bash
# Download from internet (fallback)
curl -L "$PACKAGE_URL" -o "$PACKAGE_FILE"

# Download with retry logic
for attempt in 1 2 3; do
    if curl -L -f --connect-timeout 30 --max-time 600 \
        --progress-bar -o "$PACKAGE_FILE" "$PACKAGE_URL"; then
        break
    else
        echo "Attempt $attempt failed, retrying..."
        sleep 2
    fi
done
```

### Step 3: Package Verification

#### SHA256 Checksum Verification

```bash
# Verify SHA256 checksum
echo "$EXPECTED_SHA256  $PACKAGE_FILE" | sha256sum -c

# Verify with expected checksum
ACTUAL_SHA256=$(sha256sum "$PACKAGE_FILE" | cut -d' ' -f1)
if [[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]]; then
    echo "Checksum verification passed"
else
    echo "Checksum verification failed"
    exit 1
fi
```

#### GPG Signature Verification

```bash
# Verify GPG signature
gpg --verify "$PACKAGE_FILE.sig" "$PACKAGE_FILE"

# Import GPG key if needed
gpg --keyserver keyserver.ubuntu.com --recv-keys "$GPG_KEY_ID"
```

## Integrity Verification

### Package Manifest (packages.json)

```json
{
  "metadata": {
    "version": "1.0.0",
    "description": "ForgeOS Package Manifest",
    "last_updated": "2025-01-01T00:00:00Z",
    "maintainer": "ForgeOS Team"
  },
  "packages": {
    "toolchain": {
      "binutils": {
        "version": "2.42",
        "url": "https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz",
        "filename": "binutils-2.42.tar.xz",
        "sha256": "a4b4c23b2534e67a2c8b8a4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4",
        "category": "toolchain",
        "description": "GNU binary utilities"
      },
      "gcc": {
        "version": "13.2.0",
        "url": "https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz",
        "filename": "gcc-13.2.0.tar.xz",
        "sha256": "b5b5c34b3644e78a3c9c9b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5",
        "category": "toolchain",
        "description": "GNU Compiler Collection"
      }
    }
  }
}
```

### Checksum Verification

#### SHA256 Checksums

```json
{
  "binutils-2.42.tar.xz": "a4b4c23b2534e67a2c8b8a4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4",
  "gcc-13.2.0.tar.xz": "b5b5c34b3644e78a3c9c9b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5",
  "musl-1.2.4.tar.gz": "c5b5c34b3644e78a3c9c9b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5"
}
```

#### Verification Process

```bash
# Load checksums
CHECKSUMS_FILE="packages/forge-packages/metadata/checksums.json"

# Verify each package
for package in packages/downloads/*; do
    filename=$(basename "$package")
    expected_sha256=$(jq -r ".\"$filename\"" "$CHECKSUMS_FILE")
    actual_sha256=$(sha256sum "$package" | cut -d' ' -f1)
    
    if [[ "$actual_sha256" == "$expected_sha256" ]]; then
        echo "✓ $filename: checksum verified"
    else
        echo "✗ $filename: checksum mismatch"
        exit 1
    fi
done
```

## forge-packages Integration

### Repository Setup

#### Clone forge-packages

```bash
# Clone forge-packages repository
git clone https://github.com/your-org/forge-packages.git packages/forge-packages

# Update forge-packages
cd packages/forge-packages
git pull origin main
```

#### Package Download Script

```bash
#!/bin/bash
# ForgeOS Toolchain Package Download Script
# Downloads packages from forge-packages repository

# Parameters
FORGE_PACKAGES_URL="${1:-https://github.com/your-org/forge-packages.git}"
PACKAGES_DIR="${2:-$PROJECT_ROOT/packages}"
PACKAGES_REPO_DIR="$PACKAGES_DIR/forge-packages"

# Clone or update forge-packages
if [[ -d "$PACKAGES_REPO_DIR" ]]; then
    echo "Updating forge-packages repository..."
    cd "$PACKAGES_REPO_DIR"
    git pull origin main
else
    echo "Cloning forge-packages repository..."
    git clone "$FORGE_PACKAGES_URL" "$PACKAGES_REPO_DIR"
fi

# Load package manifest
PACKAGES_JSON="$PACKAGES_REPO_DIR/metadata/packages.json"
if [[ ! -f "$PACKAGES_JSON" ]]; then
    echo "Error: Package manifest not found"
    exit 1
fi

# Download toolchain packages
LOCAL_PACKAGES_DIR="$PACKAGES_DIR/downloads"
mkdir -p "$LOCAL_PACKAGES_DIR"

# Copy packages from forge-packages
for package in "$PACKAGES_REPO_DIR/packages/toolchain"/*; do
    if [[ -f "$package" ]]; then
        filename=$(basename "$package")
        dest_path="$LOCAL_PACKAGES_DIR/$filename"
        
        if [[ ! -f "$dest_path" ]] || [[ "$package" -nt "$dest_path" ]]; then
            echo "Copying $filename..."
            cp "$package" "$dest_path"
        else
            echo "Cached $filename"
        fi
    fi
done
```

### Package Management Commands

#### Download Packages

```bash
# Download all packages
make download-packages

# Download specific category
./scripts/download_packages.sh toolchain

# Download with force update
./scripts/download_packages.sh --force
```

#### Verify Packages

```bash
# Verify all packages
./scripts/verify_packages.sh

# Verify specific package
./scripts/verify_packages.sh binutils-2.42.tar.xz

# Verify with verbose output
./scripts/verify_packages.sh --verbose
```

#### Update Packages

```bash
# Update all packages
./scripts/update_packages.sh

# Update specific package
./scripts/update_packages.sh binutils
```

## Offline Build Support

### Package Caching

#### Local Package Cache

```bash
# Package cache directory
PACKAGES_DIR="packages/downloads"

# Check if packages are cached
if [[ -f "$PACKAGES_DIR/binutils-2.42.tar.xz" ]]; then
    echo "Using cached packages"
    USE_CACHED_PACKAGES=true
else
    echo "Downloading packages from internet"
    USE_CACHED_PACKAGES=false
fi
```

#### Offline Build Process

```bash
# 1. Download packages (one-time)
make download-packages

# 2. Build offline
make toolchain

# 3. Verify build
make verify
```

### Air-Gapped Builds

#### Complete Offline Build

```bash
# 1. Download all packages
make download-packages

# 2. Disconnect from internet
# (air-gapped environment)

# 3. Build completely offline
make toolchain
make verify
make test
```

#### Package Verification

```bash
# Verify package integrity
./scripts/verify_packages.sh

# Check package availability
ls -la packages/downloads/

# Verify checksums
./scripts/verify_packages.sh --checksums
```

## Package Configuration

### Environment Variables

```bash
# Package source configuration
export FORGE_PACKAGES_URL="https://github.com/your-org/forge-packages.git"
export PACKAGES_DIR="packages/downloads"
export USE_FORGE_PACKAGES=true

# Package verification
export CHECKSUM_VERIFICATION=true
export GPG_SIGNATURES=false

# Package download
export MAX_RETRIES=3
export RETRY_DELAY=2
export DOWNLOAD_TIMEOUT=600
```

### Package URLs

#### Toolchain Packages

```bash
# binutils
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz"

# gcc
GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz"

# musl
MUSL_URL="https://musl.libc.org/releases/musl-1.2.4.tar.gz"

# glibc
GLIBC_URL="https://ftp.gnu.org/gnu/glibc/glibc-2.38.tar.xz"

# musl-cross-make
MUSL_CROSS_MAKE_URL="https://github.com/richfelker/musl-cross-make/archive/v0.9.11.tar.gz"
```

#### Kernel Packages

```bash
# Linux kernel
LINUX_URL="https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.6.0.tar.xz"

# Linux headers
LINUX_HEADERS_URL="https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.6.0.tar.xz"
```

#### Userland Packages

```bash
# busybox
BUSYBOX_URL="https://busybox.net/downloads/busybox-1.36.1.tar.bz2"

# iproute2
IPROUTE2_URL="https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-6.1.0.tar.xz"

# chrony
CHRONY_URL="https://download.tuxfamily.org/chrony/chrony-4.3.tar.gz"
```

## Troubleshooting

### Common Issues

#### 1. Package Download Failures

**Error**: `Failed to download package`  
**Solution**: Check network connectivity and package URLs

```bash
# Test connectivity
curl -I https://ftp.gnu.org/gnu/binutils/

# Check package URLs
jq '.packages.toolchain.binutils.url' metadata/packages.json

# Retry download
./scripts/download_packages.sh --force
```

#### 2. Checksum Verification Failures

**Error**: `Checksum verification failed`  
**Solution**: Check package integrity and download source

```bash
# Verify checksum manually
sha256sum packages/downloads/binutils-2.42.tar.xz

# Check expected checksum
jq '.packages.toolchain.binutils.sha256' metadata/packages.json

# Re-download package
rm packages/downloads/binutils-2.42.tar.xz
./scripts/download_packages.sh
```

#### 3. forge-packages Not Available

**Error**: `forge-packages repository not found`  
**Solution**: Check repository URL and access

```bash
# Check repository URL
echo $FORGE_PACKAGES_URL

# Test repository access
git ls-remote $FORGE_PACKAGES_URL

# Clone repository manually
git clone $FORGE_PACKAGES_URL packages/forge-packages
```

#### 4. Package Cache Issues

**Error**: `Package not found in cache`  
**Solution**: Clear cache and re-download

```bash
# Clear package cache
rm -rf packages/downloads/*

# Re-download packages
./scripts/download_packages.sh

# Verify package availability
ls -la packages/downloads/
```

### Debug Information

#### Enable Verbose Output

```bash
# Enable debug output
export DEBUG=1
./scripts/download_packages.sh

# Enable verbose output
./scripts/verify_packages.sh --verbose

# Check package status
./scripts/verify_packages.sh --status
```

#### Package Logs

**Location**: `packages/downloads/package-info.txt`  
**Content**: Package download information, checksums, timestamps  
**Usage**: Debug package issues

```bash
# View package information
cat packages/downloads/package-info.txt

# Check package timestamps
ls -la packages/downloads/

# Verify package integrity
./scripts/verify_packages.sh --checksums
```

### Performance Optimization

#### Parallel Downloads

**Default**: Sequential downloads  
**Override**: Set parallel download limit

```bash
# Use 4 parallel downloads
export PARALLEL_DOWNLOADS=4
./scripts/download_packages.sh

# Use all available connections
export PARALLEL_DOWNLOADS=$(nproc)
./scripts/download_packages.sh
```

#### Package Caching

**Location**: `packages/downloads/` directory  
**Purpose**: Cache downloaded packages for faster rebuilds  
**Clean**: `make clean-packages` to remove cache

```bash
# Clean package cache
make clean-packages

# Re-download packages
make download-packages
```

## Best Practices

### 1. Use forge-packages for Offline Builds

```bash
# Download packages once
make download-packages

# Build offline
make toolchain
```

### 2. Verify Package Integrity

```bash
# Verify all packages
./scripts/verify_packages.sh

# Verify specific package
./scripts/verify_packages.sh binutils-2.42.tar.xz
```

### 3. Use Reproducible Package Versions

```bash
# Pin package versions in packages.json
{
  "packages": {
    "toolchain": {
      "binutils": {
        "version": "2.42",
        "sha256": "a4b4c23b2534e67a2c8b8a4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4"
      }
    }
  }
}
```

### 4. Monitor Package Updates

```bash
# Check for package updates
./scripts/update_packages.sh --check

# Update specific package
./scripts/update_packages.sh binutils

# Update all packages
./scripts/update_packages.sh
```

### 5. Clean Package Cache

```bash
# Clean package cache
make clean-packages

# Clean all artifacts
make clean-all
```

## Conclusion

The ForgeOS toolchain package management system provides a robust, flexible approach to package management with support for both offline and online builds. The integration with forge-packages enables efficient, reproducible builds while maintaining fallback support for internet downloads.

For more information, see:
- [Toolchain Build Process](toolchain-build-process.md)
- [Integration Guide](integration-guide.md)
- [Main README](../README.md)
