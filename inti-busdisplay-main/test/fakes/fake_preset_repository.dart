import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/repositories/preset_repository.dart';

class FakePresetRepository extends PresetRepository {
  List<dynamic> presetsToReturn = [];
  OperationResult<void>? saveResult;
  OperationResult<void>? updateResult;

  String? lastSavedName;
  Map<String, dynamic>? lastSavedPayload;
  String? lastUpdatedId;
  String? lastUpdatedName;
  Map<String, dynamic>? lastUpdatedPayload;

  @override
  Future<List<dynamic>> fetchPresets() async => presetsToReturn;

  @override
  Future<OperationResult<void>> savePreset(
    String name,
    Map<String, dynamic> payload,
  ) async {
    lastSavedName = name;
    lastSavedPayload = payload;
    return saveResult ??
        OperationResult.failure('saveResult belum dikonfigurasi');
  }

  @override
  Future<OperationResult<void>> updatePreset(
    String id,
    String name,
    Map<String, dynamic> payload,
  ) async {
    lastUpdatedId = id;
    lastUpdatedName = name;
    lastUpdatedPayload = payload;
    return updateResult ??
        OperationResult.failure('updateResult belum dikonfigurasi');
  }
}
