#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/start.sh"
state_load

# 5. COPY TO FIRMWARE
FIRMWARE_DIR="/lib/firmware/edid"
FIRMWARE_FILE="$FIRMWARE_DIR/edid_overclocked.bin"

confirm "Copy file to $FIRMWARE_FILE? (requires sudo)" "y" || { echo "Cancelled."; exit 1; }

sudo mkdir -p "$FIRMWARE_DIR"
sudo cp "$OUT_BIN" "$FIRMWARE_FILE"
success "Copied: $FIRMWARE_FILE"

echo "FIRMWARE_FILE=\"$FIRMWARE_FILE\"" >> "$STATE_FILE"
