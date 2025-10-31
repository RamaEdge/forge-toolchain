# ForgeOS Toolchain Quick Start

## Prerequisites

- GCC/G++ compiler
- Make, cURL, tar, jq
- 4GB+ RAM, 10GB+ disk space

## Build Workflow

```bash
# 1. Check dependencies
make check-dependencies

# 2. Download packages (once)
make download-packages

# 3. Build toolchain
make toolchain              # Build musl (default)
make toolchain TOOLCHAIN=gnu  # Build glibc

# 4. Verify
make verify

# 5. Use toolchain
export PATH="$(pwd)/artifacts/toolchain/aarch64-musl/bin:$PATH"
aarch64-linux-musl-gcc --version
```

## Available Targets

- `make toolchain` - Build toolchain (musl default)
- `make all-toolchains` - Build both musl and glibc
- `make verify` - Verify toolchain works
- `make clean` - Clean build directory
- `make clean-all` - Clean everything

## Toolchain Types

**musl** (default):
- Target: `aarch64-linux-musl`
- Static linking, minimal size
- Best for edge devices

**glibc** (gnu):
- Target: `aarch64-linux-gnu`
- Full compatibility
- Best for servers

## Configuration

Edit `build.json` to:
- Change package versions
- Update forge-packages release version
- Modify build settings

## Troubleshooting

```bash
# Missing dependencies
make check-dependencies

# Build failed
make clean
make toolchain

# Package download failed
rm -rf packages/downloads/*
make download-packages
```

See main [README](../README.md) for more details.


