import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/operation_result.dart';
import '../models/route_model.dart';
import 'device_identity_service.dart';
import 'auth_session_notifier.dart';

class ApiService {
  static final String serverIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  static final String port = dotenv.env['BACKEND_PORT'] ?? '3000';

  static final String _scheme = dotenv.env['BACKEND_SCHEME'] ?? 'https';
  static final String baseUrl = '$_scheme://$serverIp:$port/api';

  final DeviceIdentityService _deviceIdentity;

  ApiService._internal({DeviceIdentityService? deviceIdentity})
    : _deviceIdentity = deviceIdentity ?? DeviceIdentityService();

  static final ApiService instance = ApiService._internal();

  factory ApiService({DeviceIdentityService? deviceIdentity}) {
    if (deviceIdentity != null) {
      return ApiService._internal(deviceIdentity: deviceIdentity);
    }
    return instance;
  }

  String get currentIp => serverIp;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _deviceIdentity.getDeviceToken();
    final deviceId = token != null
        ? await _deviceIdentity.getOrCreateDeviceId()
        : null;
    return {
      'Content-Type': 'application/json',
      'x-device-id': ?deviceId,
      'x-device-token': ?token,
    };
  }

  static const _messageEligibleStatusCodes = {
    400,
    401,
    403,
    404,
    409,
    422,
    429,
  };

  static final _suspiciousPatterns = RegExp(
    r'(Exception|Traceback|at\s+\S+\(|\.java:|\.dart:|\.py:|StackTrace|'
    r'org\.|com\.|SQL|null pointer|undefined|internal server)',
    caseSensitive: false,
  );

  String _extractErrorMessage(http.Response response, String fallback) {
    if (!_messageEligibleStatusCodes.contains(response.statusCode)) {
      return fallback;
    }

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['error'] is String) {
        final message = (body['error'] as String).trim();

        final isSafe =
            message.isNotEmpty &&
            message.length <= 200 &&
            !_suspiciousPatterns.hasMatch(message);

        if (isSafe) return message;
      }
    } catch (_) {}
    return fallback;
  }

  Future<T> _safeGet<T>({
    required String path,
    required T Function(dynamic decodedBody) onSuccess,
    required T fallback,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return onSuccess(jsonDecode(response.body));
      }
      if (response.statusCode == 401) {
        AuthSessionNotifier.instance.invalidate();
        await _deviceIdentity.clearPairing();
      }
    } catch (e) {
      debugPrint('Error GET $path: $e');
    }
    return fallback;
  }

  Future<OperationResult<T>> _authorizedRequest<T>({
    required Future<http.Response> Function(Map<String, String> headers) call,
    required int successStatus,
    T Function(Map<String, dynamic> body)? parseData,
    String? successMessage,
    Map<int, String> statusMessages = const {},
    String defaultErrorMessage = 'Terjadi kesalahan.',
    String logLabel = 'request',
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await call(headers);

      if (response.statusCode == successStatus) {
        if (parseData == null) {
          return OperationResult.success(null, successMessage);
        }
        final Map<String, dynamic> body = jsonDecode(response.body);
        return OperationResult.success(parseData(body));
      }

      if (response.statusCode == 401) {
        AuthSessionNotifier.instance.invalidate();
        await _deviceIdentity.clearPairing();
      }

      final message =
          statusMessages[response.statusCode] ??
          _extractErrorMessage(response, defaultErrorMessage);

      debugPrint('$logLabel gagal: ${response.statusCode} ${response.body}');
      return OperationResult.failure(message);
    } catch (e) {
      debugPrint('Error $logLabel: $e');
      return OperationResult.failure('Tidak dapat terhubung ke server.');
    }
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/display/status'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<OperationResult<void>> pairDevice(
    String pairingCode, {
    String? deviceName,
  }) async {
    try {
      final deviceId = await _deviceIdentity.getOrCreateDeviceId();
      final response = await http
          .post(
            Uri.parse('$baseUrl/devices/pair'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': pairingCode.trim(),
              'deviceId': deviceId,
              'deviceName': ?deviceName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'] as Map<String, dynamic>;
        final token = data['deviceToken'] as String;
        final bleKey = data['bleKey'] as String?;

        await _deviceIdentity.saveDeviceToken(token, bleKey: bleKey);
        AuthSessionNotifier.instance.markAuthenticated();
        return OperationResult.success(null, 'Device berhasil dipasangkan!');
      }

      return OperationResult.failure(
        _extractErrorMessage(response, 'Kode pairing tidak valid.'),
      );
    } catch (e) {
      debugPrint('Error pairing device: $e');
      return OperationResult.failure('Tidak dapat terhubung ke server.');
    }
  }

  Future<bool> isPaired() => _deviceIdentity.isPaired();

  Future<OperationResult<void>> sendDisplayConfig(
    Map<String, dynamic> payload,
  ) {
    return _authorizedRequest<void>(
      call: (headers) => http.post(
        Uri.parse('$baseUrl/display/send'),
        headers: headers,
        body: jsonEncode(payload),
      ),
      successStatus: 200,
      defaultErrorMessage: 'Gagal menyinkronkan ke server.',
      logLabel: 'sendDisplayConfig',
    );
  }

  Future<List<RouteModel>> fetchRoutes() {
    return _safeGet<List<RouteModel>>(
      path: '/routes',
      onSuccess: (decoded) {
        final List<dynamic> data = decoded['data'];
        return data.map((json) => RouteModel.fromJson(json)).toList();
      },
      fallback: const [],
    );
  }

  Future<OperationResult<RouteModel>> addRoute(RouteModel route) {
    return _authorizedRequest<RouteModel>(
      call: (headers) => http.post(
        Uri.parse('$baseUrl/routes'),
        headers: headers,
        body: jsonEncode(route.toJson()),
      ),
      successStatus: 201,
      parseData: (body) => RouteModel.fromJson(body['data']),
      statusMessages: const {409: 'Kode rute sudah terdaftar.'},
      defaultErrorMessage: 'Gagal menambahkan rute.',
      logLabel: 'addRoute',
    );
  }

  Future<OperationResult<void>> deleteRoute(String id) {
    return _authorizedRequest<void>(
      call: (headers) =>
          http.delete(Uri.parse('$baseUrl/routes/$id'), headers: headers),
      successStatus: 200,
      defaultErrorMessage: 'Gagal menghapus rute.',
      logLabel: 'deleteRoute',
    );
  }

  Future<OperationResult<void>> savePreset(
    String name,
    Map<String, dynamic> payload,
  ) {
    return _authorizedRequest<void>(
      call: (headers) => http.post(
        Uri.parse('$baseUrl/display/presets'),
        headers: headers,
        body: jsonEncode({'name': name, 'payload': payload}),
      ),
      successStatus: 201,
      successMessage: 'Preset berhasil disimpan!',
      statusMessages: const {409: 'Nama preset sudah terdaftar.'},
      defaultErrorMessage: 'Gagal menyimpan preset.',
      logLabel: 'savePreset',
    );
  }

  Future<OperationResult<void>> updatePreset(
    String id,
    String name,
    Map<String, dynamic> payload,
  ) {
    return _authorizedRequest<void>(
      call: (headers) => http.put(
        Uri.parse('$baseUrl/display/presets/$id'),
        headers: headers,
        body: jsonEncode({'name': name, 'payload': payload}),
      ),
      successStatus: 200,
      successMessage: 'Preset berhasil ditimpa!',
      statusMessages: const {
        409: 'Nama preset sudah dipakai oleh preset lain.',
      },
      defaultErrorMessage: 'Gagal menimpa preset.',
      logLabel: 'updatePreset',
    );
  }

  Future<List<dynamic>> fetchPresets() {
    return _safeGet<List<dynamic>>(
      path: '/display/presets',
      onSuccess: (decoded) => decoded['data'] ?? [],
      fallback: const [],
    );
  }
}
