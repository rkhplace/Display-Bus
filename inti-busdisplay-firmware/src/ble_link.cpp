#include "ble_link.h"

#include <Arduino.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>

#include "config.h"

namespace {

BleWriteHandler gHandler = nullptr;
BLECharacteristic* gStatusChar = nullptr;
volatile bool gConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    gConnected = true;
    Serial.println("[BLE] aplikasi terhubung");
  }

  // Tanpa ini panel tidak terlihat lagi di scan setelah aplikasi memutus koneksi.
  void onDisconnect(BLEServer*) override {
    gConnected = false;
    Serial.println("[BLE] aplikasi terputus, advertising ulang");
    BLEDevice::startAdvertising();
  }
};

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    const std::string value = characteristic->getValue();
    const char* status = gHandler(reinterpret_cast<const uint8_t*>(value.data()), value.size());
    gStatusChar->setValue(status);
    gStatusChar->notify();
  }
};

}  // namespace

void bleBegin(BleWriteHandler onWrite) {
  gHandler = onWrite;

  BLEDevice::init(BLE_DEVICE_NAME);
  // Aplikasi meminta MTU 512 di Android supaya paket (~180 byte) muat satu kali tulis.
  BLEDevice::setMTU(517);

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(BLE_SERVICE_UUID);

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

  Serial.printf("[BLE] advertising sebagai \"%s\"\n", BLE_DEVICE_NAME);
}

bool bleIsConnected() { return gConnected; }
