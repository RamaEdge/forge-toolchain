# ForgeOS musl Toolchain Configuration
# Configuration file for musl-based cross-compilation toolchain

# Toolchain type
TOOLCHAIN_TYPE := musl

# Default architecture
ARCH ?= aarch64

# Target configuration
TARGET := $(ARCH)-linux-musl
CROSS_COMPILE := $(TARGET)-

# Build configuration
BUILD_DIR ?= build
ARTIFACTS_DIR ?= artifacts
OUTPUT_DIR := $(ARTIFACTS_DIR)/$(ARCH)-musl

# musl-cross-make configuration
MUSL_CROSS_MAKE_VERSION := 0.9.11
MUSL_CROSS_MAKE_URL := https://github.com/richfelker/musl-cross-make/archive/v$(MUSL_CROSS_MAKE_VERSION).tar.gz

# Build flags for reproducible builds
COMMON_CFLAGS := -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables -Os
COMMON_CXXFLAGS := -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables -Os
COMMON_LDFLAGS := -Wl,--build-id=sha1

# musl-specific configuration
MUSL_CONFIG := --enable-shared --enable-static

# GCC configuration
GCC_CONFIG := --enable-languages=c,c++
GCC_CONFIG += --disable-multilib
GCC_CONFIG += --disable-libssp
GCC_CONFIG += --disable-libgomp
GCC_CONFIG += --disable-libmudflap
GCC_CONFIG += --disable-libsanitizer
GCC_CONFIG += --disable-libatomic
GCC_CONFIG += --disable-libquadmath
GCC_CONFIG += --disable-shared
GCC_CONFIG += --disable-threads
GCC_CONFIG += --disable-libstdcxx-pch

# Build environment
export ARCH
export TOOLCHAIN_TYPE
export TARGET
export CROSS_COMPILE
export OUTPUT_DIR
export COMMON_CFLAGS
export COMMON_CXXFLAGS
export COMMON_LDFLAGS
export MUSL_CONFIG
export GCC_CONFIG
