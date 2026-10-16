import 'package:flutter/foundation.dart';
import '../models/operation_result.dart';
import '../repositories/preset_repository.dart';

class PresetProvider extends ChangeNotifier {
  final PresetRepository _presetRepository;

  PresetProvider({PresetRepository? presetRepository})
    : _presetRepository = presetRepository ?? PresetRepository();

  String? _loadedPresetId;
  String? _loadedPresetName;

  String? get loadedPresetId => _loadedPresetId;
  String? get loadedPresetName => _loadedPresetName;
  bool get hasLoadedPreset => _loadedPresetId != null;

  Future<List<dynamic>> getSavedPresets() => _presetRepository.fetchPresets();

  Future<OperationResult<void>> saveCurrentPreset(
    String presetName,
    Map<String, dynamic> payload,
  ) {
    return _presetRepository.savePreset(presetName, payload);
  }

  Future<OperationResult<void>> overwritePreset({
    required String presetId,
    required String presetName,
    required Map<String, dynamic> payload,
  }) {
    return _presetRepository.updatePreset(presetId, presetName, payload);
  }

  Future<OperationResult<void>> overwriteLoadedPreset(
    Map<String, dynamic> payload,
  ) {
    if (_loadedPresetId == null) {
      return Future.value(
        OperationResult.failure(
          'Tidak ada preset yang sedang dimuat untuk ditimpa.',
        ),
      );
    }
    return overwritePreset(
      presetId: _loadedPresetId!,
      presetName: _loadedPresetName ?? 'Preset',
      payload: payload,
    );
  }

  void markLoadedPreset({String? presetId, String? presetName}) {
    _loadedPresetId = presetId;
    _loadedPresetName = presetName;
    notifyListeners();
  }

  void clearLoadedPreset() {
    _loadedPresetId = null;
    _loadedPresetName = null;
    notifyListeners();
  }
}
