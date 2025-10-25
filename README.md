# ForgeOS Toolchain Repository

Cross-compilation toolchain building for ForgeOS - lightweight Linux forged for the edge.

## Overview

This repository provides independent toolchain building capabilities for ForgeOS, supporting both musl and glibc-based cross-compilation toolchains. It's designed to be used as a submodule in the main ForgeOS repository.

## Features

- **Dual Toolchain Support**: musl (default) and glibc (compatibility)
- **Cross-Platform**: Linux and macOS build support
- **Reproducible Builds**: Deterministic toolchain generation
- **Independent CI/CD**: Separate build pipeline for toolchains
- **Version Management**: Pinned toolchain versions

## Quick Start

### Prerequisites

- GCC/G++ compiler
- Make (GNU Make on macOS)
- cURL for downloads
- Tar for extraction
- Bash shell
- 4GB+ RAM recommended
- 10GB+ disk space

### Build Toolchain

```bash
# Build musl toolchain (default)
make toolchain

# Build glibc toolchain
make toolchain TOOLCHAIN=gnu

# Build all toolchains
make all-toolchains

# Build for specific architecture
make toolchain ARCH=x86_64
```

### Use Toolchain

```bash
# Load musl toolchain environment
source artifacts/aarch64-musl/env.sh

# Load glibc toolchain environment
source artifacts/aarch64-gnu/env.sh

# Use combined environment
source artifacts/env.sh          # musl (default)
source artifacts/env.sh gnu      # glibc
```

## Architecture Support

### Currently Supported

- **aarch64**: Primary target for edge devices
- **x86_64**: Gateway and server targets

### Adding New Architectures

1. Update configuration files if needed
2. Test toolchain build: `make toolchain ARCH=<arch>`
3. Verify cross-compilation works
4. Update documentation

## Toolchain Types

### musl Toolchain (Default)

- **Target**: `aarch64-linux-musl`
- **Cross-compile**: `aarch64-linux-musl-`
- **Features**: Static linking, minimal dependencies
- **Use case**: Edge devices, embedded systems

### glibc Toolchain (Optional)

- **Target**: `aarch64-linux-gnu`
- **Cross-compile**: `aarch64-linux-gnu-`
- **Features**: Full compatibility, dynamic linking
- **Use case**: Server applications, compatibility

## Build Process

### musl Toolchain

1. **Download**: musl-cross-make source
2. **Configure**: Build configuration
3. **Build**: Compile toolchain components
4. **Install**: Install to artifacts directory
5. **Verify**: Test toolchain functionality

### glibc Toolchain

1. **Download**: binutils, GCC, glibc, Linux headers
2. **Build binutils**: Cross-assembler and linker
3. **Install headers**: Linux kernel headers
4. **Build glibc**: C library
5. **Build GCC**: Cross-compiler
6. **Verify**: Test toolchain functionality

## Configuration

### Environment Variables

- `ARCH`: Target architecture (default: aarch64)
- `TOOLCHAIN`: Toolchain type (default: musl)
- `BUILD_DIR`: Build directory (default: build)
- `ARTIFACTS_DIR`: Artifacts directory (default: artifacts)
- `SOURCE_DATE_EPOCH`: Reproducible build timestamp

### Configuration Files

- `configs/musl-config.mk`: musl toolchain configuration
- `configs/glibc-config.mk`: glibc toolchain configuration

## Usage Examples

### Basic Usage

```bash
# Build musl toolchain
make toolchain

# Build glibc toolchain
make toolchain TOOLCHAIN=gnu

# Build all toolchains
make all-toolchains
```

### Advanced Usage

```bash
# Build for specific architecture
make toolchain ARCH=x86_64

# Build with custom directories
make toolchain BUILD_DIR=custom-build ARTIFACTS_DIR=custom-artifacts

# Clean build artifacts
make clean

# Clean all artifacts
make clean-all
```

### Verification

```bash
# Verify toolchain
make verify

# Check dependencies
make check-dependencies

# Show configuration
make config
```

## Platform Support

### Linux

- **Requirements**: GCC, Make, cURL, Tar
- **Parallel jobs**: `nproc` cores
- **Memory**: 4GB+ recommended

### macOS

- **Requirements**: GCC, GNU Make, cURL, Tar
- **Parallel jobs**: `sysctl hw.ncpu` cores
- **Memory**: 4GB+ recommended

## CI/CD Integration

### GitHub Actions

```yaml
name: Build Toolchains
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build musl toolchain
        run: make toolchain
      - name: Build glibc toolchain
        run: make toolchain TOOLCHAIN=gnu
      - name: Verify toolchains
        run: make verify
```

### Local Development

```bash
# Check dependencies
make check-dependencies

# Build toolchain
make toolchain

# Verify toolchain
make verify

# Test compilation
source artifacts/aarch64-musl/env.sh
aarch64-linux-musl-gcc --version
```

## Integration with ForgeOS

### As Submodule

```bash
# In main ForgeOS repository
git submodule add https://github.com/your-org/forgeos-toolchain.git toolchains
git submodule update --init --recursive
```

### Usage in ForgeOS

```bash
# Build toolchain from ForgeOS
make -C toolchains toolchain

# Use toolchain in ForgeOS build
source toolchains/artifacts/aarch64-musl/env.sh
make kernel
```

## Troubleshooting

### Common Issues

1. **Missing dependencies**: Run `make check-dependencies`
2. **Build failures**: Check available memory and disk space
3. **Network issues**: Verify internet connectivity for downloads
4. **Platform issues**: Check platform-specific requirements

### Debug Information

```bash
# Show configuration
make config

# Check dependencies
make check-dependencies

# Verify toolchain
make verify

# Clean and rebuild
make clean-all
make toolchain
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the same terms as ForgeOS.

## Support

For issues and questions:
- Create an issue in this repository
- Check the main ForgeOS documentation
- Review the troubleshooting section

## Changelog

### v0.1.0 (Initial Release)

- musl toolchain support
- glibc toolchain support
- Cross-platform builds (Linux, macOS)
- Reproducible builds
- CI/CD integration
- Comprehensive documentation