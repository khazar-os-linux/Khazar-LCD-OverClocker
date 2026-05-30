#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/shared-lib.sh"
state_load

# 7. INITRAMFS
detect_initramfs() {
    if   command -v mkinitcpio &>/dev/null; then echo "mkinitcpio"
    elif command -v dracut     &>/dev/null; then echo "dracut"
    else echo "unknown"; fi
}

INITRAMFS=$(detect_initramfs)
info "Initramfs system: $INITRAMFS"

if [[ "$INITRAMFS" == "mkinitcpio" ]]; then
    MKINIT_CONF="/etc/mkinitcpio.conf"
    if ! grep -q "edid_overclocked.bin" "$MKINIT_CONF"; then
        confirm "Add $FIRMWARE_FILE to initramfs FILES list?" "y" && {
            elevate sed -i "s|^FILES=(|FILES=($FIRMWARE_FILE |" "$MKINIT_CONF"
            elevate sed -i "s|FILES=( )|FILES=($FIRMWARE_FILE)|" "$MKINIT_CONF"
            success "mkinitcpio.conf updated."
        }
    else
        success "File already in FILES list."
    fi
    confirm "Run mkinitcpio -P?" "y" && {
        elevate mkinitcpio -P
        success "Initramfs rebuilt."
    }
elif [[ "$INITRAMFS" == "dracut" ]]; then
    DRACUT_CONF="/etc/dracut.conf.d/edid.conf"
    confirm "Create $DRACUT_CONF for dracut?" "y" && {
        echo "install_items+=\" $FIRMWARE_FILE \"" | elevate tee "$DRACUT_CONF" > /dev/null
        elevate dracut --force
        success "Dracut initramfs rebuilt."
    }
else
    warn "Initramfs system not detected. Add the firmware file manually."
fi
