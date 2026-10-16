import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/models/route_model.dart';
import 'package:runningtext_app/core/services/api_service.dart';

class FakeApiServiceForConnection implements ApiService {
  OperationResult<void>? sendDisplayConfigResult;
  bool sendDisplayConfigThrows = false;
  Map<String, dynamic>? lastSentPayload;

  @override
  Future<OperationResult<void>> sendDisplayConfig(
    Map<String, dynamic> payload,
  ) async {
    lastSentPayload = payload;
    if (sendDisplayConfigThrows) {
      throw Exception('Simulated network error');
    }
    return sendDisplayConfigResult ??
        OperationResult.failure('sendDisplayConfigResult belum dikonfigurasi');
  }

  @override
  String get currentIp => '127.0.0.1';

  @override
  Future<bool> checkConnection() async => true;

  @override
  Future<OperationResult<void>> pairDevice(
    String pairingCode, {
    String? deviceName,
  }) async => OperationResult.success(null);

  @override
  Future<bool> isPaired() async => true;

  @override
  Future<List<RouteModel>> fetchRoutes() async => const [];

  @override
  Future<OperationResult<RouteModel>> addRoute(RouteModel route) async =>
      OperationResult.failure('tidak dipakai');

  @override
  Future<OperationResult<void>> deleteRoute(String id) async =>
      OperationResult.failure('tidak dipakai');

  @override
  Future<OperationResult<void>> savePreset(
    String name,
    Map<String, dynamic> payload,
  ) async => OperationResult.failure('tidak dipakai');

  @override
  Future<OperationResult<void>> updatePreset(
    String id,
    String name,
    Map<String, dynamic> payload,
  ) async => OperationResult.failure('tidak dipakai');

  @override
  Future<List<dynamic>> fetchPresets() async => const [];
}
