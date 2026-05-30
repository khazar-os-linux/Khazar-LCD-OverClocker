#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/shared-lib.sh"

# 2. DISPLAY DETECTION
info "Searching for connected displays..."

declare -a ACTIVE_PATHS=()
declare -a ACTIVE_NAMES=()
declare -a ACTIVE_LABELS=()

for conn in /sys/class/drm/card*-*/; do
    status=$(cat "$conn/status" 2>/dev/null || echo "disconnected")
    [[ "$status" != "connected" ]] && continue

    conn_name=$(basename "$conn")                        # e.g. card1-eDP-1
    display_name="${conn_name#*-}"                       # e.g. eDP-1

    # resolve to /sys/devices path for edid
    edid_path=$(readlink -f "$conn/edid" 2>/dev/null || echo "$conn/edid")
    [[ ! -f "$edid_path" ]] && continue
    edid_size=$(wc -c < "$edid_path" 2>/dev/null || echo 0)
    (( edid_size == 0 )) && continue

    ACTIVE_PATHS+=("$edid_path")
    ACTIVE_NAMES+=("$display_name")
    ACTIVE_LABELS+=("${display_name} — active, connected")
done

[[ ${#ACTIVE_PATHS[@]} -eq 0 ]] && error "No active connected displays found."

if [[ ${#ACTIVE_PATHS[@]} -eq 1 ]]; then
    IDX=0
    success "${ACTIVE_LABELS[0]}"
else
    echo
    info "Multiple active displays detected. Select one:"
    for i in "${!ACTIVE_LABELS[@]}"; do
        echo "  $((i+1))) ${ACTIVE_LABELS[$i]}"
    done
    echo
    while true; do
        echo -en "${BLD}Enter display number [1-${#ACTIVE_PATHS[@]}]: ${RST}"
        read -r SEL
        if [[ "$SEL" =~ ^[0-9]+$ ]] && (( SEL >= 1 && SEL <= ${#ACTIVE_PATHS[@]} )); then
            IDX=$(( SEL - 1 ))
            break
        fi
        warn "Invalid selection."
    done
    success "Selected: ${ACTIVE_LABELS[$IDX]}"
fi

EDID_PATH="${ACTIVE_PATHS[$IDX]}"
DISPLAY_NAME="${ACTIVE_NAMES[$IDX]}"

# CVT type: eDP panels use reduced blanking (-r), others use standard
if [[ "$DISPLAY_NAME" == eDP* ]]; then
    CVT_TYPE="reduced"
else
    CVT_TYPE="standard"
fi

ORIG_BIN="$STATE_FILE.orig.bin"
cp "$EDID_PATH" "$ORIG_BIN"

EDID_DECODED=$(edid-decode "$ORIG_BIN" 2>/dev/null)

CURRENT_MODE=$(echo "$EDID_DECODED" | grep "DTD 1:" | grep -oP '\d+x\d+\s+\K[\d.]+(?= Hz)' | head -1)
CURRENT_RES=$(echo  "$EDID_DECODED" | grep "DTD 1:" | grep -oP 'DTD 1:\s+\K\d+x\d+' | head -1)

[[ -z "$CURRENT_RES"  ]] && error "Could not parse resolution from EDID."
[[ -z "$CURRENT_MODE" ]] && error "Could not parse refresh rate from EDID."

W=$(echo "$CURRENT_RES" | cut -dx -f1)
H=$(echo "$CURRENT_RES" | cut -dx -f2)

info "Current panel: ${BLD}${CURRENT_RES} @ ${CURRENT_MODE}Hz${RST} (CVT: ${CVT_TYPE})"
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
CVT_TYPE="$CVT_TYPE"
ORIG_BIN="$ORIG_BIN"
CURRENT_MODE="$CURRENT_MODE"
CURRENT_RES="$CURRENT_RES"
W="$W"
H="$H"
TARGET_HZ="$TARGET_HZ"
EOF
