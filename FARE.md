# FARE.md — Gamepower Icarus (258A:0027) Tam Kapsamlı 8051 Firmware, Donanım Haritası ve Kurtarma Rehberi

> **Özet (Gelecek Ajanlar İçin Tek Bakışta Durum):**
> 1. **Donanım:** Gamepower Icarus (`VID_258A&PID_0027`), **Sinowealth SH68F89** 8051 MCU (64 KB Flash, 2 KB silme sayfası, `0xF000..0xFFFF` ISP Bootloader MD5 = `571ea8b315654c39046e4cc3b1e43777`) kullanmaktadır.
> 2. **Çift Sensör Mimarisi:** Farede **iki ayrı sensör** vardır:
>    - **Sensör 1 (Ana Optik):** PixArt PMW3325DB-TWV1 (3-telli bit-banged SPI: `P2.4` NCS, `P2.3` SCLK, `P2.1` SDIO). Görünmez 850nm IR LED kullanır.
>    - **Sensör 2 (Alt LOD Yakınlık Sensörü):** I2C (`P1.6` SCL, `P1.7` SDA, adres `0x20`/`0x21`, Chip ID `reg[0x00] == 0x63`) ve dijital lift-off çıkışı **`P1.5` (`bit_0x95`)** üzerinden bağlı ayrı bir yakınlık sensörüdür (altta 3 Hz yanıp sönen görünür ışık budur).
> 3. **Kanıtlanan Kök Neden (`dx/dy == 0`):** Canlı donanımda yapılan `p2_b1` `b11 = 0x38` testi ile MCU'nun açılışta PMW3325'ten `Product_ID == 0x43` okuduğu ve **`dir_0x43 == 0x0B`** yaptığı **%100 kanıtlandı**. PMW3325 ve SPI hattı sağlamdır. Hareketi kesen tek yer `0x473F` içindeki **`0x4760` (`JNB bit_0x95, 0x4770` / `JNB bit_0x3a, 0x4770`)** alt LOD sensörü kapısıdır (`P1.5 == 1` takılı kaldığı için `0x4766..0x476F` her ankette `dir_0x4b..0x4e` `dx/dy` baytlarını sıfırlar).
> 4. **Mevcut Durum (ISP Yazma Hatası ve Kurtarma):** `0x473F` ve `0x4760` yamalarını (`firmware_patched_60k.bin`) ISP üzerinden yazarken, bootloader'ın okuma (`0xFD79`) ve yazma (`0xF380`) arasındaki **ilk 6 bayt asimetrisi** yüzünden `0x0000..0x0002` reset vektörü `02 2E 34` (`LJMP 0x2E34`) yerine `02 FE FE` (`LJMP 0xFEFE`, `0xFEFE: 22` = `RET`) olarak yazıldı. Bu nedenle MCU açılışta `0x0000 <-> 0xFEFE` arasında sonsuz döngüde kalmakta ve USB'yi başlatamamaktadır.
> 5. **Kurtarma:** Orijinal 64 KB fabrika dökümü (`firmware_backup/isp_dump_fixed.bin`) ve tamirli 60 KB imaj (`firmware_backup/firmware_patched_60k.bin`) eksiksizdir. Herhangi bir Arduino / ESP32 / RP2040 ile PCB üzerindeki 4 ICP/JTAG pininden (`VDD`, `GND`, `TCK`, `TMS`, `TDI`, `TDO`) `firmware_patched_60k.bin` (veya `isp_dump_fixed.bin`) yazıldığı anda hem USB (`258A:0027`) hem de `dx/dy` imleç hareketi doğrudan çalışacaktır.

---

## 1. Çalışma Ortamı ve Araç Kuralları

- **Ortam:** Windows 11 üzerinde WSL2 Debian 13 (`trixie`).
- **WSL Kısıtları:** WSL içinde `/dev/hidraw*` ve `python3` yoktur; ikili analiz ve disassembler işlemleri için `node` (`v22.23.4`) kullanılır.
- **USB HID Erişimi (Windows PowerShell P/Invoke):**
  - **KURAL 1 (`< /dev/null`):** Her `powershell.exe` çağrısının sonuna mutlaka `< /dev/null` eklenmelidir; aksi halde WSL stdin yüzünden süreç asılı kalır.
  - **KURAL 2 (`Win32_PnPEntity`):** `Get-PnpDevice` yerine `Get-CimInstance Win32_PnPEntity` kullanılmalıdır.
  - **KURAL 3 (`ToLowerInvariant()`):** Türkçe Windows yerelinde `"I".ToLower()` -> `"ı"` (noktasız ı, `0x0131`) ürettiği için `HID\VID_...` yolu `\\?\hıd#vıd_...` olur ve `CreateFile` `ERROR_FILE_NOT_FOUND (2)` döner! PowerShell içinde string küçültürken **her zaman `.ToLowerInvariant()`** kullanılmalıdır.
  - **KURAL 4 (`0xC0000000u`):** `CreateFile` erişim bayrağı C# yardımcı metodu içinde `0xC0000000u` olarak çağrılmalıdır.

---

## 2. Kalıcı Dosya Envanteri (`/home/hp/projects/icarus/`)

### A. `/home/hp/projects/icarus/firmware_backup/`
| Dosya | Boyut | Açıklama |
| :--- | :--- | :--- |
| [`isp_dump_fixed.bin`](file:///home/hp/projects/icarus/firmware_backup/isp_dump_fixed.bin) | 65,536 B | **Tam 64 KB Orijinal Fabrika ROM Dökümü** (`0x0000..0xFFFF`). Her `0x800` sayfanın `6..2047` baytlarından `0x5E` çıkarılmış gerçek 8051 makine kodu + `0x8000..0xAC00` veri flash blokları + `0xF000..0xFFFF` SH68F89 ISP Bootloader. |
| [`isp_dump.bin`](file:///home/hp/projects/icarus/firmware_backup/isp_dump.bin) | 65,536 B | ISP `GetFeature(0x06)` (`0x72`) ile çekilen ham 64 KB döküm (`-0x5E` dönüşümü öncesi). |
| [`firmware_original_60k.bin`](file:///home/hp/projects/icarus/firmware_backup/firmware_original_60k.bin) | 61,440 B | Orijinal `0x0000..0xEFFF` 60 KB ana firmware dilimi. |
| [`firmware_patched_60k.bin`](file:///home/hp/projects/icarus/firmware_backup/firmware_patched_60k.bin) | 61,440 B | **Tamirli 60 KB Firmware (JTAG/ICP için hazır):** `0x473F` (`d2 3b 00`), `0x4760` (`80 0e 00` — LOD kesici bypass) ve `0xEFFB` (`02 2e 34`) yamaları uygulanmış gerçek 8051 makine kodu. |
| [`firmware_patched_60k_isp.bin`](file:///home/hp/projects/icarus/firmware_backup/firmware_patched_60k_isp.bin) | 61,440 B | **Tamirli 60 KB Firmware (USB ISP `0x77` için hazır):** Tüm 2048 baytına `+0x5A` uygulanmış ISP yükleme imajı. |
| [`sinowisp.exe`](file:///home/hp/projects/icarus/firmware_backup/sinowisp.exe) | 1,522,176 B | `karstx/sinowisp` v2.1.0 Windows x64 ikilisi. |
| [`scripts/isp_enter.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/isp_enter.ps1) | — | Normal modda (`258A:0027`) `MI_01&Col05` üzerinden `05 75 00 00 00 00` göndererek ISP moduna (`0603:1021`) sokan script. |
| [`scripts/isp_dump.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/isp_dump.ps1) | — | ISP modunda 32 sayfayı (`0x0000..0xFFFF`) salt-okunur (`0x52` + `0x72`) okuyan script. |
| [`scripts/isp_flash_patch.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/isp_flash_patch.ps1) | — | ISP üzerinden `0x45` silme, `0x57`/`0x77` 30 sayfa yazma, `0x52`/`0x72` doğrulama, `0x55` (`0xEFFB` etkinleştirme) ve `0x5A` reboot scripti. |
| [`scripts/isp_rescue_watch.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/isp_rescue_watch.ps1) | — | Cihaz `VID_0603&PID_1021` olarak göründüğü salisede yakalayıp `firmware_patched_60k_isp.bin` yazan kurtarma bekçisi. |
| [`scripts/readonly.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/readonly.ps1) | — | `258A:0027` üzerinde PSD (`0x01`), aktif profil (`0x02`) ve 4 veri bloğunu (`0x11, 0x12, 0x21, 0x22`) okuyan script. |
| [`scripts/restore.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/restore.ps1) | — | 4 fabrika bloğunu (`p1_b1, p1_b2, p2_b1, p2_b2`) `0x7B` / `0x50` magic ile yazıp doğrulayan script. |
| [`scripts/test_dir43.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/test_dir43.ps1) | — | `p2_b1` `b11 = 0x38` yazarak açılışta `0x4A2E`'nin `dir_0x43 == 0x0B` kontrolünü test eden script. |

### B. `/home/hp/projects/icarus/setup/`
Windows kurulum paketinden (`Gamepower ICARUS Software Setup.exe`) çıkarılan tüm dosyalar:
- `OemDrv.exe` (Ana Windows GUI sürücüsü)
- `Lowerdev.dll`, `MenuEx.dll`, `InitSetup.dll`, `uninstall.dll`
- `Cfg.ini` (`VID=258A, PID=0027`, `Sensor=3325`, `LedMask=0x1E8`), `text.xml`, `text_utf8.xml`, `skins/`
- `oemdrv.asm` (`OemDrv.exe` tam x86 disassembly dökümü)
- `localappdata/BY-COMBO2/` (Varsayılan profil/konfigürasyon şablonları)

---

## 3. SH68F89 64 KB Flash Bellek Haritası ve XRAM Düzeni

### A. 64 KB Flash Haritası (`isp_dump_fixed.bin`)

| Flash Adresi | Boyut | Sektör (1 KB) | İçerik | Firmware Referansı |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000..0x5132` | 20,787 B | `0x0000..0x53FF` | **Ana 8051 Program Kodu** (`0x0000: 02 2E 34` = `LJMP 0x2E34`, Keil C51 init `0x2E89`, `main` @ `0x3943`) | Reset vektörü `0x0000` |
| `0x4DE5..0x4DE8` | 4 B | — | Firmware PSD sabiti: `"V901"` (`56 39 30 31`) | `0x1B08` (Opcode `0x01`) |
| `0x508B..0x5092` | 8 B | — | Fabrika varsayılan DPI tablosu: `04 07 09 0E 13 1D 27 31` | `0x4A2E` / `0x3EA1` |
| `0x5133..0x7FFF` | 11,981 B | `0x5400..0x7FFF` | `0x00` (Boş) | — |
| `0x8000..0x804F` | 80 B | `0x8000..0x83FF` | **Profil 1 Buton Bloğu** (Opcode `0x12`) | `0x45C7` siler/yazar (`XRAM[0x0130..0x017F]`) |
| `0x8100..0x814F` | 80 B | `0x8000..0x83FF` | **Profil 2 Buton Bloğu** (Opcode `0x22`) | `0x45C7` siler/yazar (`XRAM[0x0180..0x01CF]`) |
| `0x8400..0x8484` | 133 B | `0x8400..0x87FF` | **Profil 1 Config Bloğu** (Opcode `0x11`) | `0x4609` siler/yazar (`XRAM[0x0000..0x0084]`) |
| `0x8500..0x8584` | 133 B | `0x8400..0x87FF` | **Profil 2 Config Bloğu** (Opcode `0x21`) | `0x4609` siler/yazar (`XRAM[0x0085..0x0109]`) |
| `0x8800` | 1 B | `0x8800..0x8BFF` | **Aktif Profil Kaydı** (`0x01` veya `0x02`) | `0x4CA8` okur, `0x4C81` yazar |
| `0x8C00..0x8FFF` | 1 KB | `0x8C00..0x8FFF` | **Gun / Recoil Tablosu** (Opcode `0x32` / `0x25`) | `0x1B8E` / `0x39F8` |
| `0x9400..0x9425` | 38 B | `0x9400..0x97FF` | **İkincil Tablo** (`flash[0x9425] == 0x55` ise aktif, normalde `0x00`) | `0x48C8` |
| `0x9800..0xAC00` | 5 × 1 KB | `0x9800..0xABFF` | **Onboard Makro Yuvaları** (Opcode `0x30`, salt-yazılır, `0x3F5F` siler/yazar) | `0x1B80` -> `0x3F5F` |
| `0xEFFB..0xEFFF` | 5 B | `0xEC00..0xEFFF` | Bootloader uygulama atlama vektörü (`LJMP 0x2E34`) | `0xF015` / `0xFFED` |
| `0xF000..0xFFFF` | 4,096 B | `0xF000..0xFFFF` | **Sinowealth SH68F89 ISP Bootloader** (`VID_0603&PID_1021`) | `0x50FA -> LJMP 0xFF00` |

### B. XRAM Bellek Haritası (Çalışma Zamanı)

| XRAM Adresi | Boyut | İçerik | İlgili Fonksiyonlar |
| :--- | :--- | :--- | :--- |
| `0x0000..0x0084` | 133 B | **Profil 1 Config Bloğu Gölgesi** (`config[8..140]` -> `XRAM[0x0000..0x0084]`) | `0x420C` flash'tan kopyalar, `0x4609` flash'a yazar |
| `0x0085..0x0109` | 133 B | **Profil 2 Config Bloğu Gölgesi** (`config[8..140]` -> `XRAM[0x0085..0x0109]`) | `0x420C` flash'tan kopyalar, `0x4609` flash'a yazar |
| `0x010A..0x012F` | 38 B | Gun / Recoil çalışma tamponu | `0x1B96` |
| `0x0130..0x017F` | 80 B | **Profil 1 Buton Bloğu Gölgesi** (`buttons[8..87]` -> `XRAM[0x0130..0x017F]`) | `0x48C8` flash'tan kopyalar, `0x45C7` flash'a yazar |
| `0x0180..0x01CF` | 80 B | **Profil 2 Buton Bloğu Gölgesi** (`buttons[8..87]` -> `XRAM[0x0180..0x01CF]`) | `0x48C8` flash'tan kopyalar, `0x45C7` flash'a yazar |
| `0x01D0..0x03BB` | 492 B | Makro yazma/çalıştırma tamponu (Opcode `0x30`) | `0x1B85`, `0x3F5F` |
| `0x03BC..0x043B` | 128 B | Aktif profil buton/makro çalışma tablosu | `0x0385` |
| `0x043C..0x04BF` | 132 B | Aktif profil çözümlenmiş parametreleri (`0x0446..0x0455` DPI tablosu, `0x0485` LED modu, `0x049B` parlaklık) | `0x0385`, `0x1E42`, `0x1014` |
| `0x052E` | 1 B | Son SPI/I2C sensör kimlik okuması (`0x3482` / `0x34C8` / `0x4541`) | `0x345F` |
| `0x0540..0x0547` | 8 B | USB Feature Report `0x04` başlık tamponu (`[0x04, op, 0x00, magic, ...]`) | `0x1C34`, `0x1B40..0x1B95` |

---

## 4. 8051 Firmware Tam Fonksiyon Haritası (`0x0000..0x5132`)

### A. Açılış (Boot) Sırası (`0x0000 -> 0x2E34 -> 0x3943`)
1. **`0x0000`:** `02 2E 34` (`LJMP 0x2E34`) — Keil C51 başlangıç kodu XRAM/IRAM'i sıfırlar ve `0x3943` (`main`) fonksiyonuna atlar.
2. **`0x3943` (`main` başlatma sırası):**
   - `12 31 21` (`LCALL 0x3121`): Saat, port yönleri (`P0/P1/P2/P3`), zamanlayıcılar ve USB donanımını başlatır.
   - `12 4F E3` (`LCALL 0x4FE3`): **Optik Sensör Algılama ve Başlatma:**
     - `0x345F` fonksiyonunu çağırır:
       1. Önce `0x33DA` ile eski sensör ailesini (`Product_ID == 0x09` -> `dir_0x43 = 0x02`) dener.
       2. Bulamazsa `0x4FA4` ile SPI pinlerini hazırlar, `0x32C9` ile reg `0x3A`'ya `0x5A` (Power_Up_Reset) yazar, 1 ms (`0x03E8`) bekler, reg `0x18`'e `0x39` yazar, 50 ms bekler.
       3. `0x37DF` ile reg `0x00` (`Product_ID`) kaydını 10 defaya kadar okur, `XRAM[0x052E]`'ye yazar.
       4. Okunan değer **`0x43` (PixArt PMW3325)** ise **`dir_0x43 = 0x0B`** (`0x34CF: 75 43 0B`) yapar ve `dir_0x31 = dir_0x43` kaydeder.
     - `0x4FE6`: `dir_0x43 == 0x0B` ise **`LCALL 0x3D16`** çağırarak `0x3895..0x38CE` tablosundaki 29 adet PMW3325 başlangıç kaydını SPI üzerinden yükler.
   - `12 47 79` (`LCALL 0x4779`): LED PWM / Timer kayıtlarını başlatır.
   - `12 4C A8` (`LCALL 0x4CA8`): Flash `0x8800` adresinden aktif profili (`dir_0x47`) okur.
   - `12 48 C8` (`LCALL 0x48C8`): Flash `0x8000` ve `0x8100`'den buton bloklarını `XRAM[0x0130]` ve `XRAM[0x0180]`'e kopyalar.
   - `12 42 0C` (`LCALL 0x420C`):
     - Flash `0x8400` ve `0x8500`'den config bloklarını `XRAM[0x0000]` ve `XRAM[0x0085]`'e kopyalar.
     - Eğer `XRAM[0x0000] != 0x64` ise (`0x423E`) `R7=1` ile **`LCALL 0x4A2E`** ve **`LCALL 0x4609`** çağırır.
     - Eğer `XRAM[0x0085] != 0x64` ise (`0x424E` — P2'de `b8 = 0x00` olduğu için her açılışta burası çalışır!) `R7=0` ile **`LCALL 0x4A2E`** ve **`LCALL 0x4609`** çağırır:
       - **`0x4A2E`:** `MOV A, dir_0x43; ADD A, #0xF5; JNZ 0x4A5E` -> **Sadece `dir_0x43 != 0x0B` ise** `XRAM[0x0088]` (`p2_b1` `b11` baytı) değerini `0x28` ile ezer ve `0x4609` ile flash'a yazar! **`dir_0x43 == 0x0B` ise `0x4A5E`'ye (`RET`) atlar ve `b11` baytına dokunmaz!**
   - `12 50 7A` (`LCALL 0x507A` -> `0x4C81` -> `0x0385` + `0x1E42`): Aktif profilin config ve buton ayarlarını XRAM'den çalışma kayıtlarına yükler.

### B. Ana Döngü (`0x397B..0x39B5`)
Ana döngü `0x397B` adresinde sürekli döner:
- `LCALL 0x237B`: USB uyku / suspend kontrolü.
- **`LCALL 0x210D` (`0x210D..0x2242`):** **USB Endpoint 1 (Fare Paketi) Göndericisi:**
  - `bit_0x4c == 1` ise (`0x2118: JB bit_0x4c`), `dir_0x4a` (butonlar), `dir_0x4b:0x4c` (`dx`), `dir_0x4d:0x4e` (`dy`), `dir_0x34` (tekerlek) verilerini EP1 FIFO'suna (`0x0B48`) yazar, USB gönderimini tetikler (`ORL 0xAA, #0x04`) ve `dir_0x4b..0x4e`'yi sıfırlar.
- `LCALL 0x124E`: USB Endpoint 2 (Klavye / Medya / Report `0x07` OSD bildirimi: `0x1312: JB bit_0x35` ise `[0x07, dir_0x47, (dir_0x43 << 4) | dir_0x42, 0, 0, 0]`) göndericisi.
- **`LCALL 0x2FFE` (`0x2FFE..0x308F`):** **Alt LOD Yakınlık Sensörü (I2C `0x20`/`0x21`) Okuma ve Kalibrasyon Döngüsü:**
  - `bit_0x3a == 0` ve `bit_0x67 == 1` iken I2C üzerinden `reg[0x10]` değerini 10 kez toplar, ortalamasını `0x007D` (125) ile karşılaştırıp `reg[0x05]` kazancını ayarlar; `0x007D`'ye ulaştığında **`SETB bit_0x3a`** (`0x3079`) yapar!
- `LCALL 0x3B06`: USB Feature Report `0x04` / `0x05` üzerinden gelen flash yazma bayraklarını (`bit_0x51` profil değişimi, `bit_0x59` config flash yazımı `0x4609`, `bit_0x53` buton flash yazımı `0x45C7`, `bit_0x56` makro flash yazımı `0x3F5F`) işler.
- `LCALL 0x1014`: RGB LED animasyon motoru (`XRAM[0x0485]` moduna göre `0..10` dallanma tablosu).
- **`LCALL 0x48FE` (`0x48FE..0x4932`):** Polling rate zamanlayıcı bayraklarına (`bit_0x5c..0x5f`) göre **`LCALL 0x473F`** (Sensör Hareket Okuma) çağırır.
- `LCALL 0x2246`: Fiziksel buton matrisi (`P0.2, P0.3, P0.4, P1.7, P1.6, P1.4, P1.5, P0.5`) tarayıcısı. Sol+Sağ+Orta tuşa (`bit_0x10, 0x11, 0x12`) ~3 saniye (`0x96` = 150 döngü) basılı tutulursa `SETB bit_0x41` (`0x2378`) yapar.
- `LCALL 0x4CF4`: `bit_0x41 == 1` ise `LCALL 0x3B74` çağırarak alt I2C LOD sensörünü (`reg[0x00] == 0x63` ise `SETB bit_0x67`) yeniden kalibre eder.

---

## 5. İki `dx/dy` Kesme Kapısı ve Uygulanan Yama (`0x473F..0x4778`)

`0x473F` fonksiyonunun orijinal makine kodu:
```text
473f: 30 3b 12     JNB bit_0x3b, 0x4754   ; KİLİT 1: bit_0x3b == 0 ise sensör okumasını atla!
4742: e5 43        MOV A, dir_0x43
4744: 24 f5        ADD A, #0xF5           ; dir_0x43 == 0x0B kontrolü
4746: 60 09        JZ 0x4751              ; 0x0B ise 0x4751 -> LCALL 0x3567
4748: 24 09        ADD A, #0x09
474a: 70 08        JNZ 0x4754
474c: 12 33 54     LCALL 0x3354
474f: 80 03        SJMP 0x4754
4751: 12 35 67     LCALL 0x3567           ; PMW3325 Burst Read (0x2F68) + Self-Healing (0x3D16)
4754: e5 4c        MOV A, dir_0x4c        ; dx_lo
4756: 45 4b        ORL A, dir_0x4b        ; dx_hi
4758: 70 06        JNZ 0x4760
475a: e5 4e        MOV A, dir_0x4e        ; dy_lo
475c: 45 4d        ORL A, dir_0x4d        ; dy_hi
475e: 60 18        JZ 0x4778              ; Hareket yoksa çık
4760: 30 95 0d     JNB bit_0x95, 0x4770   ; KİLİT 2: P1.5 (LOD pini) == 1 VE
4763: 30 3a 0a     JNB bit_0x3a, 0x4770   ;          bit_0x3a == 1 ise:
4766: e4           CLR A                  ;          dx/dy'yi TAMAMEN SIFIRLA!
4767: f5 4b        MOV dir_0x4b, A
4769: f5 4c        MOV dir_0x4c, A
476b: f5 4d        MOV dir_0x4d, A
476d: f5 4e        MOV dir_0x4e, A
476f: 22           RET
4770: 12 26 90     LCALL 0x2690           ; Sensör yön dönüşümü
4773: 12 1f b8     LCALL 0x1FB8           ; Jitter filtresi
4776: d2 4c        SETB bit_0x4c          ; EP1 USB gönderimini tetikle!
4778: 22           RET
```

### `firmware_patched_60k.bin` İçindeki Yamalar
1. **`0x473F`:** `30 3b 12` -> **`d2 3b 00`** (`SETB bit_0x3b; NOP`) — `bit_0x3b` her zaman `1` tutulur.
2. **`0x4760`:** `30 95 0d` -> **`80 0e 00`** (`SJMP 0x4770; NOP`) — Bozuk alt LOD sensörünün (`P1.5`) `dx/dy`'yi sıfırlaması (`0x4766..0x476F`) tamamen atlanır.
3. **`0xEFFB`:** `00 00 00` -> **`02 2e 34`** (`LJMP 0x2E34`) — Bootloader uygulama atlama vektörü.

---

## 6. Sinowealth SH68F89 ISP Bootloader (`0xF000..0xFFFF`) ve İlk 6 Bayt Tuzağı

Bootloader (`VID_0603&PID_1021`) komutları (`COL01` Report `0x05`, `COL02` Report `0x06`):
- **`0x45` (`0xF4D4`):** `0x0000..0xEFFF` arasındaki sayfaları siler.
- **`0x52 <addr_lo> <addr_hi>` + `GetFeature(0x06)` (`0x72` @ `0xF093..0xF175`):**
  - Sayfanın **`0..5` baytlarını HAM (şifresiz)** gönderir (`0xF0C0..0xF160`).
  - Sayfanın **`6..2047` baytlarına `+0x5E`** ekler (`0xFD79: ADD A, #0x5E`).
- **`0x57 <addr_lo> <addr_hi>` + `SetFeature(0x06)` (`0x77` @ `0xF36B..0xF4D0`):**
  - **KRİTİK TUZAK:** Okumanın aksine, yazma rutini (`0xF380..0xF400` ve `0xFDD3`) sayfanın **`0..5` baytlarından da `0x5A` çıkarır (`ADD A, #0xA6`)!**
  - Sayfa `0x0000` yazılırken (`0xF37C`):
    - `buf[1]` ve `buf[2]`'den `0x5A` çıkarıp `0xEFFC` ve `0xEFFD` adreslerine yazar (`0xF380..0xF398`).
    - `0x0000` adresine `0x02`, `0x0001` adresine `0xF0`, `0x0002` adresine `0x00` (`LJMP 0xF000`) yazması gerekirken (`0xF520` silme sonrası), `0xF3A6` diğer sayfalarda `0..5` baytlarından `0x5A` çıkararak flash'a yazar.
  - İlk ISP yazma denemesinde `0..5` baytlarına `+0x5A` eklenmediği için `0x0000..0x0002` adresine `02 FE FE` (`LJMP 0xFEFE`) yazıldı ve `0xFEFE` adresindeki `22` (`RET`) komutu yüzünden MCU açılışta `0x0000 <-> 0xFEFE` sonsuz döngüsüne girdi.

---

## 7. Gelecek Ajan / Kullanıcı İçin Kesin Kurtarma Adımları (4-Pin ICP / JTAG)

MCU şu an `0x0000 <-> 0xFEFE` döngüsünde olduğu için USB (`258A:0027` veya `0603:1021`) başlatmamaktadır. Kurtarmak için **dışarıdan 4-pin Sinowealth ICP/JTAG** ile bağlanılmalıdır:

### Gerekli Donanım
- Herhangi bir **Arduino (Uno / Nano / Pro Micro)**, **ESP32** veya **Raspberry Pi Pico (RP2040)**.
- Açık kaynaklı araç: [`gashtaan/sinowealth-8051-dumper`](https://github.com/gashtaan/sinowealth-8051-dumper) veya [`iterentiev/sh-flasher`](https://github.com/iterentiev/sh-flasher) (SH68F89 / SH68F881 ICP protokolünü destekler).

### Adım Adım Uygulama
1. Farenin altındaki skatezlerin altındaki vidaları söküp üst kapağı açın.
2. PCB üzerindeki **SH68F89** çipinin (veya altındaki test pedlerinin) JTAG/ICP pinlerini (`VDD`, `GND`, `TCK`, `TMS`, `TDI`, `TDO`) Arduino/Pico'ya bağlayın.
3. Doğrudan tamirli 60 KB imajı (`0x0000..0xEFFF`) veya tam 64 KB orijinal dökümü (`0x0000..0xFFFF`) yazın:
   - **Tamirli İmaj (Önerilen — LOD kilidi açık, `dx/dy` çalışır):**
     `/home/hp/projects/icarus/firmware_backup/firmware_patched_60k.bin`
   - **Tam 64 KB Fabrika Yedeği:**
     `/home/hp/projects/icarus/firmware_backup/isp_dump_fixed.bin`
4. Yazma tamamlanıp USB takıldığında `0x0000` adresi `02 2E 34` (`LJMP 0x2E34`) olarak başlayacak, ışıklar yanacak, `258A:0027` olarak bağlanacak ve `0x4760` LOD kilidi kaldırıldığı için `dx/dy` imleç hareketi doğrudan çalışacaktır.
