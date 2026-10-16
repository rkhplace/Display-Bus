import '../models/operation_result.dart';
import '../services/api_service.dart';

class PresetRepository {
  final ApiService _apiService;

  PresetRepository({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  Future<List<dynamic>> fetchPresets() => _apiService.fetchPresets();

  Future<OperationResult<void>> savePreset(
    String name,
    Map<String, dynamic> payload,
  ) => _apiService.savePreset(name, payload);

  Future<OperationResult<void>> updatePreset(
    String id,
    String name,
    Map<String, dynamic> payload,
  ) => _apiService.updatePreset(id, name, payload);
}
