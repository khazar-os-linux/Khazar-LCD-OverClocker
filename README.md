# Khazar LCD OverClocker

A bash tool that patches your display's EDID firmware to unlock higher refresh rates beyond the manufacturer's default.

> **Warning:** This may permanently damage your LCD panel. Use at your own risk.

---

## How It Works

The tool reads your display's raw EDID data from `/sys/devices`, patches the timing descriptor (DTD) with a new pixel clock calculated for your target refresh rate, writes the modified EDID as a firmware file, and configures the kernel to load it at boot.

---

## Requirements

The following tools must be available (the script can install them automatically):

| Tool | Package |
|------|---------|
| `edid-decode` | `edid-decode` |
| `cvt` | `xorg-server` (Arch) / `x11-utils` (Debian) |
| `python3` | `python3` |

Supported package managers: `pacman`, `apt`, `dnf`.

---

## Usage
1. 
```bash
git clone https://github.com/khazar-os-linux/Khazar-LCD-OverClocker.git
```

2. 
```bash
cd Khazar-LCD-OverClocker
chmod +x edid_overclock.sh
./edid_overclock.sh
```

The script walks you through each step interactively. Answering `n` to any prompt cancels the entire process.

---

## Steps

| # | Script | Description |
|---|--------|-------------|
| 1 | `scripts/01_deps.sh` | Checks and optionally installs required tools |
| 2 | `scripts/02_display.sh` | Detects connected displays, shows available modes, reads target Hz |
| 3 | `scripts/03_cvt.sh` | Calculates CVT timing for the target refresh rate |
| 4 | `scripts/04_patch.sh` | Patches the EDID binary with new timing and verifies it |
| 5 | `scripts/05_firmware.sh` | Copies patched EDID to `/lib/firmware/edid/` |
| 6 | `scripts/06_bootloader.sh` | Adds `drm.edid_firmware` kernel parameter (GRUB or systemd-boot) |
| 7 | `scripts/07_initramfs.sh` | Embeds firmware into initramfs (mkinitcpio or dracut) |
| 8 | `scripts/08_reboot.sh` | Prompts for reboot and cleans up temp files |

---

## File Structure

```
edid_overclock.sh        # Entry point: disclaimer + step runner
scripts/
  start.sh               # Shared colors, helpers, state load/save (sourced)
  01_deps.sh
  02_display.sh
  03_cvt.sh
  04_patch.sh
  05_firmware.sh
  06_bootloader.sh
  07_initramfs.sh
  08_reboot.sh
```

---

## State Passing

Each sub-script shares variables (resolution, paths, timing values) through a temporary state file at `/tmp/edid_state_<PID>`. It is created by `02_display.sh` and deleted after the final step.

---

## Supported Bootloaders

- **GRUB** — automatically updates `/etc/default/grub` and runs `grub-mkconfig`

## Supported Initramfs Systems

- **mkinitcpio** — adds firmware to `FILES=()` in `/etc/mkinitcpio.conf` and runs `mkinitcpio -P`
- **dracut** — creates `/etc/dracut.conf.d/edid.conf` and runs `dracut --force`

---

## Kernel Parameter

The following parameter is added to your bootloader:

```
drm.edid_firmware=<connector>:edid/edid_overclocked.bin
```

Example for an internal display:

```
drm.edid_firmware=eDP-1:edid/edid_overclocked.bin
```

---

## Disclaimer

This tool modifies low-level display firmware. Possible consequences include:

- Permanent LCD panel damage
- Signal loss or image corruption
- Voided warranty

The developer accepts no liability for any damage resulting from use of this tool.
