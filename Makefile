# ForgeOS Toolchain Build System
# Cross-compilation toolchain building for ForgeOS
# Independent repository for toolchain management

# =============================================================================
# CONFIGURATION
# =============================================================================

# Load build.json configuration
# Note: Configuration is loaded via scripts/load_config.sh when needed

# Default configuration (can be overridden)
ARCH ?= aarch64
TOOLCHAIN ?= musl
BUILD_DIR ?= build
ARTIFACTS_DIR ?= artifacts
SOURCE_DATE_EPOCH ?= $(shell date +%s)

# Toolchain-specific settings
ifeq ($(TOOLCHAIN),musl)
    TARGET := $(ARCH)-linux-musl
    CROSS_COMPILE := $(TARGET)-
    OUTPUT_DIR := $(ARTIFACTS_DIR)/$(ARCH)-musl
else ifeq ($(TOOLCHAIN),gnu)
    TARGET := $(ARCH)-linux-gnu
    CROSS_COMPILE := $(TARGET)-
    OUTPUT_DIR := $(ARTIFACTS_DIR)/$(ARCH)-gnu
else
    $(error Unknown toolchain: $(TOOLCHAIN). Supported: musl, gnu)
endif

# Build configuration
export ARCH
export TOOLCHAIN
export TARGET
export CROSS_COMPILE
export OUTPUT_DIR
export SOURCE_DATE_EPOCH

# =============================================================================
# MAIN TARGETS
# =============================================================================

# Default target
all: download-packages toolchain

# Build specific toolchain
toolchain: check-dependencies
	@echo "Building $(TOOLCHAIN) toolchain for $(ARCH)..."
	@./scripts/build_$(TOOLCHAIN).sh $(ARCH) $(BUILD_DIR) $(ARTIFACTS_DIR)
	@echo "Toolchain build complete: $(OUTPUT_DIR)"

# Build all toolchains
all-toolchains: check-dependencies
	@echo "Building all toolchains..."
	@./scripts/build_all.sh $(ARCH) $(BUILD_DIR) $(ARTIFACTS_DIR)
	@echo "All toolchains built successfully"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "Build artifacts cleaned"

# Clean all artifacts
clean-all: clean
	@echo "Cleaning all artifacts..."
	@rm -rf $(ARTIFACTS_DIR)
	@echo "All artifacts cleaned"

# Verify toolchain
verify: toolchain
	@echo "Verifying $(TOOLCHAIN) toolchain..."
	@./scripts/verify_toolchain.sh $(ARCH) $(TOOLCHAIN) $(ARTIFACTS_DIR)
	@echo "Toolchain verification complete"

# Test toolchain
test: toolchain
	@echo "Testing $(TOOLCHAIN) toolchain..."
	@./scripts/test_toolchain.sh $(ARCH) $(TOOLCHAIN) $(ARTIFACTS_DIR)
	@echo "Toolchain test complete"

# =============================================================================
# PACKAGE MANAGEMENT
# =============================================================================

# Download packages from forge-packages
download-packages:
	@echo "Downloading packages from forge-packages..."
	@./scripts/download_packages.sh
	@echo "Package download complete"

# Clean downloaded packages
clean-packages:
	@echo "Cleaning downloaded packages..."
	@rm -rf packages/downloads
	@echo "Downloaded packages cleaned"

# =============================================================================
# DEPENDENCY CHECKS
# =============================================================================

check-dependencies:
	@echo "Checking build dependencies..."
	@./scripts/check_dependencies.sh
	@echo "Dependencies check complete"

# =============================================================================
# PLATFORM-SPECIFIC TARGETS
# =============================================================================

# Linux-specific builds
linux: check-dependencies
	@echo "Building for Linux platform..."
	@./scripts/build_$(TOOLCHAIN).sh $(ARCH) $(BUILD_DIR) $(ARTIFACTS_DIR) linux
	@echo "Linux build complete"

# macOS-specific builds
macos: check-dependencies
	@echo "Building for macOS platform..."
	@./scripts/build_$(TOOLCHAIN).sh $(ARCH) $(BUILD_DIR) $(ARTIFACTS_DIR) macos
	@echo "macOS build complete"

# =============================================================================
# HELP AND INFO
# =============================================================================

help:
	@echo "ForgeOS Toolchain Build System"
	@echo ""
	@echo "Usage: make [target] [options]"
	@echo ""
	@echo "Targets:"
	@echo "  toolchain        Build specific toolchain (default: musl)"
	@echo "  all-toolchains   Build all toolchains"
	@echo "  verify          Build and verify toolchain"
	@echo "  test            Build and test toolchain"
	@echo "  download-packages  Download packages from forge-packages"
	@echo "  clean-packages  Clean downloaded packages"
	@echo "  clean           Clean build artifacts"
	@echo "  clean-all       Clean all artifacts"
	@echo "  check-dependencies  Check build dependencies"
	@echo "  linux           Build for Linux platform"
	@echo "  macos           Build for macOS platform"
	@echo "  help            Show this help"
	@echo ""
	@echo "Options:"
	@echo "  ARCH=arch       Target architecture (default: aarch64)"
	@echo "  TOOLCHAIN=type  Toolchain type (default: musl)"
	@echo "  BUILD_DIR=dir   Build directory (default: build)"
	@echo "  ARTIFACTS_DIR=dir  Artifacts directory (default: artifacts)"
	@echo ""
	@echo "Examples:"
	@echo "  make toolchain                    # Build musl toolchain for aarch64"
	@echo "  make toolchain ARCH=x86_64        # Build musl toolchain for x86_64"
	@echo "  make toolchain TOOLCHAIN=gnu      # Build glibc toolchain for aarch64"
	@echo "  make all-toolchains               # Build all toolchains"
	@echo "  make download-packages            # Download packages from forge-packages"
	@echo "  make verify                       # Build and verify toolchain"
	@echo "  make test                         # Build and test toolchain"

# Show current configuration
config:
	@echo "ForgeOS Toolchain Configuration:"
	@echo "  Architecture: $(ARCH)"
	@echo "  Toolchain: $(TOOLCHAIN)"
	@echo "  Target: $(TARGET)"
	@echo "  Cross-compile: $(CROSS_COMPILE)"
	@echo "  Build directory: $(BUILD_DIR)"
	@echo "  Artifacts directory: $(ARTIFACTS_DIR)"
	@echo "  Output directory: $(OUTPUT_DIR)"
	@echo "  Source date epoch: $(SOURCE_DATE_EPOCH)"

.PHONY: all toolchain all-toolchains clean clean-all verify test download-packages clean-packages check-dependencies linux macos help config
