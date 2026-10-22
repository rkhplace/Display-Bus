import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/panel_credential.dart';

class DeviceIdentityService {
  static const _storage = FlutterSecureStorage();
  static const _keyDeviceId = 'device_id';
  static const _keyDeviceToken = 'device_token';
  static const _keyPairedAtMillis = 'device_paired_at';
  static const _keyPanelCredentials = 'panel_credentials';

  // Kunci BLE global versi 1. Tidak dipakai lagi; hanya dihapus saat pairing
  // dibersihkan supaya tidak tertinggal di HP lama.
  static const _keyLegacyBleKey = 'device_ble_key';

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

  Future<void> saveDeviceToken(String token) async {
    await _storage.write(key: _keyDeviceToken, value: token);
    await _storage.write(
      key: _keyPairedAtMillis,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<Map<String, dynamic>> _readCredentials() async {
    final raw = await _storage.read(key: _keyPanelCredentials);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('Data kredensial panel rusak, diabaikan: $e');
      return {};
    }
  }

  /// Kredensial tersimpan untuk [panel] (nama BLE, tidak peka huruf besar).
  Future<PanelCredential?> getPanelCredential(String panel) async {
    final json = (await _readCredentials())[panel.toUpperCase()];
    if (json is! Map) return null;
    try {
      return PanelCredential.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      debugPrint('Kredensial panel $panel rusak, diabaikan: $e');
      return null;
    }
  }

  Future<void> savePanelCredential(PanelCredential credential) async {
    final all = await _readCredentials();
    all[credential.panel.toUpperCase()] = credential.toJson();
    await _storage.write(key: _keyPanelCredentials, value: jsonEncode(all));
  }

  Future<bool> isPaired() async {
    final String? token;
    try {
      token = await getDeviceToken();
    } catch (e) {
      // Biasanya terjadi setelah install ulang: Android memulihkan data
      // terenkripsi dari backup, tapi kunci Keystore-nya sudah tidak ada,
      // sehingga data tidak bisa dibaca lagi. Hapus supaya bisa dipasangkan
      // ulang dari awal.
      debugPrint('Penyimpanan aman tidak bisa dibaca, direset: $e');
      await _resetStorage();
      return false;
    }
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

  Future<void> _resetStorage() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Gagal mereset penyimpanan aman: $e');
    }
  }

  Future<void> clearPairing() async {
    await _storage.delete(key: _keyDeviceToken);
    await _storage.delete(key: _keyPairedAtMillis);
    await _storage.delete(key: _keyPanelCredentials);
    await _storage.delete(key: _keyLegacyBleKey);
  }
}
