#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/start.sh"
state_load

# 4. EDID PATCH
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

info "Timing: Htotal=${HTOTAL}, Vtotal=${VTOTAL}, pclk≈$(( PCLK_10KHZ / 100 )).$(( PCLK_10KHZ % 100 )) MHz"

OUT_BIN="$STATE_FILE.patched.bin"

python3 - <<PYEOF
orig  = "$ORIG_BIN"
out   = "$OUT_BIN"
pclk  = $PCLK_10KHZ
W     = $W
H     = $H
hblank = $HFRONT + $HSYNC + $HBACK
vblank = $VFRONT + $VSYNC + $VBACK
hfront = $HFRONT
hsync  = $HSYNC
vfront = $VFRONT
vsync  = $VSYNC

with open(orig, 'rb') as f:
    edid = bytearray(f.read())

pclk_lo = pclk & 0xFF
pclk_hi = (pclk >> 8) & 0xFF
ha_lo   = W & 0xFF
hb_lo   = hblank & 0xFF
hhi     = ((W >> 4) & 0xF0) | ((hblank >> 8) & 0x0F)
va_lo   = H & 0xFF
vb_lo   = vblank & 0xFF
vhi     = ((H >> 4) & 0xF0) | ((vblank >> 8) & 0x0F)
hf_lo   = hfront & 0xFF
hs_lo   = hsync & 0xFF
vf_vs   = ((vfront & 0x0F) << 4) | (vsync & 0x0F)
hi4     = (((hfront >> 8) & 0x03) << 6) | (((hsync >> 8) & 0x03) << 4) | \
          (((vfront >> 4) & 0x03) << 2) | ((vsync >> 4) & 0x03)

dtd1_start = 54
img_w_mm = (edid[dtd1_start+12] | ((edid[dtd1_start+14] & 0xF0) << 4))
img_h_mm = (edid[dtd1_start+13] | ((edid[dtd1_start+14] & 0x0F) << 8))

dtd = bytes([
    pclk_lo, pclk_hi,
    ha_lo, hb_lo, hhi,
    va_lo, vb_lo, vhi,
    hf_lo, hs_lo, vf_vs, hi4,
    img_w_mm & 0xFF, img_h_mm & 0xFF,
    ((img_w_mm >> 4) & 0xF0) | ((img_h_mm >> 8) & 0x0F),
    0x00, 0x00, 0x1A
])

edid[72:90] = dtd
edid[127] = (256 - sum(edid[:127]) % 256) % 256

with open(out, 'wb') as f:
    f.write(edid)

print(f"Checksum: {hex(edid[127])}")
PYEOF

echo
info "Verifying EDID..."
VERIFY=$(edid-decode "$OUT_BIN" 2>/dev/null | grep "Hz")
echo -e "${YEL}${VERIFY}${RST}"
echo "$VERIFY" | grep -q "$TARGET_HZ" \
    || warn "Target Hz not exactly matched in EDID output. You may still continue."

echo "OUT_BIN=\"$OUT_BIN\"" >> "$STATE_FILE"
