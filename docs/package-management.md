# ForgeOS Toolchain Package Management

**Version**: 2.0.0  
**Last Updated**: 2025-01-27  
**Status**: Complete

## Overview

This document describes the comprehensive package management system for ForgeOS toolchain builds, including package sources, download processes from GitHub releases, integrity verification, and integration with the forge-packages repository.

## Table of Contents

1. [Package Download Sources](#package-download-sources)
2. [GitHub Releases Integration](#github-releases-integration)
3. [Download Process](#download-process)
4. [Configuration](#configuration)
5. [Offline Build Support](#offline-build-support)
6. [Usage Examples](#usage-examples)
7. [Troubleshooting](#troubleshooting)

## Package Download Sources

### 1. GitHub Releases (Primary - Recommended)

**URL**: `https://github.com/RamaEdge/forge-packages/releases`  
**Purpose**: Download pre-packaged releases from forge-packages repository  
**Benefits**: Fast downloads, no repository cloning needed, no disk overhead

#### How It Works

```bash
# Packages are downloaded from GitHub release assets
https://github.com/RamaEdge/forge-packages/releases/download/v1.0.0/binutils-2.42.tar.xz
https://github.com/RamaEdge/forge-packages/releases/download/v1.0.0/gcc-13.2.0.tar.xz
https://github.com/RamaEdge/forge-packages/releases/download/v1.0.0/musl-cross-make-0.9.11.tar.gz
```

#### Available Releases

- **Latest**: `v1.0.0` (default)
- **Previous**: Check [GitHub Releases](https://github.com/RamaEdge/forge-packages/releases)
- **Release Notes**: Included with each release

### 2. forge-packages Repository (Alternative)

**URL**: `https://github.com/RamaEdge/forge-packages.git`  
**Purpose**: Alternative: Clone repository for packages  
**Benefits**: Full access to all packages and metadata  
**Note**: Requires more disk space, slower initial setup

## GitHub Releases Integration

### Configuration in build.json

The toolchain stores release information in `build.json`:

```json
{
  "build": {
    "repository": {
      "forge_packages_releases": "https://github.com/RamaEdge/forge-packages/releases",
      "forge_packages_version": "v1.0.0"
    },
    "packages": {
      "binutils": {
        "version": "2.42",
        "filename": "binutils-2.42.tar.xz",
        "url": "https://github.com/RamaEdge/forge-packages/releases/download/v1.0.0/binutils-2.42.tar.xz"
      },
      // ... more packages ...
    }
  }
}
```

### Features

✅ **Simple URLs**: Each package has direct GitHub release URL  
✅ **Version Control**: `forge_packages_version` controls which release to download  
✅ **Per-Package URLs**: Each package URL can be overridden  
✅ **Fallback URLs**: Support for alternative download sources  

## Download Process

### Step 1: List Available Packages

```bash
# List all available packages
make list-packages

# Show package details
make package-info PACKAGE=binutils

# Show package configuration
make config
```

### Step 2: Download Packages

#### Default Release Download

```bash
# Download all packages from default release (v1.0.0)
make download-packages

# Or directly
./scripts/download_packages.sh
```

#### Download from Specific Release

```bash
# Download packages from specific release
make download-packages-release VERSION=v1.0.1

# Or directly
./scripts/download_packages.sh "" v1.0.1
```

#### Download Specific Package

```bash
# Download single package (default release)
make download-package PACKAGE=binutils

# Download single package from specific release
make download-package PACKAGE=gcc VERSION=v1.0.1

# Or directly
./scripts/download_packages.sh gcc
./scripts/download_packages.sh gcc v1.0.1
```

### Step 3: Verify Download

```bash
# Check package directory
ls -lah packages/downloads/

# Verify all packages present
ls packages/downloads/ | wc -l
```

## Configuration

### Update Release Version

Edit `build.json` to change the default release:

```json
{
  "build": {
    "repository": {
      "forge_packages_version": "v1.0.1"  // Change this line
    }
  }
}
```

Then download:

```bash
make download-packages
```

### Update Package URLs

To use a different package source, edit the URL in `build.json`:

```json
{
  "packages": {
    "binutils": {
      "url": "https://custom-mirror.example.com/binutils-2.42.tar.xz"
    }
  }
}
```

### Environment Variables

```bash
# Override release version
export RELEASE_VERSION=v1.0.1

# Run download
make download-packages-release VERSION=$RELEASE_VERSION
```

## Offline Build Support

### Recommended Workflow

```bash
# Step 1: Download all packages once
make download-packages

# Step 2: Optionally disconnect network (air-gapped)
# (no network needed after this)

# Step 3: Build offline
make toolchain

# Step 4: Verify build
make verify

# Step 5: Test build
make test
```

### Offline Scenarios

#### Complete Offline Build

```bash
# 1. Online: Download all packages
make download-packages

# 2. Transfer to offline machine
rsync -av packages/downloads/ offline_machine:/path/to/packages/downloads/

# 3. Offline: Build without internet
cd /path/to/forge-toolchain
make toolchain PACKAGES_DIR=$(pwd)/packages/downloads
```

#### Update Packages Offline

```bash
# 1. Online: Download new release
make download-packages-release VERSION=v1.0.1

# 2. Clear old packages (optional)
make clean-packages

# 3. Redownload for new release
make download-packages-release VERSION=v1.0.1
```

## Usage Examples

### Example 1: Basic Usage

```bash
# Download default packages
make download-packages

# Output:
# [INFO] ForgeOS Toolchain Package Download System
# [INFO] Release Version: v1.0.0
# [INFO] Source: https://github.com/RamaEdge/forge-packages/releases
# ...
# [✓] Downloaded: binutils-2.42.tar.xz
# [✓] Downloaded: gcc-13.2.0.tar.xz
# ...
# [✓] All packages ready! ✨
```

### Example 2: Download from Specific Release

```bash
# Download v1.0.1 packages
make download-packages-release VERSION=v1.0.1

# Or in script
./scripts/download_packages.sh "" v1.0.1
```

### Example 3: Download Single Package

```bash
# Download just gcc
make download-package PACKAGE=gcc

# Download gcc from v1.0.1
make download-package PACKAGE=gcc VERSION=v1.0.1
```

### Example 4: Build with Downloaded Packages

```bash
# Download packages
make download-packages

# Build musl toolchain
make toolchain TOOLCHAIN=musl ARCH=aarch64

# Build glibc toolchain
make toolchain TOOLCHAIN=gnu ARCH=aarch64

# Build for x86_64
make toolchain TOOLCHAIN=musl ARCH=x86_64
```

### Example 5: Verify Packages

```bash
# List packages
make list-packages

# Show package info
make package-info PACKAGE=gcc

# Check download status
ls -la packages/downloads/ | grep -E '\.(tar|gz|xz)'
```

## Troubleshooting

### Common Issues

#### 1. Download Fails with Network Error

**Error**: `Failed to download: binutils-2.42.tar.xz`  
**Causes**: Network connectivity, URL incorrect, server down

```bash
# Check network connectivity
curl -I https://github.com/RamaEdge/forge-packages/releases

# Verify URL is correct
grep "download" build.json | head -3

# Try downloading manually
curl -L "https://github.com/RamaEdge/forge-packages/releases/download/v1.0.0/binutils-2.42.tar.xz" \
  -o packages/downloads/binutils-2.42.tar.xz

# Retry download
make download-packages
```

#### 2. Release Not Found

**Error**: `Some packages failed to download`  
**Cause**: Release version doesn't exist

```bash
# Check available releases
curl -s https://api.github.com/repos/RamaEdge/forge-packages/releases | jq '.[] | .tag_name'

# Update build.json with correct version
# Then re-download
make download-packages-release VERSION=v1.0.0
```

#### 3. Partial Downloads

**Error**: Download interrupted, some files missing

```bash
# Clean and restart
make clean-packages

# Re-download
make download-packages

# Verify all packages
ls packages/downloads/ | wc -l
# Should match: jq '.build.packages | length' build.json
```

#### 4. Disk Space Issues

**Error**: `No space left on device`  
**Solution**: Clean packages and verify disk space

```bash
# Check disk usage
df -h

# See package size
du -sh packages/downloads/

# Clean if needed
make clean-packages
```

### Debug Information

#### Show Configuration

```bash
# Display download configuration
make config

# Output shows:
# Package Configuration (from build.json):
# {
#   "forge_packages_releases": "https://github.com/RamaEdge/forge-packages/releases",
#   "forge_packages_version": "v1.0.0"
# }
```

#### Verbose Download Output

```bash
# Download with verbose logging
./scripts/download_packages.sh

# Shows detailed progress
# [INFO] Downloading: binutils-2.42.tar.xz (2.42)
# [INFO]   URL: https://github.com/RamaEdge/forge-packages/releases/download/v1.0.0/binutils-2.42.tar.xz
# ######################################################################## 100.0%
# [✓] Downloaded: binutils-2.42.tar.xz
```

#### Check Package Details

```bash
# Show all package URLs
make list-packages | xargs -I {} jq '.build.packages."{}".url' build.json

# Show specific package details
make package-info PACKAGE=gcc
```

## Best Practices

### 1. Pin Release Version

Always use a specific release version for reproducibility:

```bash
# ✓ Good: Specific version
make download-packages-release VERSION=v1.0.0

# ✗ Bad: Latest (changes unexpectedly)
curl https://github.com/RamaEdge/forge-packages/releases/latest/...
```

### 2. Download Once, Build Many

```bash
# Download packages once
make download-packages

# Build multiple toolchains
make toolchain TOOLCHAIN=musl ARCH=aarch64
make toolchain TOOLCHAIN=gnu ARCH=aarch64
make toolchain TOOLCHAIN=musl ARCH=x86_64
# ... all use same cached packages ...
```

### 3. Verify Packages After Download

```bash
# Check all packages present
ls packages/downloads/ | wc -l

# Verify count matches configuration
jq '.build.packages | length' build.json
```

### 4. Document Custom URLs

If using custom package sources, document in `build.json`:

```json
{
  "packages": {
    "custom-package": {
      "version": "1.0.0",
      "filename": "custom-package-1.0.0.tar.gz",
      "url": "https://custom-mirror.example.com/custom-package-1.0.0.tar.gz",
      "category": "custom"
    }
  }
}
```

### 5. Use Makefile Targets

Always use Makefile targets for consistent behavior:

```bash
# ✓ Recommended
make download-packages

# ✗ Direct script (skips checks)
./scripts/download_packages.sh
```

## See Also

- [Toolchain Build Process](toolchain-build-process.md)
- [Integration Guide](integration-guide.md)
- [Main README](../README.md)
- [forge-packages Repository](https://github.com/RamaEdge/forge-packages)
