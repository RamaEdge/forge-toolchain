# ForgeOS Toolchain Integration Guide

**Version**: 1.0.0  
**Last Updated**: 2025-01-01  
**Status**: Complete

## Overview

This document describes how to integrate the ForgeOS toolchain repository with other ForgeOS repositories and external projects, including package management, build system integration, and CI/CD workflows.

## Table of Contents

1. [Repository Integration](#repository-integration)
2. [Package System Integration](#package-system-integration)
3. [Build System Integration](#build-system-integration)
4. [CI/CD Integration](#cicd-integration)
5. [External Project Integration](#external-project-integration)
6. [Troubleshooting](#troubleshooting)

## Repository Integration

### ForgeOS Ecosystem Integration

The ForgeOS toolchain repository is designed to integrate seamlessly with the broader ForgeOS ecosystem:

#### 1. forge-os (Main Repository)

**Integration**: Toolchain as submodule  
**Purpose**: Cross-compilation toolchains for ForgeOS builds  
**Usage**: Kernel, userland, and system builds

```bash
# In forge-os repository
git submodule add https://github.com/your-org/forgeos-toolchain.git toolchains
git submodule update --init --recursive

# Use toolchain in builds
source toolchains/artifacts/aarch64-musl/env.sh
make kernel
make busybox
```

#### 2. forge-packages (Package Repository)

**Integration**: Centralized package management  
**Purpose**: Offline package downloads for toolchain builds  
**Usage**: Package source tarballs and metadata

```bash
# In forge-toolchain repository
git submodule add https://github.com/your-org/forge-packages.git packages/forge-packages
git submodule update --init --recursive

# Download packages
make download-packages
```

#### 3. forge-profiles (Profile Repository)

**Integration**: Profile-specific toolchain usage  
**Purpose**: Different toolchain configurations per profile  
**Usage**: Core-min, server, edge profiles

```bash
# In forge-profiles repository
source ../forgeos-toolchain/artifacts/aarch64-musl/env.sh
make profile PROFILE=core-min
```

#### 4. forge-security (Security Repository)

**Integration**: Security-hardened toolchain builds  
**Purpose**: Security policies and hardening  
**Usage**: Secure toolchain configurations

```bash
# In forge-security repository
source ../forgeos-toolchain/artifacts/aarch64-musl/env.sh
make secure-toolchain
```

### Submodule Management

#### Adding Toolchain as Submodule

```bash
# Add toolchain submodule
git submodule add https://github.com/your-org/forgeos-toolchain.git toolchains

# Initialize submodule
git submodule update --init --recursive

# Update submodule
git submodule update --remote toolchains
```

#### Submodule Configuration

```bash
# Configure submodule
git config submodule.toolchains.url https://github.com/your-org/forgeos-toolchain.git
git config submodule.toolchains.branch main

# Update submodule to latest
git submodule update --remote --merge toolchains
```

#### Submodule Usage

```bash
# Build toolchain
cd toolchains
make toolchain

# Use toolchain in parent repository
source toolchains/artifacts/aarch64-musl/env.sh
make all
```

## Package System Integration

### forge-packages Integration

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

#### Package Download Integration

```bash
# Download packages from forge-packages
./scripts/download_packages.sh

# Download specific category
./scripts/download_packages.sh toolchain

# Download with force update
./scripts/download_packages.sh --force
```

#### Package Verification

```bash
# Verify package integrity
./scripts/verify_packages.sh

# Verify specific package
./scripts/verify_packages.sh binutils-2.42.tar.xz

# Verify with verbose output
./scripts/verify_packages.sh --verbose
```

### Package Manifest Integration

#### packages.json Structure

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
      }
    }
  }
}
```

#### Package Loading

```bash
# Load package manifest
PACKAGES_JSON="packages/forge-packages/metadata/packages.json"

# Parse package information
BINUTILS_VERSION=$(jq -r '.packages.toolchain.binutils.version' "$PACKAGES_JSON")
BINUTILS_URL=$(jq -r '.packages.toolchain.binutils.url' "$PACKAGES_JSON")
BINUTILS_SHA256=$(jq -r '.packages.toolchain.binutils.sha256' "$PACKAGES_JSON")
```

## Build System Integration

### Makefile Integration

#### Toolchain Build Targets

```makefile
# Toolchain build targets
toolchain: download-packages
	@echo "Building $(TOOLCHAIN) toolchain for $(ARCH)..."
	@./scripts/build_$(TOOLCHAIN).sh $(ARCH) $(BUILD_DIR) $(ARTIFACTS_DIR)

# Package management targets
download-packages:
	@echo "Downloading packages from forge-packages..."
	@./scripts/download_packages.sh

# Verification targets
verify: toolchain
	@echo "Verifying $(TOOLCHAIN) toolchain..."
	@./scripts/verify_toolchain.sh $(ARCH) $(TOOLCHAIN) $(ARTIFACTS_DIR)
```

#### Configuration Integration

```makefile
# Load build.json configuration
-include scripts/load_config.sh

# Default configuration
ARCH ?= aarch64
TOOLCHAIN ?= musl
BUILD_DIR ?= build
ARTIFACTS_DIR ?= artifacts
```

### Script Integration

#### Environment Loading

```bash
# Load toolchain environment
source artifacts/aarch64-musl/env.sh

# Use toolchain
$CC --version
$CXX --version
$AR --version
```

#### Build Integration

```bash
# Build with toolchain
export CC="$CROSS_COMPILE"gcc
export CXX="$CROSS_COMPILE"g++
export AR="$CROSS_COMPILE"ar

# Compile with toolchain
$CC -static -o program program.c
```

### Configuration Integration

#### build.json Integration

```json
{
  "build": {
    "directories": {
      "build": "build",
      "output": "artifacts",
      "packages": "packages/downloads"
    },
    "architecture": {
      "default": "aarch64",
      "supported": ["aarch64", "x86_64"]
    },
    "toolchain": {
      "types": ["musl", "gnu"],
      "default": "musl"
    },
    "repository": {
      "forge_packages_url": "https://github.com/your-org/forge-packages.git"
    }
  }
}
```

#### Configuration Loading

```bash
# Load configuration
source scripts/load_config.sh

# Use configuration variables
echo "Architecture: $ARCH"
echo "Toolchain: $TOOLCHAIN"
echo "Target: $TARGET"
echo "Cross-compile: $CROSS_COMPILE"
```

## CI/CD Integration

### GitHub Actions Integration

#### Workflow Configuration

```yaml
name: Build ForgeOS Toolchains

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build-toolchains:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        toolchain: [musl, gnu]
        architecture: [aarch64]

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      with:
        submodules: recursive

    - name: Set up environment
      run: |
        echo "SOURCE_DATE_EPOCH=$(date +%s)" >> $GITHUB_ENV
        echo "Toolchain: ${{ matrix.toolchain }}" >> $GITHUB_ENV
        echo "Architecture: ${{ matrix.architecture }}" >> $GITHUB_ENV

    - name: Check dependencies
      run: make check-dependencies

    - name: Download packages
      run: make download-packages

    - name: Build toolchain
      run: make toolchain TOOLCHAIN=${{ matrix.toolchain }} ARCH=${{ matrix.architecture }}

    - name: Verify toolchain
      run: make verify ARCH=${{ matrix.architecture }} TOOLCHAIN=${{ matrix.toolchain }}

    - name: Test toolchain
      run: make test ARCH=${{ matrix.architecture }} TOOLCHAIN=${{ matrix.toolchain }}

    - name: Upload artifacts
      uses: actions/upload-artifact@v4
      with:
        name: toolchain-${{ matrix.toolchain }}-${{ matrix.architecture }}-${{ matrix.os }}
        path: artifacts/
        retention-days: 7
```

#### Package Management in CI/CD

```yaml
    - name: Setup forge-packages
      run: |
        git clone https://github.com/your-org/forge-packages.git packages/forge-packages
        cd packages/forge-packages
        ./scripts/download_packages.sh

    - name: Build with offline packages
      run: |
        export PACKAGES_DIR="packages/forge-packages/packages"
        make toolchain
```

### Artifact Management

#### Artifact Upload

```yaml
    - name: Upload toolchain artifacts
      uses: actions/upload-artifact@v4
      with:
        name: toolchain-${{ matrix.toolchain }}-${{ matrix.architecture }}
        path: artifacts/
        retention-days: 30

    - name: Upload build report
      uses: actions/upload-artifact@v4
      with:
        name: build-report
        path: build-report.md
        retention-days: 30
```

#### Artifact Download

```yaml
    - name: Download toolchain artifacts
      uses: actions/download-artifact@v4
      with:
        name: toolchain-musl-aarch64
        path: artifacts/
```

### Integration Testing

#### Toolchain Testing

```yaml
    - name: Test toolchain integration
      run: |
        # Test musl toolchain
        source artifacts/aarch64-musl/env.sh
        echo 'int main(){return 0;}' | $CC -x c - -o /tmp/test_musl
        file /tmp/test_musl
        
        # Test glibc toolchain
        source artifacts/aarch64-gnu/env.sh
        echo 'int main(){return 0;}' | $CC -x c - -o /tmp/test_gnu
        file /tmp/test_gnu
```

#### Cross-Platform Testing

```yaml
    - name: Test cross-platform builds
      run: |
        # Test Linux builds
        make toolchain TOOLCHAIN=musl ARCH=aarch64
        
        # Test macOS builds (if on macOS)
        if [[ "$RUNNER_OS" == "macOS" ]]; then
          make toolchain TOOLCHAIN=gnu ARCH=aarch64
        fi
```

## External Project Integration

### Standalone Project Integration

#### Toolchain as Dependency

```bash
# Add toolchain as git submodule
git submodule add https://github.com/your-org/forgeos-toolchain.git toolchains

# Initialize submodule
git submodule update --init --recursive

# Build toolchain
cd toolchains
make toolchain

# Use toolchain in project
cd ..
source toolchains/artifacts/aarch64-musl/env.sh
make build
```

#### Package Management

```bash
# Download packages
cd toolchains
make download-packages

# Build offline
make toolchain

# Use in project
cd ..
source toolchains/artifacts/aarch64-musl/env.sh
make build
```

### Docker Integration

#### Dockerfile Example

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    tar \
    git \
    jq

# Clone toolchain repository
RUN git clone https://github.com/your-org/forgeos-toolchain.git /toolchains

# Build toolchain
WORKDIR /toolchains
RUN make download-packages
RUN make toolchain TOOLCHAIN=musl ARCH=aarch64

# Set up environment
ENV PATH="/toolchains/artifacts/aarch64-musl/bin:$PATH"
ENV CC="aarch64-linux-musl-gcc"
ENV CXX="aarch64-linux-musl-g++"
ENV AR="aarch64-linux-musl-ar"

# Build project
WORKDIR /project
COPY . .
RUN make build
```

#### Docker Compose Example

```yaml
version: '3.8'

services:
  toolchain:
    build: .
    volumes:
      - ./toolchains:/toolchains
      - ./artifacts:/artifacts
    environment:
      - ARCH=aarch64
      - TOOLCHAIN=musl
    command: make toolchain

  build:
    build: .
    depends_on:
      - toolchain
    volumes:
      - ./toolchains:/toolchains
      - ./artifacts:/artifacts
    environment:
      - CC=aarch64-linux-musl-gcc
      - CXX=aarch64-linux-musl-g++
    command: make build
```

### CMake Integration

#### CMakeLists.txt Example

```cmake
# Find toolchain
set(TOOLCHAIN_PATH "${CMAKE_SOURCE_DIR}/toolchains/artifacts/aarch64-musl")
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER "${TOOLCHAIN_PATH}/bin/aarch64-linux-musl-gcc")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_PATH}/bin/aarch64-linux-musl-g++")

# Set sysroot
set(CMAKE_SYSROOT "${TOOLCHAIN_PATH}")

# Set compiler flags
set(CMAKE_C_FLAGS "-static -Os")
set(CMAKE_CXX_FLAGS "-static -Os")

# Find packages
find_package(PkgConfig REQUIRED)
pkg_check_modules(REQUIRED REQUIRED)

# Add executable
add_executable(program main.c)
target_link_libraries(program ${REQUIRED_LIBRARIES})
```

### Makefile Integration

#### Makefile Example

```makefile
# Toolchain configuration
TOOLCHAIN_PATH := toolchains/artifacts/aarch64-musl
CC := $(TOOLCHAIN_PATH)/bin/aarch64-linux-musl-gcc
CXX := $(TOOLCHAIN_PATH)/bin/aarch64-linux-musl-g++
AR := $(TOOLCHAIN_PATH)/bin/aarch64-linux-musl-ar

# Compiler flags
CFLAGS := -static -Os -fno-stack-protector
CXXFLAGS := -static -Os -fno-stack-protector
LDFLAGS := -static

# Build targets
all: program

program: main.c
	$(CC) $(CFLAGS) -o program main.c $(LDFLAGS)

clean:
	rm -f program

.PHONY: all clean
```

## Troubleshooting

### Common Integration Issues

#### 1. Submodule Issues

**Error**: `Submodule not found`  
**Solution**: Initialize submodules

```bash
# Initialize submodules
git submodule update --init --recursive

# Update submodules
git submodule update --remote --merge
```

#### 2. Toolchain Not Found

**Error**: `Toolchain not found`  
**Solution**: Build toolchain first

```bash
# Build toolchain
cd toolchains
make toolchain

# Verify toolchain
make verify
```

#### 3. Package Download Failures

**Error**: `Package download failed`  
**Solution**: Check network and package URLs

```bash
# Check network connectivity
curl -I https://ftp.gnu.org/gnu/binutils/

# Check package URLs
jq '.packages.toolchain.binutils.url' packages/forge-packages/metadata/packages.json

# Retry download
make download-packages
```

#### 4. Build Integration Failures

**Error**: `Build integration failed`  
**Solution**: Check environment and paths

```bash
# Check environment
source toolchains/artifacts/aarch64-musl/env.sh
echo $CC
echo $CXX
echo $AR

# Test toolchain
$CC --version
$CXX --version
$AR --version
```

### Debug Information

#### Enable Debug Output

```bash
# Enable debug output
export DEBUG=1
make toolchain

# Enable verbose output
./scripts/verify_toolchain.sh --verbose

# Check configuration
./scripts/load_config.sh
```

#### Integration Logs

**Location**: `build.log`  
**Content**: Build output, errors, warnings  
**Usage**: Debug integration issues

```bash
# Monitor build progress
tail -f build.log

# Check for errors
grep -i error build.log

# Check for warnings
grep -i warning build.log
```

### Performance Optimization

#### Parallel Builds

**Default**: Use all available CPU cores  
**Override**: Set MAKE_JOBS environment variable

```bash
# Use 4 parallel jobs
export MAKE_JOBS=4
make toolchain

# Use all CPU cores
export MAKE_JOBS=$(nproc)
make toolchain
```

#### Build Caching

**Location**: `build/` directory  
**Purpose**: Cache build artifacts for faster rebuilds  
**Clean**: `make clean` to remove cache

```bash
# Clean build cache
make clean

# Clean all artifacts
make clean-all
```

## Best Practices

### 1. Use Submodules for Integration

```bash
# Add toolchain as submodule
git submodule add https://github.com/your-org/forgeos-toolchain.git toolchains

# Initialize submodule
git submodule update --init --recursive
```

### 2. Build Toolchain First

```bash
# Build toolchain
cd toolchains
make toolchain

# Verify toolchain
make verify
```

### 3. Use Offline Packages

```bash
# Download packages
make download-packages

# Build offline
make toolchain
```

### 4. Test Integration

```bash
# Test toolchain
make test

# Test compilation
source artifacts/aarch64-musl/env.sh
echo 'int main(){return 0;}' | $CC -x c - -o /tmp/test
```

### 5. Clean Build Artifacts

```bash
# Clean build artifacts
make clean

# Clean all artifacts
make clean-all
```

## Conclusion

The ForgeOS toolchain integration provides a robust, flexible system for integrating cross-compilation toolchains with other projects and repositories. The comprehensive integration support enables efficient, reproducible builds across the ForgeOS ecosystem.

For more information, see:
- [Toolchain Build Process](toolchain-build-process.md)
- [Package Management](package-management.md)
- [Main README](../README.md)
