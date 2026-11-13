# MEMORY.md — Hardware Quirks & Non-Obvious Traps

## 1. Profile 3 USB STALL Trap

- The mouse firmware accepts profile ID `3` when executing `CMD_PROFILE (0x02)`.
- However, the MCU flash only allocates memory for profiles `1` and `2`.
- Any subsequent attempt to query block `1` (`0x31`) or block `2` (`0x32`) triggers an immediate USB Control Pipe STALL. Under Linux, this manifests as `[Errno 32] Broken pipe` on `ioctl(HIDIOCGFEATURE)`.
- **Rule:** Supported hardware profile IDs must strictly be constrained to `(1, 2)`.

## 2. Udev Rule Ordering Constraint

- Systemd-logind applies `uaccess` ACLs through `/usr/lib/udev/rules.d/73-seat-late.rules`.
- Any rule that tags a node with `TAG+="uaccess"` must sort **lexicographically before** `73-seat-late.rules`.
- A file named `99-gamepower-icarus.rules` is processed too late: `logind` ignores the tag, and the device node remains restricted to `root:root 0600`.
- **Rule:** The udev rule file is named `70-gamepower-icarus.rules`.

## 3. Flash Write Triggers (Magic Bytes)

- The MCU will silently discard configuration writes that do not include the exact byte-count offset in Byte 3:
  - Configuration blocks require Byte 3 = `0x7B` (123).
  - Button blocks require Byte 3 = `0x50` (80).
- Writing `0x00` in Byte 3 performs a no-op read mirror without flashing memory.

## 4. Short Report Read Padding

- When reading Report `0x04`, the mouse firmware sends only the populated bytes over the USB wire (141 bytes for config, 86 bytes for buttons) rather than a full 520-byte packet.
- When writing back, the host **must** transmit a full 520-byte feature report.
- The transport layer must always zero-pad inbound reports to 520 bytes before handing them to parsers.

## 5. Non-Destructive Calibration Preservation

- Bytes 4..8, 104..128, and 130..131 contain factory sensor calibration constants for the PixArt PMW3325.
- Zeroing or modifying these ranges (such as overwriting `buf[130]` or writing experimental mode data to `buf[116..125]`) corrupts sensor engine registers, halting relative motion events while button clicks remain functional.
- Writers must always base updates on an existing read buffer and copy `104..128` (except 129) and `130..131` byte-exact.

## 6. RGB Mode Masking (`LedMask = 0x1E8`)

- The Sinowealth firmware family defines up to 10 lighting modes (0..9 in `text.xml` / `OemDrv.exe @ 0x4367bf`), but the Icarus firmware only enables a subset defined by `LedMask = 0x1E8` in `Cfg.ini`.
- The UI loop tests `LedMask & (1 << i)` where non-zero bits skip/mask the mode. Bits 3, 5, 6, 7, 8 are masked out.
- Only the 5 unmasked modes (`STREAMING` = 0, `STEADY` = 1, `BREATHING` = 2, `NEON` = 4, `OFF` = 9) are supported by hardware and exposed in the CLI/GUI.

## 7. Breathing Single-Color Synchronization

- In Breathing mode (`0x02`), the MCU reads the single breathing color from `b7_colors[0]` (bytes 62..64) and expects `b7_count` (byte 61) to be set to `1`. If bytes 62..64 are zeroed or byte 61 is set to 7, the mouse unexpectedly cycles spectrum colors.
- Serializers must mirror the user's selected breathing color to `b7_colors[0]` when writing single-color breathing mode.

## 8. Hyprland Touchpad Isolation

- Global mouse wheel settings in Wayland compositors can inadvertently accelerate laptop touchpads to uncontrollable speeds.
- In Hyprland, scroll scaling must be applied strictly via per-device configuration targeting `sinowealth-wired-gaming-mouse`.
- Configuration files (`~/.config/hypr/input.lua`) must never touch `input.touchpad = { scroll_factor = ... }`.

## 9. Sinowealth SH68F89 ISP Bootloader Read/Write Asymmetry Trap

- In ISP mode (`VID_0603&PID_1021`), reading a 2048-byte page via `0x52` + `GetFeature(0x06)` (`0x72` at `0xF093..0xF175`) returns bytes `0..5` raw and adds `+0x5E` (`0xFD79`) to bytes `6..2047`.
- **Trap:** Writing a page via `0x57` + `SetFeature(0x06)` (`0x77` at `0xF36B..0xF4D0`) subtracts `0x5A` (`ADD A, #0xA6`) from **bytes `0..5` as well** (`0xF380..0xF3FF` and `0xFDD3`). Leaving bytes `0..5` unencoded on Page 0 (`0x0000`) corrupts the reset vector (`0x0001..0x0002` becomes `FE FE` instead of `2E 34`, jumping to `0xFEFE: 22` `RET` and looping forever before USB initializes).
- **Rule:** For USB ISP writes (`0x77`), all 2048 bytes of each page must have `+0x5A` added (`firmware_patched_60k_isp.bin`). For direct hardware ICP/JTAG programming, use the unencoded binary (`firmware_patched_60k.bin` or `isp_dump_fixed.bin`).

## 10. Dual-Sensor Architecture & LOD `P1.5` Motion Gate (`0x4760`)

- The mouse contains both a PixArt PMW3325 main optical sensor (3-wire SPI on `P2.4/P2.3/P2.1`, invisible 850nm IR LED) and a separate bottom Lift-Off Distance (LOD) proximity sensor (I2C `0x20`/`0x21` on `P1.6/P1.7` + digital output on `P1.5` / `bit_0x95`, visible 3 Hz blinking LED).
- At `0x4760..0x476F`, if `P1.5 == 1` (`bit_0x95`) and `bit_0x3a == 1`, the firmware zeroes `dir_0x4b..0x4e` (`dx/dy`) on every poll even when the PMW3325 sensor is healthy (`dir_0x43 == 0x0B`).

## 11. Windows Turkish Locale `ToLower()` Trap in HID Paths

- In PowerShell under a Turkish locale (`tr-TR`), calling `.ToLower()` on `"HID\VID_258A..."` converts uppercase `'I'` to dotless `'ı'` (`U+0131`), causing `CreateFile` to fail with `ERROR_FILE_NOT_FOUND (2)`.
- **Rule:** Always use `.ToLowerInvariant()` when constructing Win32 device interface paths.
