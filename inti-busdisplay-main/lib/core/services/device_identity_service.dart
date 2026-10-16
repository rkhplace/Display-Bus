import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const _storage = FlutterSecureStorage();
  static const _keyDeviceId = 'device_id';
  static const _keyDeviceToken = 'device_token';
  static const _keyPairedAtMillis = 'device_paired_at';
  static const _keyBleKey = 'device_ble_key';

  static const Duration maxLocalSessionAge = Duration(days: 30);

  Future<String> getOrCreateDeviceId() async {
    String? id = await _storage.read(key: _keyDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _keyDeviceId, value: id);
    }
    return id;
  }

  Future<String?> getDeviceToken() => _storage.read(key: _keyDeviceToken);

  Future<void> saveDeviceToken(String token, {String? bleKey}) async {
    await _storage.write(key: _keyDeviceToken, value: token);
    await _storage.write(
      key: _keyPairedAtMillis,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    if (bleKey != null && bleKey.isNotEmpty) {
      await _storage.write(key: _keyBleKey, value: bleKey);
    }
  }

  Future<String?> getBleKey() => _storage.read(key: _keyBleKey);

  Future<bool> isPaired() async {
    final token = await getDeviceToken();
    if (token == null || token.isEmpty) return false;

    if (await _isLocalSessionExpired()) {
      debugPrint(
        'Sesi lokal kedaluwarsa (>${maxLocalSessionAge.inDays} hari), '
        'device perlu dipasangkan ulang.',
      );
      await clearPairing();
      return false;
    }
    return true;
  }

  Future<bool> _isLocalSessionExpired() async {
    final raw = await _storage.read(key: _keyPairedAtMillis);

    if (raw == null) return false;

    final millis = int.tryParse(raw);
    if (millis == null) return false;

    final pairedAt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime.now().difference(pairedAt) > maxLocalSessionAge;
  }

  Future<void> clearPairing() async {
    await _storage.delete(key: _keyDeviceToken);
    await _storage.delete(key: _keyPairedAtMillis);
    await _storage.delete(key: _keyBleKey);
  }
}
