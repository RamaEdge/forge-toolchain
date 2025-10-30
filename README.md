# ForgeOS Toolchain Repository

Cross-compilation toolchains for ForgeOS - lightweight Linux forged for the edge.

## Overview

Independent toolchain builder for ForgeOS supporting musl (default) and glibc cross-compilation toolchains.

## Features

- **Dual Toolchain Support**: musl and glibc
- **Dynamic Package Discovery**: No hardcoded versions
- **Pre-extracted Packages**: Fast rebuilds
- **Reproducible Builds**: Deterministic generation
- **Simple Scripts**: Centralized utilities

## Quick Start

```bash
# 1. Check dependencies
make check-dependencies

# 2. Download and extract packages (once)
make download-packages

# 3. Build toolchain
make toolchain              # musl (default)
make toolchain TOOLCHAIN=gnu  # glibc

# 4. Verify
make verify

# 5. Use
export PATH="$(pwd)/artifacts/aarch64-musl/bin:$PATH"
aarch64-linux-musl-gcc --version
```

## Toolchain Types

**musl** (default) - `aarch64-linux-musl`:
- Static linking, minimal size
- Best for edge devices

**glibc** (gnu) - `aarch64-linux-gnu`:
- Dynamic linking, full compatibility
- Best for servers

## Architecture Support

- **aarch64**: Primary (edge devices)
- **x86_64**: Gateway/server

## Common Tasks

```bash
# Build both toolchains
make all-toolchains

# Build for x86_64
make toolchain ARCH=x86_64

# Clean and rebuild
make clean
make toolchain

# Clean everything
make clean-all
```

## Configuration

Edit `build.json` to:
- Update package versions
- Change forge-packages release version
- Modify build directories

## Platform Support

**Linux**: GCC, Make, cURL, tar, jq  
**macOS**: GCC, GNU Make, cURL, tar, jq

Parallel builds use all available CPU cores.

## ForgeOS Integration

Used as submodule in main ForgeOS repository:

```bash
# In forge-os
git submodule update --init toolchains
make -C toolchains toolchain
source toolchains/artifacts/aarch64-musl/env.sh
make kernel
```

## Troubleshooting

```bash
# Missing dependencies
make check-dependencies

# Build failed
make clean
make toolchain

# Package issues
rm -rf packages/downloads/*
make download-packages
```

## Documentation

- [Quick Start Guide](docs/QUICKSTART.md) - Get started quickly
- [Build Process](docs/BUILD-PROCESS.md) - How building works
- [Release Guide](docs/RELEASE-GUIDE.md) - Creating releases

## License

Licensed under the same terms as ForgeOS.