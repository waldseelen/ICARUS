# CLAUDE.md — Agent & Coding Guidelines for icarusctl

## 0. Non-Negotiable Invariants

1. **Zero External Dependencies:** Runtime must remain 100% Python 3 standard library (`fcntl`, `os`, `struct`, `argparse`, `dataclasses`). Do not add external package dependencies (no `hidapi`, no `pyusb`, no `cffi`).
2. **File Size Limit:** No source file in `icarus/` may exceed 400 lines. Split before hitting the boundary.
3. **Safety Gate Before Flash Writes:** Every command that modifies mouse flash must ensure a full dump of both blocks across all supported profiles is persisted to `~/.local/state/icarusctl/` first.
4. **Preserve Device Calibration:** When writing config or button blocks, always base changes on the active block read from hardware, modifying only task-relevant fields and preserving reserved/calibration bytes.
5. **No Kernel Module:** Hardware is controlled purely in userspace via `/dev/hidraw*` feature reports. The kernel `usbhid` driver handles standard mouse pointer/keyboard clicks concurrently.

## 1. Project Conventions

- **Code Style:** Strict Python 3 type annotations on all functions and methods.
- **Error Handling:** Graceful user-facing error messages on permission denied or disconnected hardware without Python tracebacks in normal CLI execution.
- **Testing:** Unit tests in `tests/` must run via `python3 -m unittest discover tests` with zero setup. Round-trip serialization tests must verify byte-exact preservation against binary fixtures in `tests/data/`.
- **Packaging:** Deliverables must support Arch Linux (PKGBUILD), Debian/Ubuntu (`.deb`), and generic Linux (standalone zipapp executable).

## 2. Reading Order for System Context

1. `ARCHITECTURE.md` — system topology, hardware interface, packet routing
2. `SPEC.md` — low-level HID report schemas, command codes, byte offsets, VA references
3. `MEMORY.md` — hardware quirks, USB STALL behaviors, udev ordering constraints
4. `PROGRESS.md` — test gate status and session log
5. `README.md` — CLI usage instructions and installation

## 3. Hardware, Firmware & Reverse Engineering Hard Rules (Post-Mortem 2026-11-13)

> **Why these rules exist:** An earlier AI session bricked the mouse by applying an unverified `-0x5A` byte offset to bytes `0..5` during USB ISP flashing, corrupting the reset vector `0x0000` (`02 2E 34` -> `02 FE FE`) and locking the device out of USB/ISP for a week until hardware ICP recovery succeeded on 2026-11-13.

### Never Touch / Hard Boundaries
1. **DO NOT write Flash (`0x0000..0xFFFF`) or Custom/Option blocks without explicit byte-by-byte verification and user confirmation:**
   - **Never** modify, erase, or overwrite the USB ISP bootloader region (`0xF000..0xFFFF`) or code options (`OP_LVRLEVEL`, `OP_RST`, `OP_ISP`, `OP_ISPPIN`) via USB ISP or ICP.
   - **Never** write Sector 0 (`0x0000..0x03FF`) unless the exact reset vector (`0x0000..0x0002` = `02 2E 34`, or verified `LJMP`) and full 1024-byte payload are checksummed and verified against a known-good dump (`firmware_backup/firmware_patched_60k.bin` or `firmware_original_60k.bin`).
2. **Reverse Engineering & Bootloader Protocol Rules:**
   - **Never guess or extrapolate** offsets, encryption/obfuscation transforms (such as `-0x5A`), or flash/ISP packet layouts from partial snippets. Every transform in `sinowisp.exe`, `OemDrv.exe`, or `0xF000..0xFFFF` bootloader disassembly **must** be verified end-to-end on a read-only dry run / byte-exact round-trip check before any erase or write command is sent.
   - **Always inspect bootloader entry conditions first:** Check `0xF000..0xFFFF` jump/flag logic (e.g., `0xEFFB == 0x02` check, `0xFFF2` vector) and `sh68f89.rs` code options before assuming how ISP recovery behaves if Sector 0 fails.
   - **Always read back and verify (`verify == expected`)** after any flash write; abort immediately on any echo or readback mismatch.
3. **Electrical & ICP Safety Rules:**
   - **NEVER** connect Arduino/external `5V` or GPIO power to `CON6 Pin 1 (VDD)` while the mouse's own USB cable is plugged into the PC.
   - **NEVER** supply `3.3V` to `CON6 Pin 1` on `SH68F89` (`OP_LVRLEVEL = 1` sets a `3.7V` Low-Voltage Reset; `CON6 Pin 1` is `5.0V` nominal).
   - **NEVER** power `CON6 Pin 1 (VDD)` directly from an ATmega328P GPIO pin (`D6`): GPIO current limits/internal resistance sag below `3.7V` under mouse PCB load. Use a P-channel MOSFET or `5V` rail with bounce-filtered cold-start synchronization (e.g., pulsed `30 us` `INPUT_PULLUP` ESD-diode detection on `D2/TDO`).
