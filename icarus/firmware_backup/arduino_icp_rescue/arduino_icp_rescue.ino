/*
 * Gamepower Icarus (Sinowealth SH68F89) ICP Kurtarma Aracı v3 (Canlı Yakalama)
 */

#include <avr/io.h>
#include <util/delay.h>

#define clrBit(b) (PORTD &= ~_BV(b))
#define setBit(b) (PORTD |= _BV(b))
#define getBit(b) (PIND & _BV(b))

uint8_t pinTDO = 2; // D2
uint8_t pinTMS = 3; // D3
uint8_t pinTDI = 4; // D4
uint8_t pinTCK = 5; // D5

enum ICPCommand : uint8_t {
  ICP_SET_IB_OFFSET_L = 0x40,
  ICP_SET_IB_OFFSET_H = 0x41,
  ICP_SET_IB_DATA     = 0x42,
  ICP_GET_IB_OFFSET   = 0x43,
  ICP_READ_FLASH      = 0x44,
  ICP_PING            = 0x49,
};

const uint8_t fixed_header[16] = {
  0x02, 0x2E, 0x34, 0x30, 0x33, 0x04, 0x8F, 0x34,
  0xD2, 0x4C, 0x22, 0x02, 0x2A, 0xEE, 0xE4, 0xF5
};

void pulseClock() {
  _delay_us(1);
  setBit(pinTCK);
  _delay_us(1);
  clrBit(pinTCK);
}

void sendData(uint8_t value) {
  for (uint8_t m = 0x80; m; m >>= 1) {
    if (value & m) setBit(pinTDI);
    else clrBit(pinTDI);
    pulseClock();
  }
  pulseClock();
  clrBit(pinTDI);
}

uint8_t receiveData() {
  uint8_t value = 0;
  for (uint8_t m = 1; m; m <<= 1) {
    pulseClock();
    if (getBit(pinTDO)) value |= m;
  }
  pulseClock();
  return value;
}

void startMode() {
  clrBit(pinTCK);
  _delay_us(2);
  for (uint8_t m = 0x80; m; m >>= 1) {
    if (150 & m) setBit(pinTDI);
    else clrBit(pinTDI);
    setBit(pinTCK); _delay_us(2);
    clrBit(pinTCK); _delay_us(2);
  }
  setBit(pinTCK); _delay_us(2); clrBit(pinTCK); _delay_us(2);
  setBit(pinTCK); _delay_us(2); clrBit(pinTCK); _delay_us(2);
}

void resetICP() {
  setBit(pinTCK);
  setBit(pinTMS);
  _delay_us(2);
  clrBit(pinTMS);
  _delay_us(2);
}

void ping() {
  sendData(ICP_PING);
  sendData(0xFF);
}

void connectICP() {
  setBit(pinTCK);
  setBit(pinTDI);
  setBit(pinTMS);
  _delay_us(500);

  clrBit(pinTCK); _delay_us(1);
  setBit(pinTCK); _delay_us(50);

  for (uint8_t n = 0; n < 165; ++n) {
    clrBit(pinTMS); _delay_us(2); setBit(pinTMS); _delay_us(2);
  }
  for (uint8_t n = 0; n < 105; ++n) {
    clrBit(pinTDI); _delay_us(2); setBit(pinTDI); _delay_us(2);
  }
  for (uint8_t n = 0; n < 90; ++n) {
    clrBit(pinTCK); _delay_us(2); setBit(pinTCK); _delay_us(2);
  }
  for (uint16_t n = 0; n < 25600; ++n) {
    clrBit(pinTMS); _delay_us(2); setBit(pinTMS); _delay_us(2);
  }
  _delay_us(8);
  clrBit(pinTMS);

  startMode();

  for (uint16_t n = 0; n < 25600; ++n) {
    setBit(pinTCK); _delay_us(2); clrBit(pinTCK); _delay_us(2);
  }
  resetICP();

  _delay_us(800);
  ping();
}

uint8_t checkICP_raw() {
  sendData(ICP_SET_IB_OFFSET_L); sendData(0x69);
  sendData(ICP_SET_IB_OFFSET_H); sendData(0xFF);
  sendData(ICP_GET_IB_OFFSET);
  uint8_t b = receiveData();
  (void)receiveData();
  return b;
}

bool readFlash(uint32_t address, uint8_t* buffer, uint8_t bufferSize) {
  sendData(0x46); sendData(0xFE); sendData(0xFF);
  sendData(ICP_SET_IB_OFFSET_L); sendData(address & 0xFF);
  sendData(ICP_SET_IB_OFFSET_H); sendData((address >> 8) & 0xFF);
  sendData(ICP_READ_FLASH);
  for (uint8_t n = 0; n < bufferSize; ++n) buffer[n] = receiveData();
  resetICP();
  return true;
}

bool eraseFlash(uint32_t address) {
  sendData(0x46); sendData(0xF0); sendData(0xFF);
  sendData(ICP_SET_IB_OFFSET_L); sendData(address & 0xFF);
  sendData(ICP_SET_IB_OFFSET_H); sendData((address >> 8) & 0xFF);
  sendData(ICP_SET_IB_DATA); sendData(0x00);
  sendData(0xE6); sendData(0x15); sendData(0x0A); sendData(0x09); sendData(0x06);
  sendData(0x00);
  _delay_ms(300);
  sendData(0x00);
  bool status = getBit(pinTDO);
  sendData(0x00);
  return status;
}

bool writeFlash(uint32_t address, const uint8_t* buffer, uint16_t bufferSize) {
  if (bufferSize == 0) return false;
  sendData(0x46); sendData(0xF0); sendData(0xFF);
  sendData(ICP_SET_IB_OFFSET_L); sendData(address & 0xFF);
  sendData(ICP_SET_IB_OFFSET_H); sendData((address >> 8) & 0xFF);
  sendData(ICP_SET_IB_DATA); sendData(buffer[0]);
  sendData(0x6E); sendData(0x15); sendData(0x0A); sendData(0x09); sendData(0x06);
  for (uint16_t n = 1; n < bufferSize; ++n) {
    sendData(buffer[n]); _delay_us(5); sendData(0x00);
  }
  sendData(0x00); sendData(0xAA); sendData(0x00); sendData(0x00);
  _delay_us(5);
  return true;
}

void printHex(uint8_t val) {
  if (val < 16) Serial.print("0");
  Serial.print(val, HEX); Serial.print(" ");
}

void readAndDisplayHeader() {
  uint8_t buf[16] = {0};
  readFlash(0x0000, buf, 16);
  Serial.print(F("Adres 0x0000..0x000F: "));
  for (uint8_t i = 0; i < 16; ++i) printHex(buf[i]);
  Serial.println();
}

void printMenu() {
  Serial.println(F("\r\n--- ISLEM SECIN (Serial Monitor'e yazin) ---"));
  Serial.println(F(" [1] Sadece Sektor 0'i SIL (USB Bootloader'i acar: VID_0603 PID_1021)"));
  Serial.println(F(" [2] Sektor 0'i SIL ve Tamirli Vektoru YAZ (LJMP 0x2E34 -> Fare dogrudan canlanir!)"));
  Serial.println(F(" [3] 0x0000 Adresini Tekrar OKU"));
  Serial.println(F("-------------------------------------------"));
}

bool isConnected = false;
unsigned long lastHeartbeat = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial);

  Serial.println(F("\r\n========================================"));
  Serial.println(F(" Gamepower Icarus - Canli ICP Yakalama "));
  Serial.println(F("========================================"));

  DDRD &= ~_BV(pinTDO);
  DDRD |= _BV(pinTMS) | _BV(pinTDI) | _BV(pinTCK);

  clrBit(pinTCK);
  clrBit(pinTDI);
  clrBit(pinTMS);

  Serial.println(F("\r\n>>> ACELE YOK! ARDUINO SONSUZA KADAR SENI BEKLIYOR. <<<"));
  Serial.println(F("Adim 1: 3.3V kablosunu simdi Arduino'dan cikar."));
  Serial.println(F("Adim 2: 2 saniye bekle, sonra rahatca 3.3V pinine geri tak."));
  Serial.println(F("Arduino arkada nobet tutuyor, taktigin milisaniyede yakalayacak.\r\n"));
}

void loop() {
  if (!isConnected) {
    // Saniyede bir ekrana yasadigini gostersin
    if (millis() - lastHeartbeat > 1000) {
      lastHeartbeat = millis();
      Serial.print(F("."));
    }

    // Surekli baglanmayi dene
    connectICP();
    uint8_t resp = checkICP_raw();

    if (resp == 0x69) {
      isConnected = true;
      Serial.println(F("\r\n\r\n*********************************************"));
      Serial.println(F(">>> CIPI YAKALADIK! ICP BAGLANTISI BASARILI! <<<"));
      Serial.println(F("*********************************************"));
      readAndDisplayHeader();
      printMenu();
    } else {
      // Diger pin siralamasini da dene
      uint8_t temp = pinTMS; pinTMS = pinTDI; pinTDI = temp;
      connectICP();
      resp = checkICP_raw();
      if (resp == 0x69) {
        isConnected = true;
        Serial.println(F("\r\n\r\n*********************************************"));
        Serial.println(F(">>> CIPI YAKALADIK! (Alternatif Sira) <<<"));
        Serial.println(F("*********************************************"));
        readAndDisplayHeader();
        printMenu();
      } else {
        temp = pinTMS; pinTMS = pinTDI; pinTDI = temp;
      }
      delay(20);
    }
  } else {
    // Baglanti kurulduktan sonra komut bekle
    if (Serial.available()) {
      char cmd = Serial.read();
      if (cmd == '1') {
        Serial.println(F("\r\n[ISLEM] Sektor 0 siliniyor..."));
        if (eraseFlash(0x0000)) {
          Serial.println(F("[BASARILI] Sektor 0 silindi!"));
          readAndDisplayHeader();
        }
        printMenu();
      } else if (cmd == '2') {
        Serial.println(F("\r\n[ISLEM] Sektor 0 siliniyor ve LJMP 0x2E34 yaziliyor..."));
        eraseFlash(0x0000);
        delay(50);
        if (writeFlash(0x0000, fixed_header, 16)) {
          Serial.println(F("[BASARILI] Baslangic vektoru yazildi!"));
          readAndDisplayHeader();
          Serial.println(F("TEBRIKLER! Fare canlandi. Arduino kablolarini sokebilirsin."));
        }
        printMenu();
      } else if (cmd == '3') {
        readAndDisplayHeader();
        printMenu();
      }
    }
  }
}
