# EEE.md — Elektronik Donanım (Arduino / ESP32 / RP2040) ile SH68F89 ICP/JTAG Uyandırma ve Kurtarma Kılavuzu

> **Amaç:** Gamepower Icarus (`258A:0027`) faresinin içindeki **Sinowealth SH68F89** 8051 mikrodenetleyicisini, USB üzerinden erişilemediği (`0x0000 <-> 0xFEFE` reset döngüsü) durumlarda dışarıdan **Arduino (Uno/Nano/Pro Micro), ESP32 veya Raspberry Pi Pico (RP2040)** kullanarak **4 kablo (In-Circuit Programming — ICP)** ile yeniden programlamak, fareyi uyandırmak ve alt LOD sensörü hatasını kalıcı olarak çözmek.

---

## 1. Devreyi ve Problemi Okuma (Neden Dışarıdan Müdahale Gerekiyor?)

1. **Çipin Normal Açılışı:** SH68F89 çipine USB'den $+5\text{ V}$ ($V_{DD}$ / Regüle $3.3\text{ V}$) geldiğinde, donanımsal Program Sayacı ($\text{PC}$) `0x0000` adresinden başlar. Normalde burada `02 2E 34` (`LJMP 0x2E34`) komutu vardır; çip ana programa atlar, RGB LED'leri yakar ve USB D+/D- hatlarını aktif eder.
2. **Mevcut Durum:** İlk ISP yazma sırasında bootloader'ın ilk 6 bayttan `0x5A` çıkarması nedeniyle `0x0000` adresinde `02 FE FE` (`LJMP 0xFEFE`) yazılıdır. `0xFEFE` adresinde `22` (`RET`) komutu bulunduğu için işlemci her mikrosaniyede `0x0000 <-> 0xFEFE` arasında döner ve USB donanımını başlatan satıra hiç ulaşamaz.
3. **Çözüm İlkesi (Donanımsal ICP Modu):**
   - Sinowealth 8051 çiplerinde (SH68F881, SH68F89, SH68F90), çipe enerji verildikten (**Power-On Reset**) hemen sonraki **ilk birkaç milisaniye içinde** programlama pinlerinden (`TCK`, `TMS`, `TDI`, `TDO`) özel bir darbe dizisi gönderilirse, çip **CPU çekirdeğini durdurur (`0x0000` adresindeki bozuk koda hiç bakmaz!)** ve doğrudan donanımsal Flash denetleyicisini dışarıya açar.
   - Bu moda **ICP (In-Circuit Programming) / JTAG** modu denir.

---

## 2. Gerekli Malzemeler ve Voltaj Uyumu (Kritik Elektrik Kuralı!)

### A. Kullanılabilecek Kartlar (Herhangi Biri Yeterli)
1. **Raspberry Pi Pico (RP2040) veya ESP32:** Doğrudan **$3.3\text{ V}$ lojik** seviyesinde çalıştığı için direnç bile gerektirmeden en güvenli seçenektir.
2. **Arduino Uno / Nano / Pro Micro (ATmega328P / ATmega32U4):** $5\text{ V}$ lojik seviyesinde çalışır. SH68F89'un IO pinleri $3.3\text{ V}$ (dahili regülatör çıkışı $V_{DD}$) seviyesindedir; bu yüzden Arduino kullanırken sinyal hatlarına ($TCK, TMS, TDI$) **$1\text{ k}\Omega$ seri akım sınırlama direnci** (veya basit $1\text{ k}\Omega / 2.2\text{ k}\Omega$ gerilim bölücü) takılması önerilir.

### B. Gerekli Yardımcı Malzemeler
- Yıldız tornavida (farenin altındaki skatezlerin altındaki vidalar için).
- 5–6 adet Jumper kablo (Erkek-Erkek veya Dişi-Erkek).
- İsteğe bağlı: Lehim yapmadan temas etmek için ölçü aleti probu veya toplu iğne uçları (işlem sadece 3–5 saniye sürdüğü için elle bastırarak tutmak bile yeterlidir).

---

## 3. Farenin İçindeki PCB ve SH68F89 Pin Haritası

Farenin altındaki skatezleri (kaygan pedleri) hafifçe kaldırıp vidaları söktüğünde ana devre kartı (PCB) görünecektir.

### A. PCB Altındaki Hazır Test Pedleri (Test Points)
Sinowealth fare kartlarının neredeyse tamamında, fabrikada yazılım yüklemek için kartın altında (veya çipin hemen yanında) yan yana dizilmiş **5 veya 6 adet yuvarlak bakır test noktası (TP)** bulunur. Genellikle yanlarında küçük harflerle yazar:
- **`V` / `VDD` / `3V3` / `5V`** (Besleme)
- **`G` / `GND`** (Toprak — USB metal gövdesiyle kısa devredir, multimetre ile kolayca bulunur)
- **`C` / `TCK` / `CLK`** (Saat پini)
- **`M` / `TMS`** (Mod Seçim pini)
- **`I` / `TDI`** (Veri Giriş pini)
- **`O` / `TDO`** (Veri Çıkış pini)

### B. Doğrudan SH68F89 Çip Bacakları (QFN-32 / LQFP-32)
Eğer kart üzerinde yazı yoksa, doğrudan **SH68F89** (veya BY8832/Sinowealth etiketli) 32 bacaklı çipin JTAG/ICP bacakları şunlardır:

| Sinyal Adı | Açıklama | Arduino Uno/Nano Pini | RP2040 / ESP32 Pini |
| :--- | :--- | :--- | :--- |
| **`GND`** | Ortak Toprak | `GND` | `GND` |
| **`VDD` ($3.3\text{ V}$ / $5\text{ V}$)** | Çip Güç Girişi (ICP girişi için Arduino tarafından açılıp kapatılmalı) | `D8` (veya $3.3\text{ V}$ + manuel tak-çıkar) | `GP8` / $3.3\text{ V}$ |
| **`TCK`** | JTAG/ICP Saat Girişi | `D2` ($1\text{ k}\Omega$ seri dirençle) | `GP2` |
| **`TMS`** | JTAG/ICP Mod Seçimi | `D3` ($1\text{ k}\Omega$ seri dirençle) | `GP3` |
| **`TDI`** | JTAG/ICP Veri Girişi (MCU'ya giden) | `D4` ($1\text{ k}\Omega$ seri dirençle) | `GP4` |
| **`TDO`** | JTAG/ICP Veri Çıkışı (MCU'dan gelen) | `D5` (Doğrudan) | `GP5` |

> [!CAUTION]
> **Güç Sıralaması (Power-Cycle Timing):**
> SH68F89 çipi sadece **enerji ilk verildiğinde (Power-On Reset anında)** ICP/JTAG moduna girer! Bu yüzden çipe USB kablosu **takılı olmamalıdır**; çipin beslemesi (`VDD`) Arduino/Pico üzerinden verilmeli (ya da Arduino komutu başlattığı anda `VDD` kablosu değdirilmelidir).

---

## 4. Adım Adım Uygulama (Yöntem 1: `sinowealth-8051-dumper` / Arduino ile)

Açık kaynaklı **[`gashtaan/sinowealth-8051-dumper`](https://github.com/gashtaan/sinowealth-8051-dumper)** veya **[`iterentiev/sh-flasher`](https://github.com/iterentiev/sh-flasher)** projesi SH68F89 çipini doğrudan destekler.

### Adım 1: Arduino'ya ICP Köprü Yazılımını Yükleme
1. Bilgisayara Arduino IDE veya `arduino-cli` kurun.
2. `sinowealth-8051-dumper` deposundaki Arduino sketch dosyasını Arduino Uno/Nano'ya yükleyin.
3. Bu yazılım Arduino'yu bilgisayar ile SH68F89 arasında bir **USB-ICP/JTAG adaptörüne** dönüştürür.

### Adım 2: Kabloları Bağlama
```text
[ Arduino / Pico ]                       [ Fare PCB (SH68F89) ]
      GND          ────────────────────>        GND
      D8 (Power)   ────────────────────>        VDD (3.3V)
      D2 (TCK)     ────[ 1 kΩ ]────────>        TCK
      D3 (TMS)     ────[ 1 kΩ ]────────>        TMS
      D4 (TDI)     ────[ 1 kΩ ]────────>        TDI
      D5 (TDO)     ────────────────────>        TDO
```

### Adım 3: Çip Kimliğini (JTAG ID) Doğrulama
Bilgisayardan kontrol scriptini çalıştırıp SH68F89 ile bağlantıyı doğrulayın:
- Eğer pinler doğru temas ettiyse çip kendi donanım kimliğini döner ve Flash belleği okumaya/yazmaya hazır hale gelir.

### Adım 4: Tamirli Yazılımı (`firmware_patched_60k.bin`) Yazma
Depomuzda hazır bulunan ve hem `0x0000` başlangıç vektörü (`02 2E 34`) düzgün olan hem de bozuk alt LOD sensörü kilidi (`0x4760`) kaldırılmış olan dosyayı yazdırın:
- **Yazılacak Dosya (Önerilen — İmleç `dx/dy` Sorunu Çözülmüş Halde):**
  [`/home/hp/projects/icarus/firmware_backup/firmware_patched_60k.bin`](file:///home/hp/projects/icarus/firmware_backup/firmware_patched_60k.bin) (`0x0000..0xEFFF`, 61,440 bayt)
- **Alternatif (Tam 64 KB Fabrika Orijinal Yedeği — Bootloader Dahil):**
  [`/home/hp/projects/icarus/firmware_backup/isp_dump_fixed.bin`](file:///home/hp/projects/icarus/firmware_backup/isp_dump_fixed.bin) (`0x0000..0xFFFF`, 65,536 bayt)

---

## 5. Adım Adım Uygulama (Yöntem 2: Tek Başına ESP32 / Pico ile Sadece İlk Sayfayı Kurtarma)

Tüm 60 KB yazılımı baştan yazmak zorunda bile değilsiniz! Çünkü şu an farenin hafızasında:
- `0x0800..0xEFFF` arasındaki tüm sayfalar (ve `0x473F` / `0x4760` imleç düzeltme yamaları) **zaten %100 doğru yazılıdır!**
- Sadece **Sayfa 0 (`0x0000..0x07FF`)** içindeki ilk 6 bayt (`02 2E 34 30 33 04`) kaymıştır.

Dolayısıyla ICP üzerinden:
1. Sadece `0x0000` sayfasını silip (`Erase Sector 0x0000`) `firmware_patched_60k.bin` dosyasının ilk 2048 baytını yazmak **veya**
2. Sadece `0x0000` sayfasını silmek bile (silinen flash `0xFF` olur; `FF` = `MOV R7, A` NOP benzeri tek baytlık komuttur, işlemci `0x0000`'dan başlayıp `0xFF` boyunca kayarak `0xF000`'daki **ISP Bootloader**'a ulaşır ve fare anında USB'de `VID_0603&PID_1021` olarak görünür!) fareyi USB üzerinden kurtarmaya yeter!

> [!TIP]
> **80/20 Mühendislik Kısayolu ("Sadece Sayfa 0 Silme Tekniği"):**
> Eğer ICP üzerinden tam dosya yazmakla uğraşmak istemiyorsanız, ICP ile **yalnızca `0x0000` sektörüne silme (Sector Erase) komutu** gönderin.
> `0x0000..0x03FF` arası `0xFF` (`MOV R7, A`) olduğunda, işlemci `0xFEFE`'ye zıplamak yerine aşağı doğru kayıp `0xF000`'daki USB Bootloader'ı çalıştırır. Fareyi USB'ye taktığınız anda `VID_0603&PID_1021` olarak bağlanır ve hazır bekleyen [`isp_rescue_watch.ps1`](file:///home/hp/projects/icarus/firmware_backup/scripts/isp_rescue_watch.ps1) scripti USB üzerinden 2 saniyede tamirli yazılımı yükler!

---

## 6. Alternatif Saf Elektronik Çözüm: Alt LOD Sensörü Pini (`P1.5`) Donanımsal Bypass

Eğer fareye tamirli yazılım (`firmware_patched_60k.bin`) yerine orijinal fabrika yazılımı (`isp_dump_fixed.bin`) yüklenirse, imlecin (`dx/dy`) çalışması için **alt LOD sensörünün `P1.5` bacağını** elektronik olarak susturmak da mümkündür:

1. Firmware analizinde (`0x4760: 30 95 0d` -> `JNB P1.5, 0x4770`) görüldüğü üzere:
   - **$P1.5 = 0\text{ V}$ (Lojik `0`):** Fare yüzeyde $\rightarrow$ `dx/dy` imleç hareketine **izin verilir**.
   - **$P1.5 = 3.3\text{ V}$ (Lojik `1`):** Fare havada $\rightarrow$ `dx/dy` imleç hareketi **sıfırlanır**.
2. Alt LOD yakınlık sensörü bozulup `P1.5` hattını sürekli Lojik `1` ($3.3\text{ V}$) seviyesinde tuttuğu için imleç hareket etmemektedir.
3. **Donanımsal Müdahale:** SH68F89'un `P1.5` bacağı (veya alt LOD sensörünün çıkış pini) bir **$1\text{ k}\Omega$ direnç üzerinden `GND`'ye (Toprağa) çekilirse (Pull-Down)**, `P1.5` her zaman Lojik `0` okunur ve orijinal fabrika yazılımında bile `0x4760` kilidi açılarak imleç kusursuz çalışır. *(Ancak `firmware_patched_60k.bin` yüklendiğinde bu yazılımsal olarak zaten yapıldığı için hiçbir direnç/lehim işlemine gerek kalmaz).*

---

### SONUÇ

$$\boxed{\text{Kurtarma Yöntemi: 4-Pin Sinowealth ICP/JTAG (TCK, TMS, TDI, TDO + GND/VDD)}}$$
$$\boxed{\text{Yazılacak Dosya: firmware\_backup/firmware\_patched\_60k.bin (61,440 B)}}$$
$$\boxed{\text{Hedef Başlangıç Vektörü: 0x0000} = \text{02 2E 34 (LJMP 0x2E34)}}$$
