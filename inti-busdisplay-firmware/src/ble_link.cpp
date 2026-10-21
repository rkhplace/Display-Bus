#include "ble_link.h"

#include <Arduino.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <string.h>

#include "config.h"

namespace {

BleWriteHandler gHandler = nullptr;
BLEServer* gServer = nullptr;
BLECharacteristic* gStatusChar = nullptr;
volatile bool gConnected = false;
// true setelah klien yang terhubung mengirim minimal satu paket sah.
volatile bool gAuthenticated = false;
volatile uint32_t gConnectedAtMs = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    gConnectedAtMs = millis();
    gAuthenticated = false;
    gConnected = true;
    gStatusChar->setValue("IDLE");
    Serial.println("[BLE] klien terhubung, menunggu salam");
  }

  // Tanpa ini panel tidak terlihat lagi di scan setelah aplikasi memutus koneksi.
  void onDisconnect(BLEServer*) override {
    gConnected = false;
    gAuthenticated = false;
    Serial.println("[BLE] klien terputus, advertising ulang");
    BLEDevice::startAdvertising();
  }
};

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    const std::string value = characteristic->getValue();
    const char* status = gHandler(reinterpret_cast<const uint8_t*>(value.data()), value.size());
    if (strcmp(status, "OK") == 0) gAuthenticated = true;
    gStatusChar->setValue(status);
    gStatusChar->notify();
  }
};

}  // namespace

void bleBegin(const char* deviceName, BleWriteHandler onWrite) {
  gHandler = onWrite;

  BLEDevice::init(deviceName);
  // Aplikasi meminta MTU 512 di Android supaya paket muat satu kali tulis;
  // di iOS aplikasi memakai long write.
  BLEDevice::setMTU(517);

  gServer = BLEDevice::createServer();
  gServer->setCallbacks(new ServerCallbacks());

  BLEService* service = gServer->createService(BLE_SERVICE_UUID);

  BLECharacteristic* configChar = service->createCharacteristic(
      BLE_CONFIG_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
  configChar->setCallbacks(new ConfigCallbacks());

  gStatusChar = service->createCharacteristic(
      BLE_STATUS_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  gStatusChar->addDescriptor(new BLE2902());
  gStatusChar->setValue("IDLE");

  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);  // nama device dikirim di scan response
  BLEDevice::startAdvertising();

  Serial.printf("[BLE] advertising sebagai \"%s\"\n", deviceName);
}

void bleTick() {
  if (!gConnected || gAuthenticated) return;
  if (millis() - gConnectedAtMs < HELLO_TIMEOUT_MS) return;

  Serial.println("[BLE] klien tidak mengirim paket sah, koneksi diputus");
  gConnectedAtMs = millis();  // cegah pemutusan berulang sebelum onDisconnect tiba
  gServer->disconnect(gServer->getConnId());
}

bool bleIsConnected() { return gConnected; }
