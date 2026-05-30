#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/shared-lib.sh"

# 1. DEPENDENCY CHECK
info "Checking required tools..."

detect_pkg_manager() {
    if   command -v pacman &>/dev/null; then echo "pacman"
    elif command -v apt    &>/dev/null; then echo "apt"
    elif command -v dnf    &>/dev/null; then echo "dnf"
    else echo "unknown"; fi
}

install_pkg() {
    local pkg="$1" pm
    pm=$(detect_pkg_manager)
    case "$pm" in
        pacman) elevate pacman -S --noconfirm "$pkg" ;;
        apt)    elevate apt install -y "$pkg" ;;
        dnf)    elevate dnf install -y "$pkg" ;;
        *)      error "No package manager found. Install '$pkg' manually." ;;
    esac
}

check_dep() {
    local cmd="$1" pkg="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        warn "'$cmd' not found."
        confirm "Install '$pkg'?" "y" \
            && install_pkg "$pkg" \
            || error "Cannot continue without '$cmd'."
    else
        success "$cmd found"
    fi
}

check_dep "edid-decode" "edid-decode"
check_dep "cvt"         "xorg-server"
check_dep "python3"     "python3"
