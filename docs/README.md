# ForgeOS Toolchain Documentation

**Version**: 1.0.0  
**Last Updated**: 2025-01-01  
**Status**: Complete

## Overview

This documentation provides comprehensive information about the ForgeOS toolchain build system, package management, and integration with the broader ForgeOS ecosystem.

## Table of Contents

### 📚 Core Documentation

1. **[Toolchain Build Process](toolchain-build-process.md)**
   - Complete guide to building ForgeOS cross-compilation toolchains
   - Architecture overview and build flow
   - Toolchain types (musl, glibc) and configuration
   - Build scripts and verification process

2. **[Package Management](package-management.md)**
   - Comprehensive package management system
   - Package sources (forge-packages, internet downloads)
   - Integrity verification and offline build support
   - Package configuration and troubleshooting

3. **[Integration Guide](integration-guide.md)**
   - Integration with ForgeOS ecosystem repositories
   - CI/CD integration and external project integration
   - Docker, CMake, and Makefile integration
   - Troubleshooting and best practices

### 🏗️ Architecture Overview

```
forge-toolchain/
├── docs/                       # Documentation
│   ├── README.md              # This file
│   ├── toolchain-build-process.md
│   ├── package-management.md
│   └── integration-guide.md
├── scripts/                    # Build and management scripts
│   ├── build_musl.sh          # musl toolchain builder
│   ├── build_glibc.sh          # glibc toolchain builder
│   ├── build_all.sh            # Build all toolchains
│   ├── download_packages.sh    # Package downloader
│   ├── check_dependencies.sh   # Dependency checker
│   ├── verify_toolchain.sh     # Toolchain verifier
│   ├── test_toolchain.sh       # Toolchain tester
│   └── load_config.sh          # Configuration loader
├── configs/                    # Toolchain configurations
│   ├── musl-config.mk          # musl configuration
│   └── glibc-config.mk         # glibc configuration
├── artifacts/                  # Build outputs (gitignored)
│   ├── aarch64-musl/          # musl toolchain
│   └── aarch64-gnu/           # glibc toolchain
├── packages/                   # Package downloads (gitignored)
│   └── downloads/             # Downloaded packages
├── build.json                 # Build configuration
├── Makefile                   # Main build orchestrator
└── README.md                  # Project documentation
```

### 🚀 Quick Start

#### 1. Build Toolchain

```bash
# Build musl toolchain (default)
make toolchain

# Build glibc toolchain
make toolchain TOOLCHAIN=gnu

# Build all toolchains
make all-toolchains
```

#### 2. Download Packages

```bash
# Download packages from forge-packages
make download-packages

# Download specific category
./scripts/download_packages.sh toolchain
```

#### 3. Verify Toolchain

```bash
# Verify toolchain
make verify

# Test toolchain
make test
```

### 📦 Package Management

#### Package Sources

- **forge-packages Repository**: Centralized package management
- **Internet Downloads**: Fallback when forge-packages not available
- **Local Cache**: Offline build support

#### Package Categories

- **Toolchain**: binutils, gcc, musl, glibc, musl-cross-make
- **Kernel**: Linux kernel source and headers
- **Userland**: busybox, iproute2, chrony
- **System**: dropbear, nftables, apk-tools

#### Package Verification

- **SHA256 Checksums**: Cryptographic integrity verification
- **GPG Signatures**: Digital signature verification
- **Package Manifest**: Centralized package metadata

### 🔧 Toolchain Types

#### musl Toolchain (Default)

- **Target**: `aarch64-linux-musl`
- **Cross-compile**: `aarch64-linux-musl-`
- **Features**: Static linking, minimal dependencies, edge-optimized
- **Use Case**: Edge devices, embedded systems

#### glibc Toolchain (Optional)

- **Target**: `aarch64-linux-gnu`
- **Cross-compile**: `aarch64-linux-gnu-`
- **Features**: Full compatibility, dynamic linking, server-optimized
- **Use Case**: Server applications, compatibility

### 🌐 Integration

#### ForgeOS Ecosystem

- **forge-os**: Main distribution with toolchain integration
- **forge-packages**: Centralized package management
- **forge-profiles**: Profile-specific toolchain usage
- **forge-security**: Security-hardened toolchain builds

#### External Projects

- **Git Submodules**: Toolchain as dependency
- **Docker Integration**: Containerized builds
- **CMake Integration**: CMake toolchain files
- **Makefile Integration**: Custom build systems

### 🔄 CI/CD Integration

#### GitHub Actions

- **Automated Builds**: Cross-platform toolchain builds
- **Package Management**: forge-packages integration
- **Artifact Upload**: Toolchain distribution
- **Integration Testing**: Toolchain verification

#### Build Matrix

- **Platforms**: Ubuntu, macOS
- **Toolchains**: musl, glibc
- **Architectures**: aarch64, x86_64

### 📋 Configuration

#### build.json

```json
{
  "metadata": {
    "version": "1.0.0",
    "description": "ForgeOS Toolchain Build Configuration"
  },
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
    }
  }
}
```

#### Environment Variables

```bash
# Architecture and toolchain
export ARCH=aarch64
export TOOLCHAIN=musl

# Build directories
export BUILD_DIR=build
export ARTIFACTS_DIR=artifacts
export PACKAGES_DIR=packages/downloads

# Reproducible builds
export SOURCE_DATE_EPOCH=$(date +%s)
```

### 🛠️ Build Scripts

#### Core Scripts

- **build_musl.sh**: Build musl toolchain
- **build_glibc.sh**: Build glibc toolchain
- **build_all.sh**: Build all toolchains
- **download_packages.sh**: Download packages
- **check_dependencies.sh**: Check build dependencies
- **verify_toolchain.sh**: Verify toolchain
- **test_toolchain.sh**: Test toolchain
- **load_config.sh**: Load configuration

#### Usage Examples

```bash
# Build specific toolchain
./scripts/build_musl.sh aarch64 build artifacts

# Download packages
./scripts/download_packages.sh

# Check dependencies
./scripts/check_dependencies.sh

# Verify toolchain
./scripts/verify_toolchain.sh aarch64 musl artifacts

# Test toolchain
./scripts/test_toolchain.sh aarch64 musl artifacts
```

### 🔍 Troubleshooting

#### Common Issues

1. **Missing Dependencies**: Install build dependencies
2. **Package Download Failures**: Check network connectivity
3. **Build Failures**: Check build logs and dependencies
4. **Toolchain Verification Failures**: Check toolchain installation

#### Debug Information

```bash
# Enable debug output
export DEBUG=1
make toolchain

# Check configuration
./scripts/load_config.sh

# Verify packages
./scripts/verify_packages.sh --verbose
```

### 📖 Best Practices

#### 1. Use forge-packages for Offline Builds

```bash
# Download packages once
make download-packages

# Build offline
make toolchain
```

#### 2. Verify Toolchain After Build

```bash
# Build and verify
make toolchain
make verify
```

#### 3. Use Reproducible Builds

```bash
# Set SOURCE_DATE_EPOCH for reproducible builds
export SOURCE_DATE_EPOCH=$(date +%s)
make toolchain
```

#### 4. Test Toolchain Functionality

```bash
# Build and test
make toolchain
make test
```

#### 5. Clean Build Artifacts

```bash
# Clean build artifacts
make clean

# Clean all artifacts
make clean-all
```

### 📚 Additional Resources

#### Documentation Links

- **[Toolchain Build Process](toolchain-build-process.md)**: Complete build guide
- **[Package Management](package-management.md)**: Package system documentation
- **[Integration Guide](integration-guide.md)**: Integration documentation
- **[Main README](../README.md)**: Project overview

#### External Resources

- **[ForgeOS Main Repository](https://github.com/your-org/forgeos)**: Main ForgeOS distribution
- **[forge-packages Repository](https://github.com/your-org/forge-packages)**: Package management
- **[ForgeOS Documentation](https://docs.forgeos.org)**: Complete ForgeOS documentation

### 🤝 Contributing

#### Development Setup

```bash
# Clone repository
git clone https://github.com/your-org/forgeos-toolchain.git
cd forgeos-toolchain

# Build toolchain
make toolchain

# Test changes
make test
```

#### Contribution Guidelines

1. **Fork Repository**: Create your own fork
2. **Create Branch**: Create feature branch
3. **Make Changes**: Implement your changes
4. **Test Changes**: Verify functionality
5. **Submit PR**: Create pull request

### 📄 License

This project is licensed under the same terms as ForgeOS.

### 🆘 Support

For issues and questions:
- Create an issue in this repository
- Check the troubleshooting section
- Review the documentation
- Contact the ForgeOS team

---

**ForgeOS Toolchain Repository**  
*Lightweight Linux forged for the edge*
