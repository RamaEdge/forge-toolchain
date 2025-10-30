#!/bin/bash
# ForgeOS Toolchain Common Library
# Shared utilities for all toolchain scripts

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

# Project root detection
detect_project_root() {
    if ! PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
        PROJECT_ROOT="$(dirname "$script_dir")"
        log_warning "Not in a git repository. Using fallback project root detection."
        log_info "Project root: $PROJECT_ROOT"
    fi
    export PROJECT_ROOT
}

# Toolchain configuration helper
# Usage: get_toolchain_config <arch> <toolchain>
# Sets: TARGET, CROSS_COMPILE
get_toolchain_config() {
    local arch="$1"
    local toolchain="$2"
    
    case "$toolchain" in
        "musl")
            export TARGET="$arch-linux-musl"
            export CROSS_COMPILE="$TARGET-"
            ;;
        "gnu"|"glibc")
            export TARGET="$arch-linux-gnu"
            export CROSS_COMPILE="$TARGET-"
            ;;
        *)
            log_error "Unknown toolchain: $toolchain"
            log_info "Supported toolchains: musl, gnu, glibc"
            return 1
            ;;
    esac
    
    return 0
}

