#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/shared-lib.sh"
state_load

# 3. CVT CALCULATION
info "Calculating CVT: ${W}x${H} @ ${TARGET_HZ}Hz (${CVT_TYPE})"
if [[ "$CVT_TYPE" == "reduced" ]]; then
    CVT_OUT=$(cvt -r "$W" "$H" "$TARGET_HZ" 2>&1)
    if echo "$CVT_OUT" | grep -qi "error\|required"; then
        warn "CVT reduced blanking not available for ${TARGET_HZ}Hz, falling back to standard."
        CVT_OUT=$(cvt "$W" "$H" "$TARGET_HZ" 2>&1)
    fi
else
    CVT_OUT=$(cvt "$W" "$H" "$TARGET_HZ" 2>&1)
fi
echo -e "${YEL}${CVT_OUT}${RST}"

# Parse original blanking values from EDID and compute optimized pixel clock
DTD1_LINE=$(edid-decode "$ORIG_BIN" 2>/dev/null | grep "DTD 1:" -A2)
HFRONT=$(echo "$DTD1_LINE" | grep -oP 'Hfront\s+\K\d+')
HSYNC=$( echo "$DTD1_LINE" | grep -oP 'Hsync\s+\K\d+')
HBACK=$( echo "$DTD1_LINE" | grep -oP 'Hback\s+\K\d+')
VFRONT=$(echo "$DTD1_LINE" | grep -oP 'Vfront\s+\K\d+')
VSYNC=$( echo "$DTD1_LINE" | grep -oP 'Vsync\s+\K\d+')
VBACK=$( echo "$DTD1_LINE" | grep -oP 'Vback\s+\K\d+')

HTOTAL=$(( W + HFRONT + HSYNC + HBACK ))
VTOTAL=$(( H + VFRONT + VSYNC + VBACK ))
PCLK_10KHZ=$(( HTOTAL * VTOTAL * TARGET_HZ / 10000 ))

echo
info "Optimized timing (original blanking, target Hz):"
echo "  Htotal=${HTOTAL}  Vtotal=${VTOTAL}  pclk≈$(( PCLK_10KHZ / 100 )).$(( (PCLK_10KHZ % 100) ))MHz"
echo

confirm "Confirm and proceed with patch?" "y" || { echo "Cancelled."; exit 1; }

cat >> "$STATE_FILE" <<EOF
HFRONT="$HFRONT"
HSYNC="$HSYNC"
HBACK="$HBACK"
VFRONT="$VFRONT"
VSYNC="$VSYNC"
VBACK="$VBACK"
HTOTAL="$HTOTAL"
VTOTAL="$VTOTAL"
PCLK_10KHZ="$PCLK_10KHZ"
EOF
