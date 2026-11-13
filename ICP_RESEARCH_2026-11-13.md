# Gamepower Icarus (BY8948 / SH68F89Q) ICP/JTAG Kurtarma Araştırması

**Tarih:** 2026-11-13  
**Hedef Cihaz:** Gamepower Icarus Gaming Mouse (`VID:PID = 258A:0027`, Bootloader `0603:1021`)  
**MCU:** Sinowealth `BY8948-00006` / `SH68F89Q` (48-pin LQFP, 8051 çekirdek, 64 KB Flash: `0x0000..0xEFFF` uygulama + `0xF000..0xFFFF` USB ISP bootloader)  
**Programlayıcı Donanımı:** Arduino Uno (`ATmega328P`, `CH340 COM5`)  

---

## 1. Mevcut Durum ve Kök Sorun Özeti

1. **Brick Sebebi:** USB ISP üzerinden yazma sırasında ilk 6 byte'a yanlış `-0x5A` ofseti uygulanması nedeniyle `0x0000`'daki reset vektörü `02 2E 34` (`LJMP 0x2E34`) yerine `02 FE FE` (`LJMP 0xFEFE`) olarak bozuldu. `0xFEFE` adresinde `0x22` (`RET`) bulunduğu için MCU açılışta `0x0000 <-> 0xFEFE` arasında sonsuz döngüye giriyor ve USB init/bootloader koduna hiç ulaşamıyor.
2. **İkincil Donanım Sorunu (Önceki `dx/dy` Kilidi):** Alt kısımdaki `U5` LOD sensör arızası `P1.5 = 1` tuttuğu için imleç hareketi kilitleniyordu. `0x0800..0xEFFF` bölgesinde `0x4760 -> SJMP 0x4770` LOD bypass yaması mevcut; yalnızca `0x0000` vektörünün (`02 2E 34 30 33 04 8F 34 D2 4C 22 02 2A EE E4 F5`) düzeltilmesi veya Sector 0'ın silinip USB ISP (`0603:1021`) ile `firmware_patched_60k.bin` atılması yeterli.

---

## 2. Doğrulanmış Fiziksel Bağlantı (`CON6` ↔ Arduino Uno)

Multimetre ve pin taramalarıyla doğrulanan `CON6` pin dizilimi:

| `CON6` Pin | İşlev | Arduino Uno | Direnç / Not |
|---|---|---|---|
| **Pin 1** | `VDD` (`5.0V`) | `5V` (veya anahtarlı `5V`) | USB takılıyken `5.0V` ölçüldü (`3.3V` değil!) |
| **Pin 2** | `TCK` | `D5` (`PD5`) | `1kΩ` seri direnç |
| **Pin 3** | `TDI` | `D4` (`PD4`) | `1kΩ` seri direnç |
| **Pin 4** | `TMS` | `D3` (`PD3`) | `1kΩ` seri direnç |
| **Pin 5** | `TDO` | `D2` (`PD2`) | Doğrudan bağlantı |
| **Pin 6** | `GND` | `GND` | USB kalkanı ile kısa devre doğrulandı |

> **Güvenlik Kuralı:** Mouse'un kendi USB kablosu PC'ye takılıyken Arduino'dan kesinlikle `VDD` (`5V` / GPIO) beslemesi verilmez.

---

## 3. Derin Araştırma Bulguları (`karstx/sinodude`, `gashtaan`, `isp_dump_fixed.bin`)

### 3.1. `D6` Pininden Besleme Neden Başarısız Oldu?
- `karstx/sinodude` (`src/parts/sh68f89.rs`) verisine göre `SH68F89` varsayılan Code Option (`00 20 03 8c`) ayarında **`OP_LVRLEVEL = 1` (3.7V Low-Voltage Reset)** aktiftir.
- `3.3V` ile denemelerde MCU donanımsal LVR kilidinde kaldığı için hiç uyanmaz.
- `D6` GPIO pini doğrudan hedefe bağlandığında ise ATmega328P pin akım sınırı (~25–40 mA) ve iç çıkış direnci nedeniyle mouse PCB'sinin (MCU + `PMW3325` + `U5` + dekuplaj kondansatörleri) ilk akımında voltaj **3.7V altına çöktü** (`D4 = 0` gözlemlendi).
- Bu nedenle `sinodude` şemasında `D6` doğrudan hedef `VDD`'ye değil, **`5V` hattını süren bir P-kanallı MOSFET** kapısına bağlanır (`10kΩ` pull-up ile).

### 3.2. `5V` Pininde Manuel Tetikleme Neden Başarısız Oldu?
1. **Çok Dar ICP Giriş Penceresi:** `gashtaan/sinowealth-8051-dumper` dokümantasyonuna göre SinoWealth 8051 MCU'ları güç verildikten sonraki **yalnızca ilk birkaç on milisaniye (~10–50 ms)** içinde ICP el sıkışmasını kabul ediyor.
2. **Contact Bounce + `0 µs` Tetikleme:** `icp_trig2` skeci `D4` yükseldiği `0 µs` anında hemen `connect()` başlatıyordu; oysa jumper elle `5V` pinine takılırken ilk 1–3 ms mekanik sıçrama (**contact bounce**) yaşanır ve PCB kapasitörleri henüz dolmamıştır. `sinodude` güç açılışından sonra **`5 ms` + `3 ms`** stabilizasyon bekler.
3. **Kapasitör Deşarj Süresi (`POWER_SETTLE`):** `sinolink.rs` yorumuna göre bazı kartlarda `VDD` kapasitörleri yük tuttuğu için soğuk ICP girişi öncesi gücün en az **`1500 ms` (1.5–2 sn)** tamamen kesilmesi gerekir.
4. **Protokol Uyumsuzlukları (`SH68F881` vs `SH68F89`):**
   - `TDO (D2)` pini `INPUT` değil **`INPUT_PULLUP`** olmalı (`pd2.into_pull_up_input()`).
   - `connect()` darbe sayıları `25600 / 25600` değil, **`20480` TMS + `1644` TCK** olmalı.
   - `check()` fonksiyonunda `0x41 0xFF` ardından **ekstra bir `0xFF`** gönderilmeli ve `0x43` sonrası 2 byte (`response` + dummy) okunmalı (`response == 0x69`).
   - `Mode::Jtag` (`start_mode = 165`) ile **`0x6161` JTAG ID** okuması `SH68F89` varlığını doğrulamak için kullanılabilir.

### 3.3. `sh68f89.rs` ve `isp_dump_fixed.bin` Detayları
- **Part Specs:** `jtag_id = 0x6161`, `chip_type = 0x02`, `sector_size = 1024`, `flash_size = 65536`, `custom_block = 0x03`, `compatible_voltages = [5.0V, 3.3V]`.
- **Code Options:**
  - `OP_RST` (Byte 0 bit 5): `0 = Pin 7.0 RST pini`, `1 = I/O pini`.
  - `OP_ISPPIN` (Byte 3 bit 6): `1 = P3.4 ve P3.5 aynı anda GND iken ISP`, `0 = Doğrudan ISP`.
- **Bootloader (`0xF000`):** `isp_dump_fixed.bin` içinde `0xF000` adresi `0xEFFB == 0x02` kontrolü yapıyor; `0xFFED` -> `02 EF FB`, `0xFFF2` -> `02 00 00`. Uygulama normalde `0x0000` üzerinden başladığı için `0x0000` (`02 FE FE`) düzeltilmeden USB ISP açılmıyor.

---

## 4. Uygulanan Kesin Çözüm ve Kurtarma Sonucu (2026-11-13)

1. **Darbeli ESD Diyot Tetikleyicisi (MOSFET ve Ekstra Kablo Olmadan):**
   - `D2 (TDO)` pini sürekli `INPUT_PULLUP` yapıldığında PCB kondansatörlerini 0.5–0.7 sn içinde şarj ettiği için `1500 ms` deşarj sayacı tamamlanamıyordu.
   - Çözüm olarak `D2` pini yalnızca **5 ms'de bir `30 µs` `INPUT_PULLUP`** ile örneklendi: `Pin 1` çıkarıldığında iç ESD diyodu `TDO`'yu kararlı biçimde `0` tuttu (`VDD_OFF_1500MS_ARMED`), `Pin 1` `5V`'a takıldığı milisaniyede `TDO=1` (`VDD_ON_TRIG`) yakalandı ve Arduino Uno bootloader gecikmesi tamamen baypas edildi.
2. **Doğrulanan ICP/JTAG ve Sector 0 Onarımı (`icp_repair_sector0.ino`):**
   - **`ICP=0x69`**, **`JTAG_ID=0x6161`** (`SH68F89`) ilk denemede doğrulandı.
   - Mevcut Flash başı `02 F0 00 D6 D9 AA 8F 34 ...` olarak okundu ve `0x4760` adresindeki LOD bypass yaması (`80 0E 00 30 3A 0A E4 F5`) doğrulandı.
   - Sector 0 (`0x0000..0x03FF`) silindi (`ERASE_STATUS=0x0`), `firmware_backup/firmware_patched_60k.bin` dosyasındaki ilk 1024 byte echo doğrulamasıyla yazıldı (`WRITE_1024_OK`) ve geri okunarak **`VERIFY_MISMATCHES=0`** (`NEW_FLASH0=02 2E 34 30 33 04 8F 34 D2 4C 22 02 2A EE E4 F5`) ile onaylandı (**`REPAIR_SUCCESS`**).
   - Fare USB üzerinden **`VID_258A&PID_0027`** olarak tüm HID/klavye/fare/yapılandırma arayüzleriyle **`OK`** durumunda geri geldi.

---

## 5. Kesin Kurallar, Sınırlar ve Çıkarılan Dersler (Post-Mortem)

> Tüm kalıcı ajan kuralları [CLAUDE.md](file:///c:/Users/HP/Desktop/ICARUS/CLAUDE.md) §3 içine işlenmiştir.

1. **Asla Dokunulmayacaklar:**
   - `0xF000..0xFFFF` USB ISP bootloader bölgesine ve `OP_LVRLEVEL / OP_RST / OP_ISP / OP_ISPPIN` Code Option bitlerine kullanıcı onayı ve tam doğrulama olmadan **asla** yazma/silme yapılmaz.
   - Sector 0 (`0x0000..0x03FF`) üzerine yazılacak veride `0x0000..0x0002` reset vektörü (`02 2E 34`) byte-byte doğrulanmadan flash komutu gönderilmez.
2. **Reverse Engineering ve Bootloader Kuralları:**
   - Bootloader/ISP dönüşümleri (`-0x5A` gibi ofsetler, şifreleme, paket başlıkları) tahminle değil, **tam disassembly + salt-okunur dry-run** ile kanıtlanmadan gerçek cihaza uygulanmaz.
   - Her flash yazımı sonrası **echo + readback doğrulaması (`VERIFY_MISMATCHES=0`)** zorunludur.
3. **Donanım / Elektriksel Sınırlar:**
   - Fare USB'si PC'ye takılıyken Arduino `5V`/GPIO üzerinden `CON6 Pin 1`'e **asla** güç verilmez.
   - `SH68F89` `3.7V` LVR (`OP_LVRLEVEL=1`) nedeniyle `3.3V` ile veya akım sınırı olan tek bir Arduino GPIO pini (`D6`) ile doğrudan beslenmez.
