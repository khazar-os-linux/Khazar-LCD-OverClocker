#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/start.sh"

# 2. DISPLAY DETECTION
info "Searching for connected displays..."

mapfile -t EDID_PATHS < <(find /sys/devices -name "edid" -path "*/drm/card*" 2>/dev/null | sort)
[[ ${#EDID_PATHS[@]} -eq 0 ]] && error "No displays found via /sys/devices."

if [[ ${#EDID_PATHS[@]} -eq 1 ]]; then
    EDID_PATH="${EDID_PATHS[0]}"
    success "Display found: $EDID_PATH"
else
    echo
    info "Multiple displays detected. Select one:"
    for i in "${!EDID_PATHS[@]}"; do
        echo "  $((i+1))) ${EDID_PATHS[$i]}"
    done
    echo
    while true; do
        echo -en "${BLD}Enter display number [1-${#EDID_PATHS[@]}]: ${RST}"
        read -r SEL
        if [[ "$SEL" =~ ^[0-9]+$ ]] && (( SEL >= 1 && SEL <= ${#EDID_PATHS[@]} )); then
            EDID_PATH="${EDID_PATHS[$((SEL-1))]}"
            break
        fi
        warn "Invalid selection."
    done
    success "Selected: $EDID_PATH"
fi

DISPLAY_NAME=$(echo "$EDID_PATH" | grep -oP '(?<=/drm/card\d/card\d-)[^/]+(?=/)' | head -1)
[[ -z "$DISPLAY_NAME" ]] && DISPLAY_NAME="eDP-1"

ORIG_BIN="$STATE_FILE.orig.bin"
cp "$EDID_PATH" "$ORIG_BIN"

EDID_DECODED=$(edid-decode "$ORIG_BIN" 2>/dev/null)

CURRENT_MODE=$(echo "$EDID_DECODED" | grep "DTD 1:" | grep -oP '\d+x\d+\s+\K[\d.]+(?= Hz)' | head -1)
CURRENT_RES=$(echo  "$EDID_DECODED" | grep "DTD 1:" | grep -oP 'DTD 1:\s+\K\d+x\d+' | head -1)

[[ -z "$CURRENT_RES"  ]] && error "Could not parse resolution from EDID."
[[ -z "$CURRENT_MODE" ]] && error "Could not parse refresh rate from EDID."

W=$(echo "$CURRENT_RES" | cut -dx -f1)
H=$(echo "$CURRENT_RES" | cut -dx -f2)

info "Current panel: ${BLD}${CURRENT_RES} @ ${CURRENT_MODE}Hz${RST}"
echo
info "Available modes from EDID:"
echo "$EDID_DECODED" | grep -oP 'DTD \d+:\s+\K\d+x\d+\s+[\d.]+(?= Hz)' \
    | awk '{printf "  %s @ %sHz\n", $1, $2}'
echo

echo -en "${BLD}Enter target refresh rate (Hz): ${RST}"
read -r TARGET_HZ

[[ "$TARGET_HZ" =~ ^[0-9]+$ ]] || error "Invalid value."
(( TARGET_HZ <= ${CURRENT_MODE%.*} )) && error "Target must be higher than current refresh rate."
(( TARGET_HZ > 200 ))               && error "Values above 200Hz are not supported."

cat > "$STATE_FILE" <<EOF
EDID_PATH="$EDID_PATH"
DISPLAY_NAME="$DISPLAY_NAME"
ORIG_BIN="$ORIG_BIN"
CURRENT_MODE="$CURRENT_MODE"
CURRENT_RES="$CURRENT_RES"
W="$W"
H="$H"
TARGET_HZ="$TARGET_HZ"
EOF
