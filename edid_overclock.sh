#!/usr/bin/env bash
# edid_overclock.sh - LCD Refresh Rate Overclock Tool
# Use at your own risk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export STATE_FILE="/tmp/edid_state_$$"
source "$SCRIPT_DIR/scripts/start.sh"

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
