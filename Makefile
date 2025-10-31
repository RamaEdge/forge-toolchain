# ForgeOS Toolchain Build System
# Cross-compilation toolchain building for ForgeOS
# Independent repository for toolchain management
#
# Configuration Source: build.json
# - All package URLs are defined in build.json pointing to forge-packages releases
# - All package versions are centralized in build.json
# - Single source of truth for all dependencies
#
# Package Management Strategy:
# - forge-packages releases contain all pre-built packages
# - Packages are downloaded via GitHub releases (faster, no cloning needed)
# - Local copies used during build (offline-capable after download)
# - All URLs point to forge-packages GitHub releases (forge-packages repo)

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
    OUTPUT_DIR := $(ARTIFACTS_DIR)/toolchain/$(ARCH)-musl
else ifeq ($(TOOLCHAIN),gnu)
    TARGET := $(ARCH)-linux-gnu
    CROSS_COMPILE := $(TARGET)-
    OUTPUT_DIR := $(ARTIFACTS_DIR)/toolchain/$(ARCH)-gnu
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

# Color output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m

# =============================================================================
# MAIN TARGETS
# =============================================================================

# Default target: download packages and build toolchain
all: download-packages toolchain

# Build specific toolchain
toolchain: check-dependencies
	@echo "Building $(TOOLCHAIN) toolchain for $(ARCH)..."
	@LOG_TO_FILE=1 ./scripts/build_toolchain.sh $(ARCH) $(TOOLCHAIN)
	@if [ -f "$(OUTPUT_DIR)/bin/$(TARGET)-gcc" ]; then \
		echo "$(GREEN)[✓]$(NC) Toolchain build complete: $(OUTPUT_DIR)"; \
	else \
		echo "$(RED)[✗]$(NC) ERROR: Toolchain not found at $(OUTPUT_DIR)"; \
		exit 1; \
	fi

# Build all toolchains (musl and gnu for both architectures)
all-toolchains: check-dependencies
	@echo "Building all toolchains..."
	@echo "$(BLUE)[1/2]$(NC) Building musl toolchain..."
	LOG_TO_FILE=1 ./scripts/build_toolchain.sh $(ARCH) musl
	@if [ -f "$(ARTIFACTS_DIR)/toolchain/$(ARCH)-musl/bin/$(ARCH)-linux-musl-gcc" ]; then \
		echo "$(GREEN)[✓]$(NC) musl toolchain built successfully"; \
	else \
		echo "$(RED)[✗]$(NC) ERROR: musl toolchain not found"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(BLUE)[2/2]$(NC) Building glibc toolchain..."
	LOG_TO_FILE=1 ./scripts/build_toolchain.sh $(ARCH) gnu
	@if [ -f "$(ARTIFACTS_DIR)/toolchain/$(ARCH)-gnu/bin/$(ARCH)-linux-gnu-gcc" ]; then \
		echo "$(GREEN)[✓]$(NC) glibc toolchain built successfully"; \
	else \
		echo "$(RED)[✗]$(NC) ERROR: glibc toolchain not found"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(GREEN)[✓]$(NC) All toolchains built successfully"
	@echo ""
	@echo "$(BLUE)[Summary]$(NC)"
	@echo "  musl:  $(ARTIFACTS_DIR)/toolchain/$(ARCH)-musl/bin/$(ARCH)-linux-musl-gcc"
	@echo "  glibc: $(ARTIFACTS_DIR)/toolchain/$(ARCH)-gnu/bin/$(ARCH)-linux-gnu-gcc"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf packages/downloads
	@rm -rf artifacts/
	@echo "Build artifacts and packages cleaned"

# Clean all artifacts including built toolchains
clean-all: clean
	@echo "Cleaning all artifacts..."
	@rm -rf $(ARTIFACTS_DIR)
	@echo "All artifacts cleaned"
	@rm -rf packages/extracted
	@rm -rf packages/downloads
	

# =============================================================================
# TOOLCHAIN VERIFICATION
# =============================================================================

# Verify toolchain build (includes testing)
verify: toolchain
	@echo "Verifying $(TOOLCHAIN) toolchain..."
	@LOG_TO_FILE=1 ./scripts/verify_toolchain.sh $(ARCH) $(TOOLCHAIN) $(ARTIFACTS_DIR)
	@echo "Toolchain verification complete"

# =============================================================================
# PACKAGE MANAGEMENT
# =============================================================================

# Download packages from forge-packages
download-packages:
	@echo "Downloading packages from forge-packages..."
	@LOG_TO_FILE=1 ./scripts/download_packages.sh
	@echo "Package download complete"

# =============================================================================
# RELEASE AND DISTRIBUTION
# =============================================================================

# Create and upload release archive to GitHub
# Reads version from build.json, creates minimal archives, and uploads
# Usage: make release
release:
	@LOG_TO_FILE=1 ./scripts/create_release.sh

# =============================================================================
# DEPENDENCY CHECKS
# =============================================================================

check-dependencies:
	@echo "Checking build dependencies..."
	@./scripts/check_dependencies.sh || { echo "$(RED)[✗]$(NC) Dependency check failed"; exit 1; }
	@echo "$(GREEN)[✓]$(NC) All dependencies check complete"

# =============================================================================
# HELP AND INFO
# =============================================================================

help:
	@echo "$(BLUE)ForgeOS Toolchain Build System$(NC)"
	@echo ""
	@echo "Usage: make [target] [options]"
	@echo ""
	@echo "$(BLUE)Build Targets:$(NC)"
	@echo "  toolchain            Build specific toolchain (default: musl)"
	@echo "  all-toolchains       Build all toolchains (musl and gnu)"
	@echo "  verify               Build and verify toolchain"
	@echo ""
	@echo "$(BLUE)Package Management:$(NC)"
	@echo "  download-packages    Download all packages from forge-packages"
	@echo ""
	@echo "$(BLUE)Release:$(NC)"
	@echo "  release              Create and upload GitHub release"
	@echo ""
	@echo "$(BLUE)Cleanup:$(NC)"
	@echo "  clean                Clean build artifacts and packages"
	@echo "  clean-all            Clean all artifacts including toolchains"
	@echo ""
	@echo "$(BLUE)Information:$(NC)"
	@echo "  config               Show current build configuration"
	@echo "  check-dependencies   Check build dependencies"
	@echo "  help                 Show this help"
	@echo ""
	@echo "$(BLUE)Options:$(NC)"
	@echo "  ARCH=arch       Target architecture (default: aarch64)"
	@echo "  TOOLCHAIN=type  Toolchain type: musl, gnu (default: musl)"
	@echo "  BUILD_DIR=dir   Build directory (default: build)"
	@echo "  ARTIFACTS_DIR=dir  Artifacts directory (default: artifacts)"
	@echo "  VERSION=tag     Release/package version"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make toolchain                            # Build musl/aarch64"
	@echo "  make toolchain ARCH=x86_64 TOOLCHAIN=gnu  # Build gnu/x86_64"
	@echo "  make download-packages                    # Download all packages"
	@echo "  make verify                               # Build and verify"
	@echo "  make release                              # Create GitHub release"

# Show current configuration
config:
	@echo "$(BLUE)ForgeOS Toolchain Configuration:$(NC)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Toolchain: $(TOOLCHAIN)"
	@echo "  Target: $(TARGET)"
	@echo "  Cross-compile: $(CROSS_COMPILE)"
	@echo "  Build directory: $(BUILD_DIR)"
	@echo "  Artifacts directory: $(ARTIFACTS_DIR)"
	@echo "  Output directory: $(OUTPUT_DIR)"
	@echo "  Source date epoch: $(SOURCE_DATE_EPOCH)"
	@echo ""
	@echo "$(BLUE)Package Configuration:$(NC)"
	@jq '.build.repository' build.json

.PHONY: all toolchain all-toolchains clean clean-all verify download-packages release check-dependencies config help
