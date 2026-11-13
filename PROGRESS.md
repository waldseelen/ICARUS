# PROGRESS.md — Gate Status & Session History

## Current Gate Status (2026-11-13)

- `node` 8051 firmware disassembly & 64 KB ROM extraction (`firmware_backup/isp_dump_fixed.bin`): **PASS** (Bootloader MD5 `571ea8b315654c39046e4cc3b1e43777` verified)
- Live PMW3325 SPI `dir_0x43 == 0x0B` verification (`p2_b1` `b11 = 0x38` retention across `0x420C -> 0x4A2E` boot check): **PASS** (`BLK_21: 04-21-00-00-00-00-06-00-00-0B-02-38...`)
- Hardware ICP/JTAG Sector 0 recovery & USB re-enumeration (`VID_258A&PID_0027`): **PASS** (`ICP=0x69`, `JTAG_ID=0x6161`, `VERIFY_MISMATCHES=0`, Windows PnP `OK`)
- Remaining 60 KB Pages (`0x0800..0xEFFF`) & USB `GET/SET_REPORT` (`0x1002..0x1005`): **BLOCKED (Hardware ICP pads damaged)** — Sector 0 is repaired, but `0x1000..0x1005` (`GET_REPORT`/`SET_REPORT` in `0x0FD5..0x1013`) is corrupted by `-0x5A`, causing EP0 STALL (`err=31`) on all `0x05`/`0x04` feature reports; awaits PCB trace repair (`SH68F89_ICP_PINOUT.png`).

## 2026-11-13 (Oturum 2) — `OFFLINE_ESD_CHECK`, USB `0x1002..0x1005` Kök Neden Kanıtı, Pinout Görseli ve Arduino Sıfırlama

- **Değişen alanlar (`path›symbol`)**:
  - `SH68F89_ICP_PINOUT.png`: Ana dizinde elektronikçi için yüksek çözünürlüklü `CON6` (`Pin 1..6` = `VDD, TCK, TDI, TMS, TDO, GND`) ↔ Arduino Uno (`5V, D5, D4, D3, D2, GND`) ve yanık ped/bakır yol onarım şeması oluşturuldu.
  - `PROGRESS.md`, `CLAUDE_HANDOFF.md`: Oturum 2 bulguları, 8051 tersine mühendislik kanıtları ve Arduino Uno sıfırlama sonucu belgelendi.
  - Arduino Uno (`COM5`, ATmega328P): `avrdude.exe` ile `uno_factory_blink.ino.hex` (`998` bayt) yüklenerek fabrika `Blink` + EEPROM (`0..127 = 0xFF`) temizleme durumuna geri döndürüldü.

- **Kanıt**:
  - `OFFLINE_ESD_CHECK` (`icp_stream60k.ino`): `D2=0` sağlam görünürken `D3=1, D4=1, D5=1` okunarak `TMS/TDI/TCK` lehimlerinde temassızlık tespit edildi; ardından `CON6` pedleri ısıdan hasar gördü.
  - Canlı USB HID testi (`VID_258A&PID_0027`): `SetFeature(05, 01)` → `err=31` (STALL), `GetFeature(05)` → `err=31`, `SetFeature(05, 02)` → `err=121`, `GetFeature(04)` → `err=31`; tüm arayüzlerde `Out=0` (Interrupt OUT yok).
  - 8051 Tersine Mühendislik (`firmware_patched_60k.bin`): `0x3669` EP0 SETUP yönlendiricisinin `0x0FD5..0x1013` tablosunda `0x1002..0x1004` (`A1 01 0F` = `GET_REPORT` → `0x0066`) ve `0x1005..0x1007` (`21 09 10` = `SET_REPORT` → `0x31B0` → `0x1B9F` → `0x05 0x75` → `0x50FA` → `LJMP 0xFF00`) kayıtlarının `0x1000..0x1005` sayfa sınırında `-0x5A` ile `B0 B4 47 A7 B5 C7`'ye bozulduğu ve bu nedenle USB üzerinden ISP'ye (`0603:1021`) geçişin yazılımsal olarak imkânsız olduğu kanıtlandı.
  - `avrdude.exe` (`COM5`): `998 bytes of flash verified` / `Avrdude done. Thank you.`

- **Kalan boşluk**:
  - `CON6` yanındaki 4 bakır yoldan (`TCK, TDI, TMS, TDO`) yeni tel çekildikten sonra `icp_stream60k.ino` + `stream_repair.ps1` ile `0x0800..0xEFFF` sektörlerinin onarımı, `GetPSD` (`"V901"`) ve imleç `dx/dy` doğrulaması.

## 2026-11-13 — Hardware ICP/JTAG Recovery (`SH68F89`), Pulsed ESD Trigger & Post-Mortem Rules

- **Değişen alanlar (`path›symbol`)**:
  - `CLAUDE.md` (§3): Added non-negotiable hardware, firmware, and reverse-engineering safety rules (bootloader `0xF000..0xFFFF` lock, Sector 0 verification gate, `3.7V` LVR / `D6` sag / USB power isolation rules).
  - `CLAUDE_HANDOFF.md`: Updated status to `RECOVERED` (`VID:PID 258A:0027 OK`).
  - `ICP_RESEARCH_2026-11-13.md`: Documented `karstx/sinodude` (`sh68f89.rs`, `firmware/src/main.rs`, `sinolink.rs`) and `gashtaan/sinowealth-8051-dumper` findings, pulsed `30 µs` ESD-diode `VDD` edge trigger, and Sector 0 repair result.
  - Mouse MCU Flash (`0x0000..0x03FF`): Erased Sector 0 (`ERASE_STATUS=0x0`), flashed 1024 bytes from `firmware_backup/firmware_patched_60k.bin` (`WRITE_1024_OK`), verified `0` mismatches (`NEW_FLASH0=02 2E 34 30 33 04 8F 34 D2 4C 22 02 2A EE E4 F5`), and confirmed `0x4760` LOD bypass (`80 0E 00 30 3A 0A E4 F5`) intact.

- **Kanıt**:
  - Arduino Uno (`COM5`) ICP/JTAG log: `ICP=0x69`, `JTAG_ID=0x6161`, `ERASE_STATUS=0x0`, `WRITE_1024_OK`, `VERIFY_MISMATCHES=0`, `REPAIR_SUCCESS`.
  - Windows `Get-PnpDevice -PresentOnly`: `USB\VID_258A&PID_0027` and all `HID\VID_258A&PID_0027&MI_00` / `MI_01` interfaces report `Status = OK`.

- **Kalan boşluk**:
  - Physical cursor (`dx/dy`) verification on Linux/Windows and Linux `python3 -m unittest discover tests` run on Linux host.

## 2026-11-08 — Full 64 KB SH68F89 Flash Extraction, Dual-Sensor Root Cause Proof & ISP Reset Vector Post-Mortem

- **Değişen alanlar (`path›symbol`)**:
  - `EEE.md`: Created electronics & embedded hardware recovery guide detailing how to wake and re-flash the Sinowealth SH68F89 MCU using an Arduino (Uno/Nano/Pro Micro), ESP32, or Raspberry Pi Pico (RP2040) via 4-pin ICP/JTAG (`TCK, TMS, TDI, TDO`), including voltage level rules ($3.3\text{ V}$ vs $5\text{ V}$ with $1\text{ k}\Omega$ series resistors), the Sector 0 (`0x0000`) erase shortcut to slide into the `0xF000` USB ISP bootloader, and the hardware `P1.5` pull-down alternative for the bottom LOD sensor.
  - `FARE.md`: Documented complete 64 KB SH68F89 flash map (`0x0000..0xFFFF`), XRAM shadow layout (`0x0000..0x0547`), full 8051 call graph (`0x2E34 -> 0x3943`), dual-sensor architecture (PixArt PMW3325 on 3-wire SPI `P2.4/P2.3/P2.1` + bottom LOD proximity sensor on I2C `P1.6/P1.7` and lift-off pin `P1.5`), ISP read/write asymmetry post-mortem, and 4-pin ICP/JTAG recovery guide.
  - `firmware_backup/`: Saved permanent copies of `isp_dump_fixed.bin` (exact 64 KB factory ROM), `isp_dump.bin` (raw 64 KB ISP read), `firmware_original_60k.bin` (original 60 KB firmware), `firmware_patched_60k.bin` (patched 60 KB firmware for ICP/JTAG with `0x473F: d2 3b 00`, `0x4760: 80 0e 00`, `0xEFFB: 02 2e 34`), `firmware_patched_60k_isp.bin` (`+0x5A` encoded across all 2048 bytes per page for USB ISP), `sinowisp.exe`, and all PowerShell scripts (`scripts/`).
  - `setup/`: Extracted full Windows vendor installer (`OemDrv.exe`, `Lowerdev.dll`, `MenuEx.dll`, `InitSetup.dll`, `Cfg.ini`, `text.xml`, `oemdrv.asm`, `skins/`, `localappdata/`).
  - `ARCHITECTURE.md`, `SPEC.md`, `MEMORY.md`: Updated hardware topology to Sinowealth SH68F89 (64 KB), documented Opcode `0x75` (ISP entry), dual-sensor architecture, ISP read/write first-6-byte asymmetry trap, and Turkish locale `.ToLowerInvariant()` rule.

- **Kanıt**:
  - `isp_dump.ps1`: Read all 32 pages (65,536 bytes) in ISP mode (`VID_0603&PID_1021`); subtracting `0x5E` from bytes `6..2047` of each `0x800` page yielded bootloader MD5 `571ea8b315654c39046e4cc3b1e43777` (SH68F89).
  - `p2_b1` `b11 = 0x38` hardware boot test: Wrote `b8 = 0x00, b11 = 0x38` with magic `0x7B`; after full USB power cycle (`0x3943 -> 0x4FE3 -> 0x420C -> 0x4A2E`), readback returned `04-21-00-00-00-00-06-00-00-0B-02-38-00-04-07-09`, proving `0x4A2E` took the `dir_0x43 == 0x0B` branch (PMW3325 SPI `Product_ID == 0x43` is healthy) and isolating `dx/dy == 0` to the `0x4760` (`JNB bit_0x95, 0x4770` / `JNB bit_0x3a, 0x4770`) bottom LOD sensor gate.
  - `isp_flash_patch.ps1` verification output: All bytes `6..2047` across all 30 pages (`0x0000..0xEFFF`, including patches at `0x473F` and `0x4760`) verified with `0` mismatches; bytes `0..5` of each page had `0x5A` subtracted by bootloader write routine `0xF380..0xF400`, writing `02 FE FE` (`LJMP 0xFEFE`, where `0xFEFE = 0x22 RET`) at `0x0000..0x0002`.

- **Kalan boşluk**:
  - Hardware 4-pin ICP/JTAG flash required using an Arduino / ESP32 / RP2040 (`sinowealth-8051-dumper` / `sh-flasher`) to write `firmware_backup/firmware_patched_60k.bin` (or `firmware_backup/isp_dump_fixed.bin`) directly to the SH68F89 MCU and restore the `0x0000: 02 2E 34` reset vector.

## 2026-11-01 — REA Disassembly, Active Profile 1 Switching & Factory Block Restoration

- **Değişen alanlar (`path›symbol`)**:
  - `OemDrv.exe` & `Lowerdev.dll`: Disassembled `CDrv8948` methods `0x413180` (SendCmd), `0x4134e0` (GetPSD), `0x413550` (GetActiveProfile), `0x4135c0` (SetActiveProfile), `0x413610` (ReadBlock), `0x4136d0` (WriteConfigBlock with Magic `0x7B`), `0x413780` (WriteButtonBlock with Magic `0x50`), proving driver has zero SPI sensor wake commands.
  - Hardware Memory: Active profile switched from Profile 2 (locked at `lod=0`, shutter `1018`, 250 Hz) to Profile 1 (`lod=1`, 1000 Hz).
  - Hardware Flash: Restored byte-exact golden factory dumps `p1_b1.bin`, `p1_b2.bin`, `p2_b1.bin`, `p2_b2.bin` to physical mouse flash via `/dev/hidraw1` with write magic `0x7B` and `0x50`. Read-back verified 0 byte differences against factory fixtures.

- **Kanıt**:
  - `dev.active_profile()` returned `1`.
  - Flash read-back diffs: Profile 1 Config: 0 diffs, Profile 1 Button: 0 diffs.
  - `bin/icarus info`: Device active profile = 1, Polling Rate = 1000 Hz, LOD = High (3mm).
  - `python3 -m unittest discover tests`: 42 tests passed in 1.291s.

- **Kalan boşluk**:
  - Yok.

## 2026-10-31 — Factory Flash Restoration & Live Hardware Write Lockdown

- **Değişen alanlar (`path›symbol`)**:
  - `tests/test_hardware_live.py`: Gated `test_safe_nondestructive_write_readback_restore` behind `RUN_LIVE_HARDWARE_WRITE=1`. Running tests or build scripts will never modify physical mouse memory again.
  - `icarus/commands.py›cmd_restore`: Fixed write magic injection (`0x7B` for config, `0x50` for buttons) so raw backup dumps can be flashed back to hardware without being silently discarded by MCU.
  - Hardware Memory: Profile 1 and Profile 2 (both config and button blocks) flashed with 100% byte-exact factory original dumps (`tests/data/p1_b1.bin` and `p2_b1.bin`). Zero byte differences verified on readback.

## 2026-10-31 — Optical Sensor Tracking Fix, 0-Indexed RGB Mode Alignment & Touchpad 3-Dot Tap Isolation

- **Değişen alanlar (`path›symbol`)**:
  - `icarus/config.py`: Aligned `RgbEffect` enum with genuine 0-indexed hardware values from `OemDrv.exe` & `text.xml` (`0=STREAMING`, `1=STEADY`, `2=BREATHING`, `4=NEON`, `9=OFF`). Removed destructive writes to `buf[116..125]` and blanket write to `buf[130]`. Added invariant preservation in `serialize_config` ensuring PixArt PMW3325 sensor calibration bytes `104..128` (except `129`) and `130..131` are strictly copied from `raw_buffer` byte-exact (311 lines).
  - `icarus/commands.py`: Aligned `cmd_led` to reject masked effects and validate against `SUPPORTED_RGB_EFFECTS` (398 lines).
  - `icarus/gui.py`: Aligned `RGB_MODES` list to `SUPPORTED_RGB_EFFECTS` (394 lines).
  - `tests/test_config.py`: Updated parse tests for Profile 1 (`BREATHING`) and Profile 2 (`STEADY`) and added `test_sensor_calibration_bytes_preserved` against golden factory backups (134 lines).
  - `tests/test_gui.py`: Updated `test_api_status_metadata` to expect 5 supported RGB modes (195 lines).
  - `tests/test_e2e_mock.py`: Aligned test assertions with new hardware enum values (333 lines).
  - `SPEC.md` & `MEMORY.md`: Documented sensor calibration registers (`104..128`, `130..131`) and `LedMask=0x1E8` bit-test logic in `OemDrv.exe @ 0x4367bf`.
  - `dotfiles/.config/hypr/input.lua`: Bound `mouse:274` to `omarchy-shell media playPause` with `non_consuming = true` and `device = { inclusive = true, list = { "syna32e4:00-06cb:cee7-touchpad" } }`, isolating the gesture strictly to the touchpad without intercepting external mouse middle-clicks.
  - Mouse Flash Memory: Restored factory sensor calibration registers from `p1_b1.bin` and `p2_b1.bin` to physical mouse flash via `/dev/hidraw2`.

- **Kanıt**:
  - Unit tests: `python3 -m unittest discover tests` executed 42 tests in 1.623s with 0 errors.
  - Live query: `~/.local/bin/icarus info` executed cleanly against physical device.
  - Line count audit: `wc -l` confirmed all 13 modules in `icarus/` strictly <= 400 lines.
  - Distribution build: `scripts/build-dist.sh` passed tests and generated standalone `dist/icarus` installed to `~/.local/bin/icarus`.
  - Touchpad isolation: `hyprctl devices` confirmed touchpad has natural scroll untouched, while Hyprland bind targets only touchpad device for `mouse:274`.

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Documentation Sync & Public Release Initialization

- **Değişen alanlar (`path›symbol`)**:
  - `README.md`: Documented scroll speed scaling, touchpad isolation guarantee, full button preset categories, and RGB unmasked hardware modes.
  - `ARCHITECTURE.md`: Synchronized file tree to `icarus/` with all 13 modules, web assets, and layered architecture diagram including REST API, Hyprland IPC, and TEA decryptor.
  - `SPEC.md`: Added `0x22` multimedia and browser shortcut mappings, `0x33` multi-click codes, `0x50` special hardware switches, and `LedMask=0x1E8` unmasked modes.
  - `MEMORY.md`: Added durable traps for `LedMask=0x1E8` hardware masking, Breathing/Reaction single-color byte positions, and Hyprland touchpad isolation regex.
  - `CLAUDE.md`: Updated line count boundary target to `icarus/`.
  - `icarus/__init__.py`: Added package exports and version string (`1.0.0`).

- **Kanıt**:
  - Test gate: `python3 -m unittest discover tests` executed 42 tests in 1.739s with 0 errors.
  - Line count audit: `wc -l` confirmed all 13 modules in `icarus/` strictly <= 400 lines.
  - Distribution build: `scripts/build-dist.sh` generated fresh standalone executable `dist/icarus`, Debian package, and release tarball.
  - Live query: `~/.local/bin/icarus info` executed cleanly against hardware.

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Scroll Overhaul, Touchpad Isolation, RGB Color Sync & Full OemDrv Button Presets

- **Değişen alanlar (`path›symbol`)**:
  - `icarus/scroll.py›set_scroll_factor`: Expanded factor clamp from `min(10.0)` to `min(20.0)` with config path parameter. Strengthened regex to match and modify ONLY `hl.device({ name = "sinowealth-wired-gaming-mouse", ... })` and append cleanly if missing, strictly preserving `input.touchpad = { scroll_factor = 0.6 }` (99 lines).
  - `icarus/buttons.py`: Added `MULTI_CLICK = 0x33`, `MULTIMEDIA_ACTIONS`, `MULTIMEDIA_NAMES`, `SPECIAL_HW_ACTIONS`, `SPECIAL_HW_NAMES`. Extended `ButtonBinding.summary()` to format all multimedia (Play/Pause, Stop, Next, Prev, Vol+, Vol-, Mute, Media Player), Windows/Web (Explorer, Calc, Mail, Web Home/Search/Back/Forward/Refresh/Favorites), Double/Triple Click, and Hardware Toggles (Profile, Polling, Lighting ON/OFF/Effect/Color/Speed/Brightness). Added factory functions `make_multimedia_binding`, `make_special_binding`, `make_multiclick_binding` (319 lines).
  - `icarus/gui_macros.py›handle_button_bind`: Extended dispatcher to handle `multimedia`, `system`, `special`, and `multiclick` action payloads directly from the REST API (279 lines).
  - `icarus/config.py`: Added `SUPPORTED_RGB_EFFECTS` reflecting genuine unmasked hardware modes (`LedMask=0x1E8` in `Cfg.ini`). Fixed color synchronization in `serialize_config` for `BREATHING` mode (auto-syncing `single_color` to `breathing_colors[0]` and setting `b_count`) and `REACTION` mode (writing `single_color` to bytes 57..59) (338 lines).
  - `icarus/web/index.html`: Expanded Scroll slider to `0.2x..15.0x` with fast presets (`0.5x`, `1.0x`, `3.0x`, `6.0x`, `10.0x`, `15.0x`) and touchpad isolation notice. Redesigned Remap Modal with categorized action selectors for Mouse, Multimedia, Windows/Web, Hardware Switches, Fire Burst, Sniper Lock, and Macro.
  - `icarus/web/app.js`: Updated `RGB_NAMES` to unmasked modes, enabled single-color picker sync for Breathing and Reaction modes, added `setScrollPreset()`, and wired categorized Remap Modal with active binding auto-detection.
  - `icarus/web/style.css`: Added `.btn-preset` styling for scroll quick-select badges.
  - `tests/test_scroll.py`: Created unit tests verifying scroll factor clamping up to 15.0x and asserting `touchpad = { scroll_factor = 0.6 }` in `~/.config/hypr/input.lua` is 100% untouched.
  - `tests/test_buttons.py`: Added unit tests for multimedia presets, special hardware toggles, and multi-click bindings.
  - `tests/test_config.py`: Added unit tests for Breathing mode single-color auto-sync and Reaction mode color persistence.
  - `dist/icarus`: Rebuilt standalone distribution executable via `scripts/build-dist.sh` and updated `~/.local/bin/icarus`.

- **Kanıt**:
  - Unit tests: `python3 -m unittest discover tests` executed 42 tests in 1.619s with 0 errors.
  - Live hardware: `~/.local/bin/icarus info` executed cleanly against `/dev/hidraw2` showing `K6 -> Play / Pause` and `NEON` lighting.
  - Touchpad isolation: `hyprctl devices -j` confirmed `sinowealth-wired-gaming-mouse` has `scrollFactor: 5.00` while `syna32e4:00-06cb:cee7-touchpad` remains `-1.00` (backed by `scroll_factor = 0.6` in `input.lua`).
  - Line count audit: `wc -l` confirmed all 12 Python modules in `icarus/` strictly <= 400 lines (longest: `commands.py` 397 lines, `gui.py` 394 lines).
  - Distribution build: `scripts/build-dist.sh` generated fresh standalone executable `dist/icarus`, Debian package, and release tarball.

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Scroll Wheel Speed & LED Color Alignment / Channel Calibration

- **Değişen alanlar (`path›symbol`)**:
  - `icarus/scroll.py`: Created module implementing `get_scroll_factor()` and `set_scroll_factor(factor)` via Hyprland IPC (`hyprctl eval`) and persistent synchronization in `~/.config/hypr/input.lua` (87 lines).
  - `icarus/config.py`: Added `CHANNEL_ORDERS`, `permute_color_to_hw`, `permute_color_from_hw`, and `channel_order` field to `MouseConfig` for hardware LED pinout calibration (RGB, GRB, BGR) (324 lines).
  - `icarus/fileconfig.py`: Integrated `scroll_factor` and `channel_order` into declarative JSON schema, `mouse_to_dict`, and `apply_to_mouse` (217 lines).
  - `icarus/commands.py›cmd_scroll`: Added CLI scroll speed command (`icarus scroll [<factor>]`) (397 lines).
  - `icarus/cli.py`: Registered `scroll` CLI command parser and routing (133 lines).
  - `icarus/gui.py`: Added `POST /api/scroll` endpoint and compacted `RGB_MODES` (394 lines).
  - `icarus/web/index.html`: Added Scroll Wheel Speed slider to Performance tab, LED Channel Order Calibration dropdown to Lighting tab, and Zone 1 (Scroll wheel) vs Zone 2 (Perimeter strip) semantic banners.
  - `icarus/web/app.js`: Added debounced real-time hardware apply for color pickers (`debounceLiveApply`) and scroll speed slider (`debounceSetScroll`), eliminating the requirement to click "Apply All" for visual color preview.
  - `tests/test_scroll.py`: Automated unit test for scroll factor boundary clamping (0.1..10.0).
  - `tests/test_config.py`: Added unit tests for RGB, GRB, and BGR color permutations.
  - `dist/icarus`: Rebuilt standalone zipapp and updated `~/.local/bin/icarus`.

- **Kanıt**:
  - Unit tests: `python3 -m unittest discover tests` executed 36 tests with 0 errors.
  - Live hardware: `~/.local/bin/icarus scroll 1.4` set `scrollFactor: 1.40` in Hyprland and verified via `hyprctl devices -j`. Restored to 1.0.
  - Live color preview: Verified `permute_color_to_hw` maps pure Red to Green for GRB hardware strips and to Blue for BGR strips.
  - Line count audit: `wc -l` confirmed all 12 Python modules strictly <= 400 lines.

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Milestone 4 Fix: REST API Input Validation & Thread Crash Prevention

- **Değişen alanlar (`path›symbol`)**:
  - `icarus/gui.py›do_POST`: Validate non-empty JSON body and return HTTP 400 Bad Request on parsing failure or non-dict root object instead of silently falling back to empty dict.
  - `icarus/gui.py›_handle_switch_profile`: Validate profile integer within range 1..3, returning HTTP 400 Bad Request on invalid inputs (`"invalid"`, `999`) and catch hardware errors with HTTP 500 instead of thread termination.
  - `icarus/gui.py›_handle_import_bkm`: Safely parse `profile`, `path`, and base64 decode within `try...except (ValueError, binascii.Error, TypeError, OSError)` block, returning HTTP 400 Bad Request on decoding errors.
  - `icarus/gui.py›_handle_pull`, `_handle_apply`: Wrapped hardware operations in `try...except Exception as e:` returning HTTP 500 error payload on failure.
  - `dist/icarus`: Rebuilt standalone distribution executable via `scripts/build-dist.sh`.

- **Kanıt**:
  - Unit tests: `python3 -m unittest discover tests` executed 34 tests with 0 errors.
  - Verification: Adversarial script confirmed HTTP 400 Bad Request returned on malformed JSON, out-of-range profile, non-integer profile, and corrupted base64 string without socket drop or traceback.
  - Line count audit: `icarus/gui.py` is 396 lines (strictly <= 400 lines).

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Milestone 4: Frontend Redesign, Anti-AI-Slop Bento Layout & Accessibility (A11y)

- **Değişen alanlar (`path›symbol`)**:
  - `icarus/web/index.html`: Fully redesigned semantic markup featuring WAI-ARIA tablist/tab/tabpanel, accessible modal dialog (`role="dialog"`, `aria-modal="true"`, `aria-labelledby`), live announcements (`aria-live="polite"`), and 100vh fitted viewport layout eliminating double scrollbars.
  - `icarus/web/style.css`: Anti-AI-slop visual architecture with disciplined typography scale (11px, 12px, 13px, 14px), subtle 1px borders (`#27272a`), monochrome primary actions, high-contrast `:focus-visible` outlines, and `@media (prefers-reduced-motion: reduce)` support.
  - `icarus/web/app.js`: Enhanced interaction layer with WAI-ARIA keyboard navigation (Arrow keys, Home, End), accessible modal focus trap (Tab cycling, Esc close, Enter confirm, focus restore), 57 PMW3325 discrete DPI step magnetic snapping, dynamic parameter display for 11 RGB modes, and bugfix for inline color swatch callbacks (725 lines).
  - `icarus/web/macro.js`: Timeline macro editor with 16 hardware slots, loop mode selectors, live keyboard recorder, and .BKM drag-and-drop container support (287 lines).
  - `scripts/build-dist.sh`: Rebuilt distribution artifacts (`dist/icarus`, `dist/icarus_1.0.0_all.deb`, `dist/icarus-1.0.0.tar.gz`) embedding newly polished web assets. Installed to `~/.local/bin/icarus`.

- **Kanıt**:
  - Unit tests: `python3 -m unittest discover tests` executed 34 tests in 1.613s with 0 errors.
  - Live hardware: `dist/icarus info` and `~/.local/bin/icarus info` executed cleanly against `/dev/hidraw2` with exit 0.
  - Line count audit: `wc -l` confirmed all Python modules in `icarus/` strictly <= 400 lines (`icarus/gui.py`: 368 lines, `icarus/commands.py`: 387 lines).
  - Distribution build: `scripts/build-dist.sh` generated fresh 1.7MB standalone executable `dist/icarus`.

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Milestone 3: E2E Automated Unit Tests, Live Hardware Testing, and Distribution Build

- **Değişen alanlar (`path›symbol`)**:
  - `tests/test_e2e_mock.py`: Created comprehensive automated mock unit tests for Report 0x04 generation for all 11 RGB modes, dedicated register slice preservation across mode writes, all 57 PixArt PMW3325 discrete DPI steps and boundary formula snapping (400..10000), physical button calibration (K4/K5 pin swap, K8 Fire Key burst 0x17, K9 Sniper action 0xA6), and macro serialization (12-bit delay framing across 1..4095ms, event taxonomy, loop modes, 16 slots, 168 max events limit) (377 lines).
  - `tests/test_hardware_live.py`: Created live hardware integration tests targeting connected mouse at `/dev/hidraw2` with graceful skip if device node not found or permissions missing. Probes vendor node, verifies PSD string `0x56 0x39 0x30 0x31` ("V901"), active profile query (1 or 2), Profile 1 Config Block (Cmd 0x11) and Button Block (Cmd 0x12) reads, auto-backup persistence to `~/.local/state/icarusctl/`, and safe non-destructive write, read-back, and restore (160 lines).
  - `icarus/commands.py`: Updated `STATE_DIR` to `~/.local/state/icarusctl` (with mirror to `~/.local/state/icarus`) to adhere to CLAUDE.md invariant 3 and auto-backup safety verification (387 lines).
  - `scripts/build-dist.sh`: Validated distribution packaging, verifying standalone zipapp `dist/icarus`, Debian package, and source tarball with all 34 unit tests.

- **Kanıt**:
  - `python3 -m unittest discover tests` executed 34 tests in 1.615s with 0 errors.
  - `python3 -m unittest tests/test_e2e_mock.py` executed 9 mock packet tests in 0.001s with 0 errors.
  - `python3 -m unittest tests/test_hardware_live.py` executed 6 live hardware tests on `/dev/hidraw2` in 0.724s with 0 errors.
  - `scripts/build-dist.sh` generated `dist/icarus` (1.7MB zipapp), `dist/icarus_1.0.0_all.deb` (1.1MB), and `dist/icarus-1.0.0.tar.gz` (1.1MB).
  - `dist/icarus info` executed cleanly against live hardware with code 0.
  - Line count verification: all 11 source modules in `icarus/` and all 8 test suites in `tests/` strictly <= 400 lines.

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Milestone 2: Web GUI Frontend Macro Editor & Visual Integration

- **Değişen alanlar (`path›symbol`)**:
  - `icarus/gui.py`: Extended REST API endpoints (`GET /api/macros`, `POST /api/macros`, `POST /api/macros/flash`, `GET /api/config`, `POST /api/config`, `POST /api/bind`). Kept strictly at 357 lines (< 400 lines limit).
  - `icarus/gui_macros.py`: Created dedicated macro management helper module handling 16 onboard macro slots, JSON conversion, BKM import, and button binding (267 lines).
  - `icarus/web/index.html`: Anti-AI-slop bento container layout featuring Buttons, 57-step DPI, 11 RGB modes, Macro Studio timeline, Sensor performance, and Config/BKM (305 lines).
  - `icarus/web/style.css`: Disciplined typography scale, dark theme, high-contrast monochrome primary actions, tinted surfaces, crisp borders (`border-neutral-800`), zero overflow (167 lines).
  - `icarus/web/macro.css`: Dedicated styling for interactive Remap Modal, Macro Studio timeline cards, keystroke recording pulse, and BKM drag-and-drop dropzone (119 lines).
  - `icarus/web/app.js`: Refactored client-side application wiring for calibrated pins K1..K9 matching `mouse_nr.png`, discrete 57 PMW3325 DPI steps, 11 RGB modes with dynamic controls, and button remapping modal (346 lines).
  - `icarus/web/macro.js`: Timeline-based Macro Studio with 16 hardware slot selector, loop modes (Repeat N times, While held, Toggle), real-time interactive keystroke recording, event add/edit/del, and drag-and-drop BKM container importer (287 lines).
  - `tests/test_gui.py`: Added 4 automated unit tests covering `/api/status`, `/api/config`, `/api/macros`, `POST /api/macros`, `POST /api/bind`, and `POST /api/macros/flash` (195 lines).

- **Kanıt**:
  - Unit tests: `python3 -m unittest discover tests` ran 19 tests in 0.849s with 0 errors.
  - File limit verification: `wc -l` confirmed all Python, JS, CSS, and HTML source files are strictly <= 400 lines.
  - Verification: `python3 -m py_compile` validated syntax across all files with exit 0.

- **Kalan boşluk**:
  - Yok.

## 2026-10-29 — Desktop GUI Frontend, BKM Import & Package Rebrand

- **Değişen alanlar (`path›symbol`)**:
  - `icarus/`: Rebranded root package from `icarusctl` to `icarus`. Provided backwards-compatible `icarusctl` alias/symlink.
  - `icarus/bkm.py`: Reverse-engineered 32-round Tiny Encryption Algorithm (TEA) decryptor with constant key `[0x10022, 0x60F420, 0x3, 0x4]`. Verified decryption on `/run/media/hp/SSS/WIN/App_Configs/` (`LOL.bkm`, `OBSIDIAN.bkm`, `GENERAL.bkm`).
  - `icarus/fileconfig.py`: Declarative single-file configuration engine managing `~/.config/icarus/config.json` with two-way hardware sync (`pull_from_mouse` and `apply_to_mouse`).
  - `icarus/web/`: Embedded HTML5/CSS/JS frontend replicating original 1030x662 Windows canvas with interactive mouse pins K1..K9, 8-stage DPI sliders, RGB lighting effect selector, and drag-and-drop BKM importer.
  - `icarus/gui.py`: Lightweight Python stdlib `http.server` backend with REST API and automatic `--app` window launcher (Brave/Chrome/Chromium with fallback).
  - `icarus/commands.py`: Separated CLI command handlers keeping all files under the 400-line limit.
  - `icarus/cli.py`: Updated dispatcher with optional `cmd` (defaults to GUI on desktop display, info on headless) and `icarus help` manual.
  - `packaging/desktop/icarus.desktop` & `icarus/web/assets/icon.png`: XDG desktop entry and high-res icon.
  - `scripts/build-dist.sh` & `scripts/build-deb.py`: Built standalone executable zipapp `dist/icarus` (1.1MB) and Debian package `dist/icarus_1.0.0_all.deb` (795KB).
  - `tests/test_gui.py`: Added 4 automated unit tests for HTTP asset serving and REST endpoints.

- **Kanıt**:
  - Unit tests: `cd /home/hp/Work/MOUSE/icarusctl && python3 -m unittest discover tests` executed 15 tests in 0.535s with 0 errors.
  - CLI execution: `icarus help` and `icarus info` executed via user PATH (`~/.local/bin/icarus`).
  - Declarative sync: `icarus pull` created `~/.config/icarus/config.json`, and `icarus apply` successfully committed blocks to mouse hardware flash.
  - BKM import: `icarus import-bkm /run/media/hp/SSS/WIN/App_Configs/OBSIDIAN.bkm --profile 2` decrypted macros `ctrlo`, `seskonusma`, `crtlp`, `ctrlq` and flashed to hardware.
  - GUI verification: HTTP test confirmed `GET /`, `GET /assets/icon.png`, and `GET /api/status` return live mouse state.

- **Kalan boşluk**:
  - Yok.
