#!/usr/bin/env bash
# scripts/revert.sh - Revert all EDID overclock changes
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/shared-lib.sh"

GRUB_CHANGED=0

# 1. Remove firmware files
FIRMWARE_DIR="/lib/firmware/edid"
if [[ -d "$FIRMWARE_DIR" ]]; then
    mapfile -t FILES < <(find "$FIRMWARE_DIR" -maxdepth 1 -type f 2>/dev/null)
    if [[ ${#FILES[@]} -gt 0 ]]; then
        info "Firmware files found in $FIRMWARE_DIR:"
        for f in "${FILES[@]}"; do echo "  $f"; done
        if confirm "Delete these files?" "y"; then
            elevate rm -f "${FILES[@]}"
            success "Firmware files removed."
        fi
    else
        info "No firmware files in $FIRMWARE_DIR."
    fi
else
    info "$FIRMWARE_DIR does not exist, skipping."
fi
echo

# 2. Remove kernel parameter
detect_bootloader() {
    if   [[ -f /etc/default/grub ]];    then echo "grub"
    elif [[ -d /boot/loader/entries ]]; then echo "systemd-boot"
    else echo "unknown"; fi
}

BOOTLOADER=$(detect_bootloader)
info "Bootloader: $BOOTLOADER"

if [[ "$BOOTLOADER" == "grub" ]]; then
    GRUB_CFG="/etc/default/grub"
    if grep "^GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_CFG" | grep -q "drm.edid_firmware"; then
        if confirm "Remove drm.edid_firmware from GRUB_CMDLINE_LINUX_DEFAULT?" "y"; then
            elevate sed -i 's| drm\.edid_firmware=[^ "]*||g' "$GRUB_CFG"
            success "GRUB config updated."
            GRUB_CHANGED=1
        fi
    else
        info "drm.edid_firmware not found in GRUB config."
    fi
    if [[ "$GRUB_CHANGED" -eq 1 ]]; then
        if confirm "Run grub-mkconfig?" "y"; then
            elevate grub-mkconfig -o /boot/grub/grub.cfg
            success "GRUB rebuilt."
        fi
    fi
elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    warn "systemd-boot detected. Remove drm.edid_firmware manually:"
    echo "  File: /boot/loader/entries/*.conf"
else
    warn "Bootloader not detected. Remove the kernel parameter manually."
fi
echo

# 3. Remove from initramfs config
detect_initramfs() {
    if   command -v mkinitcpio &>/dev/null; then echo "mkinitcpio"
    elif command -v dracut     &>/dev/null; then echo "dracut"
    else echo "unknown"; fi
}

INITRAMFS=$(detect_initramfs)
info "Initramfs system: $INITRAMFS"

if [[ "$INITRAMFS" == "mkinitcpio" ]]; then
    MKINIT_CONF="/etc/mkinitcpio.conf"
    if grep -q "edid" "$MKINIT_CONF"; then
        if confirm "Remove EDID entries from $MKINIT_CONF?" "y"; then
            elevate sed -i 's|^FILES=(.*)|FILES=()|' "$MKINIT_CONF"
            success "mkinitcpio.conf updated."
            if confirm "Run mkinitcpio -P?" "y"; then
                elevate mkinitcpio -P
                success "Initramfs rebuilt."
            fi
        fi
    else
        info "No EDID entries found in $MKINIT_CONF."
    fi
elif [[ "$INITRAMFS" == "dracut" ]]; then
    DRACUT_CONF="/etc/dracut.conf.d/edid.conf"
    if [[ -f "$DRACUT_CONF" ]]; then
        if confirm "Remove $DRACUT_CONF and rebuild initramfs?" "y"; then
            elevate rm -f "$DRACUT_CONF"
            elevate dracut --force
            success "Dracut config removed and initramfs rebuilt."
        fi
    else
        info "$DRACUT_CONF not found, skipping."
    fi
else
    warn "Initramfs system not detected. Clean up manually if needed."
fi
echo

success "Revert complete. Reboot to apply changes."
