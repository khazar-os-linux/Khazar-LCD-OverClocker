#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/start.sh"
state_load

# 3. CVT CALCULATION
info "Calculating CVT: ${W}x${H} @ ${TARGET_HZ}Hz"
CVT_OUT=$(cvt "$W" "$H" "$TARGET_HZ" 2>&1)
echo -e "${YEL}${CVT_OUT}${RST}"
echo

confirm "Confirm this CVT output?" "y" || { echo "Cancelled."; exit 1; }
