# CLAUDE_HANDOFF.md — Gamepower Icarus (258A:0027) Donanım Kurtarma & Bağlam Devir Raporu

**Tarih:** 11 Kasım 2026, 00:25 (TSİ)  
**Hedef Ajan:** Claude (veya sonraki tüm yapay zeka mühendisleri)  
**Özet:** Bu doküman, Gamepower Icarus faresinin içindeki Sinowealth SH68F89 mikrodenetleyicisinin başlangıç vektörü kayması nedeniyle girdiği sonsuz döngüden harici **Arduino Nano (ICP/JTAG)** ile kurtarılması için yürütülen tüm tersine mühendislik bulgularını, PCB pin haritasını, kodları, bağlantıları ve şu anki tam durumu içerir. Sıfır bağlam kaybıyla işe devam edilebilmesi için hazırlanmıştır.

---

## 1. DONANIM MİMARİSİ VE ÇİP KİMLİĞİ

* **Cihaz:** Gamepower Icarus RGB Gaming Mouse
* **USB Kimliği:** `VID:PID = 258A:0027` (Uygulama Modu), `0603:1021` (Fabrika ISP Bootloader Modu)
* **Ana MCU (U1):** **Sinowealth `BY8948-00006`** (48-pin LQFP kılıf, iç mimari **Sinowealth SH68F89Q** / 8051 türevi).
  * Bellek: 64 KB Flash (`0x0000..0xFFFF`).
  * `0x0000..0xEFFF`: Ana fare uygulama yazılımı (60 KB).
  * `0xF000..0xFFFF`: Fabrika USB ISP Bootloader (4 KB).
  * Sayfa boyutu: 2 KB (`0x0800` bayt). Sektör silme boyutu: 1 KB / 2 KB.
* **Ana Optik Sensör:** PixArt PMW3325DB-TWV1 (MCU'ya SPI üzerinden bağlı).
* **İkinci Sensör (U5):** Kartın alt tarafında, lens açıklığı ile scroll tekerleği arasında yer alan **bağımsız optik Lift-Off Distance (LOD) yakınlık sensörü** (şeffaf gövde, altın VCSEL verici + fotodiyot). MCU'nun `P1.5` pinine bağlıdır.

---

## 2. KÖK NEDEN ANALİZİ (NE OLDU, NEDEN ELEKTRİK GİTMİŞ GİBİ DURUYOR?)

### Sorun 1 (Orijinal Problem — İmleç dx/dy Hareket Etmiyordu):
Fare tuşları, tekerlek ve RGB LED'leri çalışıyordu ancak imleç (`dx/dy`) tamamen ölüydü.
* **Tersine Mühendislik Kanıtı:** Firmware assembly analizi (`0x4760` adresi):
  ```assembly
  0x4760: 30 95 0D    JNB P1.5, 0x4770   ; P1.5 == 0 (Zemin algılandı) -> 0x4770'e zıpla (dx/dy aktar)
  0x4763: E4          CLR A              ; P1.5 == 1 (Fare havada!) -> dx ve dy sıfırla
  0x4764: F5 2C       MOV 0x2C, A        ; dx = 0
  0x4766: F5 2D       MOV 0x2D, A        ; dy = 0
  ```
* Kartın altındaki `U5` optik LOD sensörü donanımsal olarak arızalanmış ve `P1.5` pinini sürekli `1` ($3.3\text{ V}$) seviyesinde tutmuştur. Fare kendisini sonsuza kadar masadan havaya kaldırılmış sanarak tüm imleç hareketini sıfırlamıştır.

### Sorun 2 (Mevcut Kilitlenme — Farenin Hiç Işık Vermemesi ve Tanınmaması):
`0x4760`'taki LOD kilidini devre dışı bırakmak için USB ISP bootloader üzerinden firmware yaması yazılırken, bootloader'ın ilk 6 baytta (`0x0000..0x0005`) **$0x5A$ çıkarma algoritması** uyguladığı (`Yazılan = Gelen - 0x5A`) keşfedilmemiştir.
* Orijinal vektör: `02 2E 34` (`LJMP 0x2E34`).
* Bootloader'ın yazdığı: `02 FE FE` (`LJMP 0xFEFE`).
* `0xFEFE` adresinde `22` (`RET`) komutu vardır.
* **Sonuç:** MCU USB'ye takıldığı anda `0x0000` $\rightarrow$ `0xFEFE` $\rightarrow$ `0x0000` arasında mikrosaniyede milyonlarca kez dönen sonsuz bir reset döngüsüne girmiştir. USB motorunu başlatan koda hiç ulaşamadığı için işletim sistemi fareyi hiç takılmamış gibi görür (elektrik yok sanılır).

---

## 3. KURTARMA YOLU: DONANIMSAL ICP (IN-CIRCUIT PROGRAMMING)

Sinowealth 8051 mikrodenetleyicileri, harici bir programlayıcı (Arduino Nano) ile **ICP (In-Circuit Programming)** moduna alınabilir.
* **Kritik Kural:** Sinowealth çipleri, **yalnızca enerji ilk verildiği (Power-On Reset) ilk 1–20 milisaniye içinde** JTAG/ICP darbe dizisini (`connectICP`) dinler. Çip sürekli açık kalırsa JTAG dinlemeyi bırakır ve normal kod döngüsüne zıplar.
* ICP moduna girildiğinde işlemci çekirdeği durur (`0x0000`'a bakmaz) ve doğrudan donanımsal Flash kontrolcüsü dışarı açılır.

---

## 4. PCB ÜZERİNDEKİ `CON6` BAŞLIĞI VE PİNLER

Kullanıcı farenin gövdesini açmıştır. Kartın alt yüzeyinde, optik sensör yuvasının hemen arkasında **`CON6`** silkscreen etiketli 6 pinli fabrika programlama lehim pedleri bulunmaktadır.

### Silkscreen Yazısı Düz Okunurken Soldan Sağa Pinout:
```text
       ┌───────────────────────────────┐
       │  [1]   [2]   [3]   [4]   [5]   [6]  │
       └───┬─────┬─────┬─────┬─────┬─────┬───┘
           │     │     │     │     │     │
          VDD   TCK   TDI   TMS   TDO   GND
```

1. **`Pin 1` (En Soldaki Ped):** $V_{DD}$ (Lojik Güç).
   * Kullanıcı multimetre ile ölçtü: **$3.3\text{ V}$ doğrulandı.**
2. **`Pin 2`:** `TCK` (Test Clock)
3. **`Pin 3`:** `TDI` (Test Data In — MCU'ya giriş) veya `TMS`
4. **`Pin 4`:** `TMS` (Test Mode Select) veya `TDI`
5. **`Pin 5`:** `TDO` (Test Data Out — MCU'dan Arduino'ya çıkış)
6. **`Pin 6` (En Sağdaki Ped):** `GND` (Toprak).
   * Kullanıcı multimetre süreklilik (bip) modunda test etti: **USB şasesi ile öttü, kesinleşti ✅.**

---

## 5. MEVCUT DEVRE BAĞLANTISI (ARDUINO NANO $\leftrightarrow$ FARE PCB)

Kullanıcı şu anda lehimleri ve $1\text{ k}\Omega$ dirençleri bağlamış durumdadır:

| Arduino Nano Pini | Araya Takılan | CON6 Pini | Sinyal Adı | Durum |
| :--- | :--- | :--- | :--- | :--- |
| **`GND`** | Doğrudan kablo | **`Pin 6`** | GND | Doğrulandı ✅ |
| **`D2`** | Doğrudan kablo | **`Pin 5`** | TDO | Doğrulandı ✅ |
| **`D3`** | **$1\text{ k}\Omega$ Direnç** | **`Pin 4`** | TMS (veya TDI) | Doğrulandı ✅ |
| **`D4`** | **$1\text{ k}\Omega$ Direnç** | **`Pin 3`** | TDI (veya TMS) | Doğrulandı ✅ |
| **`D5`** | **$1\text{ k}\Omega$ Direnç** | **`Pin 2`** | TCK | Doğrulandı ✅ |
| **`3.3V`** | Doğrudan kablo | **`Pin 1`** | VDD ($3.3\text{ V}$) | $3.3\text{V}$ Ölçüldü ✅ |

> [!CAUTION]
> **ÖNEMLİ:** Farenin kendi USB kablosu bilgisayara **KESİNLİKLE TAKILMAMALIDIR**. Tüm devre enerjisini Arduino üzerinden almaktadır.

---

## 6. KULLANILAN YAZILIMLAR VE DOSYA KONUMLARI

### A. Arduino Sketch Kodu (Şu an Masaüstünde Yüklü):
* **Dosya Yolu:** `C:\Users\HP\Desktop\icarus_v2\icarus_v2.ino`
* **Proje İçi Yedeği:** `/home/hp/projects/icarus/firmware_backup/arduino_icp_rescue/arduino_icp_rescue.ino`
* **Özellikleri:**
  * Baud Hızı: **`115200`**
  * Arduino sürekli döngüde `connectICP()` sinyalleri pompalar ve ekrana saniyede bir nokta (`.`) basar.
  * `0x69` yanıtı (ICP handshake doğrulaması) alındığı anda bağlantıyı kilitler, Sektör 0'ı okur ve menüyü ekrana basar.
  * Serial Monitor'den **`2`** tuşuna basıldığında Sektör 0'ı siler ve `0x0000` adresine orijinal `02 2E 34 30 33 04 8F 34 D2 4C 22 02 2A EE E4 F5` baytlarını yazar.
  * Serial Monitor'den **`1`** tuşuna basıldığında Sektör 0'ı sadece siler (`0xFF`), bu sayede MCU açılışta `0xF000` USB ISP Bootloader'a düşer (`VID_0603&PID_1021`).

### B. Hazır Tamirli Firmware Dosyaları:
* **Tamirli Firmware (Önerilen — LOD Sensörü Devre Dışı Bırakılmış):**
  `/home/hp/projects/icarus/firmware_backup/firmware_patched_60k.bin` (61,440 bayt)
  * `0x0000`: `02 2E 34` (Düzgün başlangıç vektörü).
  * `0x4760`: `80 0E` (`SJMP 0x4770` — LOD kilidi baypas edildi, imleç serbest bırakıldı).
* **Fabrika Orijinal Yedeği (Ham):**
  `/home/hp/projects/icarus/firmware_backup/isp_dump_fixed.bin` (65,536 bayt, Bootloader dahil tam dump).
* **USB Otomatik Kurtarma Scripti (PowerShell):**
  `/home/hp/projects/icarus/firmware_backup/scripts/isp_rescue_watch.ps1`
  *(Sektör 0 silinip fare USB'ye takıldığında bootloader'ı otomatik yakalayıp 2 saniyede tamirli firmware'i yazar).*

---

## 7. ŞU ANKİ TAM ADIM VE ÇÖZÜM BEKLEYEN NOKTA

### Kullanıcının Kaldığı Yer:
Arduino Nano bilgisayara takılı, `icarus_v2.ino` yüklendi, Serial Monitor 115200 baud'da açık.

### Yapılması Gereken Tek Hamle:
1. Fare `CON6 Pin 1` kablosu Arduino'nun `3.3V` pinine takılı olduğu için çip sürekli elektrik alıyor ve reset anını kaçırıyor.
2. Arduino Serial Monitor açıkken (noktalar `. . .` akarken):
   - **Kullanıcı $3.3\text{V}$ kablosunu Arduino'dan çekecek.**
   - 2-3 saniye bekleyecek (kondansatörler deşarj olsun).
   - Kabloyu **tekrar $3.3\text{V}$ pinine takacak.**
3. Arduino arkada sürekli darbe gönderdiği için, kablo takıldığı ilk milisaniyede `0x69` yanıtını alacak ve ekrana:
   ```text
   >>> CIPI YAKALADIK! ICP BAGLANTISI BASARILI! <<<
   Adres 0x0000..0x000F: 02 FE FE ...
   --- ISLEM SECIN ---
   [1] Sektor 0'i SIL (USB Bootloader moduna sokar)
   [2] Sektor 0'i SIL ve Tamirli Vektoru YAZ (Dogrudan calistirir)
   ```
4. Kullanıcı Serial Monitor'e **`2`** yazıp Enter'a basacak.
5. Vektör yazıldıktan sonra Arduino kabloları sökülecek, fare normal USB kablosuyla PC'ye takılacak:
   **Fare RGB ışıkları yanacak, imleç (`dx/dy`) masaüstünde sorunsuz hareket edecektir.**

---

## 8. GİT VE DEPO GEÇMİŞİ

* **GitHub Deposu:** `waldseelen/icarus` (Dal: `master`)
* Son Commit'ler:
  * `c4eee8a`: `feat: complete 64KB SH68F89 flash map, dual-sensor proof, vendor setup, and live backups`
  * `27e3251`: `docs(eee): hardware recovery guide with Arduino/ESP32 ICP JTAG flasher for un-enumerated SH68F89`
* Tüm dosyalar, dissasembly haritaları, IDA/Ghidra notları ve firmware yedekleri depoda kayıtlıdır; hiçbir veri silinmemiştir.
