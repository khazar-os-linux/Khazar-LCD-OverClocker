#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/shared-lib.sh"
state_load

# 6. BOOT PARAMETER
GRUB_PARAM="drm.edid_firmware=${DISPLAY_NAME}:edid/edid_overclocked.bin"

detect_bootloader() {
    if   [[ -f /etc/default/grub ]];    then echo "grub"
    elif [[ -d /boot/loader/entries ]]; then echo "systemd-boot"
    else echo "unknown"; fi
}

BOOTLOADER=$(detect_bootloader)
info "Bootloader: $BOOTLOADER"

if [[ "$BOOTLOADER" == "grub" ]]; then
    GRUB_CFG="/etc/default/grub"
    if grep "^GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_CFG" | grep -q "edid_overclocked"; then
        success "GRUB parameter already present."
    else
        confirm "Add '$GRUB_PARAM' to GRUB_CMDLINE_LINUX_DEFAULT?" "y" && {
            elevate sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $GRUB_PARAM\"|" "$GRUB_CFG"
            success "GRUB config updated."
        }
    fi
    confirm "Run grub-mkconfig?" "y" && {
        elevate grub-mkconfig -o /boot/grub/grub.cfg
        success "GRUB rebuilt."
    }
elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    warn "systemd-boot detected. Add the kernel parameter manually:"
    echo -e "  ${BLD}$GRUB_PARAM${RST}"
    echo "  File: /boot/loader/entries/*.conf"
else
    warn "Bootloader not detected. Add the kernel parameter manually:"
    echo -e "  ${BLD}$GRUB_PARAM${RST}"
fi
