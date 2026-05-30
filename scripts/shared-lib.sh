#!/usr/bin/env bash
# scripts/shared-lib.sh - Shared colors and helper functions
# Source this file; do not execute directly.

RED='\033[0;31m'
YEL='\033[1;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
BLD='\033[1m'
RST='\033[0m'

info()    { echo -e "${CYN}[*]${RST} $*"; }
success() { echo -e "${GRN}[✓]${RST} $*"; }
warn()    { echo -e "${YEL}[!]${RST} $*"; }
error()   { echo -e "${RED}[✗]${RST} $*"; exit 1; }

confirm() {
    local msg="$1"
    local default="${2:-n}"
    local prompt
    [[ "$default" == "y" ]] && prompt="[Y/n]" || prompt="[y/N]"
    echo -en "${BLD}$msg $prompt${RST} "
    read -r answer
    answer="${answer:-$default}"
    [[ "${answer,,}" == "y" ]]
}

: "${STATE_FILE:?STATE_FILE is not set. Run edid_overclock.sh instead.}"

# Privilege escalation helper
if command -v sudo &>/dev/null; then
    PRIV="sudo"
elif command -v doas &>/dev/null; then
    PRIV="doas"
else
    PRIV=""
fi

elevate() { ${PRIV:?No sudo or doas found.} "$@"; }

state_load() {
    [[ -f "$STATE_FILE" ]] || error "State file not found. Did you run the previous steps?"
    source "$STATE_FILE"
}
