#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/start.sh"
state_load

# 8. REBOOT
echo -e "${GRN}${BLD}  All steps completed!${RST}"
echo
echo "  1) Reboot now"
echo "  2) Later"
echo -n "Your choice [1/2]: "
read -r REBOOT_CHOICE

case "$REBOOT_CHOICE" in
    1) info "Rebooting..."; sudo reboot ;;
    *) success "Done. Run 'sudo reboot' when ready." ;;
esac

rm -f "${ORIG_BIN:-}" "${OUT_BIN:-}" "$STATE_FILE"
