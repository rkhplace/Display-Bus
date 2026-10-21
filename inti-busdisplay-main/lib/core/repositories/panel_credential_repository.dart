import '../models/operation_result.dart';
import '../models/panel_credential.dart';
import '../services/api_service.dart';
import '../services/device_identity_service.dart';

/// Mengambil kredensial BLE per panel: dari cache selama masih lama berlaku,
/// dari server bila hampir habis, dan tetap memakai cache yang masih berlaku
/// saat server tidak terjangkau (bus sering tanpa sinyal).
class PanelCredentialRepository {
  final ApiService _apiService;
  final DeviceIdentityService _deviceIdentity;

  PanelCredentialRepository({
    ApiService? apiService,
    DeviceIdentityService? deviceIdentity,
  }) : _apiService = apiService ?? ApiService.instance,
       _deviceIdentity = deviceIdentity ?? DeviceIdentityService();

  /// [forceRefresh] dipakai setelah panel menolak kredensial yang ada
  /// (kedaluwarsa atau kunci panel diganti): cache tidak dipakai sebagai cadangan.
  Future<OperationResult<PanelCredential>> credentialFor(
    String panel, {
    bool forceRefresh = false,
  }) async {
    final cached = await _deviceIdentity.getPanelCredential(panel);
    if (!forceRefresh && cached != null && !cached.needsRefresh()) {
      return OperationResult.success(cached);
    }

    final fetched = await _apiService.fetchPanelCredential(panel);
    final credential = fetched.data;
    if (fetched.success && credential != null) {
      await _deviceIdentity.savePanelCredential(credential);
      return OperationResult.success(credential);
    }

    if (!forceRefresh && cached != null && !cached.isExpired()) {
      return OperationResult.success(cached);
    }
    return OperationResult.failure(
      fetched.message ??
          'Kunci akses panel tidak tersedia. Hubungkan HP ke server lalu coba lagi.',
    );
  }
}
