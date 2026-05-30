#!/usr/bin/env bash
# edid_overclock.sh - LCD Refresh Rate Overclock Tool
# Use at your own risk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export STATE_FILE="/tmp/edid_state_$$"
source "$SCRIPT_DIR/scripts/shared-lib.sh"

# WARNING
clear
echo -e "${RED}${BLD}⚠️  DISCLAIMER / LIABILITY WAIVER${RST}"
echo
echo "  This operation may permanently damage your LCD panel."
echo "  Image corruption, panel death, and signal loss may occur."
echo "  You may void your warranty."
echo
echo "  You are solely responsible for any hardware damage,"
echo "  data loss, or other harm resulting from using this tool."
echo "  The developer accepts no liability whatsoever."
echo

confirm "I understand and accept all risks. I want to continue." "n" \
    || { echo "Cancelled."; exit 0; }
echo

# DETECT PATCHED EDID
FIRMWARE_EXISTS=0
CMDLINE_SET=0
[[ -f /lib/firmware/edid/edid_overclocked.bin ]] && FIRMWARE_EXISTS=1
grep -q "drm.edid_firmware" /proc/cmdline 2>/dev/null && CMDLINE_SET=1

if [[ "$FIRMWARE_EXISTS" -eq 1 || "$CMDLINE_SET" -eq 1 ]]; then
    if [[ "$FIRMWARE_EXISTS" -eq 1 && "$CMDLINE_SET" -eq 0 ]]; then
        warn "Firmware file found but kernel parameter is missing — previous overclock may be incomplete."
    elif [[ "$FIRMWARE_EXISTS" -eq 0 && "$CMDLINE_SET" -eq 1 ]]; then
        warn "Kernel parameter set but firmware file missing — system may be misconfigured."
    else
        warn "Patched EDID detected on this system."
    fi
    echo
    echo "  1) Revert to defaults"
    echo "  2) Overclock (apply new patch)"
    echo
    echo -en "${BLD}Your choice [1/2]: ${RST}"
    read -r CHOICE
    case "$CHOICE" in
        1) bash "$SCRIPT_DIR/scripts/revert.sh"; exit 0 ;;
        2) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
    echo
fi

STEPS=(
    "01_deps.sh:Dependency Check"
    "02_display.sh:Display Detection"
    "03_cvt.sh:CVT Calculation"
    "04_patch.sh:EDID Patch"
    "05_firmware.sh:Copy Firmware"
    "06_bootloader.sh:Boot Parameter"
    "07_initramfs.sh:Initramfs"
    "08_reboot.sh:Reboot"
)

for entry in "${STEPS[@]}"; do
    file="${entry%%:*}"
    name="${entry##*:}"
    echo
    confirm "Step: $name — Run?" "y" || { echo "Cancelled."; exit 0; }
    bash "$SCRIPT_DIR/scripts/$file"
done
