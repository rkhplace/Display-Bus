import 'package:flutter/foundation.dart';
import '../models/operation_result.dart';
import '../models/route_model.dart';
import '../repositories/route_repository.dart';

class RouteProvider extends ChangeNotifier {
  final RouteRepository _routeRepository;

  RouteProvider({RouteRepository? routeRepository})
    : _routeRepository = routeRepository ?? RouteRepository() {
    refreshRoutes();
  }

  // Sama dengan batas validasi di backend (src/lib/validation.js).
  static const int maxCodeLength = 10;
  static const int maxCityLength = 40;

  List<RouteModel> _routes = [
    RouteModel(code: 'B1', origin: 'Bandung', destination: 'Garut'),
    RouteModel(code: 'B2', origin: 'Bandung', destination: 'Jakarta'),
  ];
  late RouteModel _selectedRoute = _routes.first;
  bool _isPergi = true;

  bool _isLoadingRoutes = true;
  Future<void>? _inFlightLoad;

  List<RouteModel> get routes => _routes;
  RouteModel get selectedRoute => _selectedRoute;
  bool get isPergi => _isPergi;
  bool get isLoadingRoutes => _isLoadingRoutes;

  /// Memuat ulang daftar rute dari server. Dipanggil saat app dibuka, saat
  /// halaman utama tampil (mis. setelah pairing), dan dari tombol muat ulang.
  /// Jika server tidak terjangkau, daftar yang ada dipertahankan.
  Future<void> refreshRoutes() {
    return _inFlightLoad ??= _loadRoutes().whenComplete(() => _inFlightLoad = null);
  }

  Future<void> _loadRoutes() async {
    _isLoadingRoutes = true;
    notifyListeners();
    try {
      final serverRoutes = await _routeRepository.fetchRoutes();
      if (serverRoutes.isNotEmpty) {
        final previous = _selectedRoute;
        _routes = serverRoutes;
        _selectedRoute = _routes.firstWhere(
          (r) => r == previous,
          orElse: () => _routes.first,
        );
      }
    } finally {
      _isLoadingRoutes = false;
      notifyListeners();
    }
  }

  /// Rute bawaan lokal (belum pernah dimuat dari server) tidak punya id.
  bool get isUsingLocalFallback => _routes.any((r) => r.id == null);

  void setRoute(RouteModel route) {
    _selectedRoute = route;
    notifyListeners();
  }

  void setDirection(bool isPergi) {
    _isPergi = isPergi;
    notifyListeners();
  }

  Future<OperationResult<RouteModel>> addRoute({
    required String code,
    required String origin,
    required String destination,
  }) async {
    final trimmedCode = code.trim();
    final trimmedOrigin = origin.trim();
    final trimmedDestination = destination.trim();

    if (trimmedCode.isEmpty ||
        trimmedOrigin.isEmpty ||
        trimmedDestination.isEmpty) {
      return OperationResult.failure(
        'Kode, asal, dan tujuan rute wajib diisi.',
      );
    }

    if (trimmedCode.length > maxCodeLength) {
      return OperationResult.failure(
        'Kode rute maksimal $maxCodeLength karakter.',
      );
    }
    if (trimmedOrigin.length > maxCityLength ||
        trimmedDestination.length > maxCityLength) {
      return OperationResult.failure(
        'Nama kota maksimal $maxCityLength karakter.',
      );
    }

    final isDuplicateCode = _routes.any(
      (r) => r.code.toLowerCase() == trimmedCode.toLowerCase(),
    );
    if (isDuplicateCode) {
      return OperationResult.failure(
        'Kode rute "$trimmedCode" sudah terdaftar.',
      );
    }

    final isDuplicateRouteName = _routes.any(
      (r) =>
          (r.origin.toLowerCase() == trimmedOrigin.toLowerCase() &&
              r.destination.toLowerCase() ==
                  trimmedDestination.toLowerCase()) ||
          (r.origin.toLowerCase() == trimmedDestination.toLowerCase() &&
              r.destination.toLowerCase() == trimmedOrigin.toLowerCase()),
    );
    if (isDuplicateRouteName) {
      return OperationResult.failure(
        'Rute "$trimmedOrigin - $trimmedDestination" sudah terdaftar (arah sebaliknya '
        'sudah ada, gunakan toggle Pergi/Pulang).',
      );
    }

    final newRoute = RouteModel(
      code: trimmedCode,
      origin: trimmedOrigin,
      destination: trimmedDestination,
    );

    final result = await _routeRepository.addRoute(newRoute);

    if (result.success && result.data != null) {
      _routes.add(result.data!);
      _selectedRoute = result.data!;
      notifyListeners();
    }

    return result;
  }

  Future<OperationResult<void>> deleteRoute(RouteModel route) async {
    if (_routes.length <= 1) {
      return OperationResult.failure('Minimal harus ada 1 rute tersisa!');
    }

    // Tanpa id, rute hanya ada di HP: menghapusnya di sini tidak menghapus
    // apa pun di server, dan rute itu akan muncul lagi saat daftar dimuat ulang.
    if (route.id == null) {
      return OperationResult.failure(
        'Daftar rute belum tersinkron dengan server. Tekan muat ulang rute '
        'lalu coba lagi.',
      );
    }

    final result = await _routeRepository.deleteRoute(route.id!);
    if (!result.success) {
      return result;
    }

    _routes.remove(route);
    if (_selectedRoute == route) {
      _selectedRoute = _routes.first;
    }
    notifyListeners();
    return OperationResult.success(null, 'Rute berhasil dihapus.');
  }

  bool applyRouteFromPayload(Map<String, dynamic> payload) {
    final routeName = payload['route'] as String?;
    bool matched = true;

    if (routeName != null) {
      final found = _routes.where((r) => r.fullDisplayName == routeName);
      if (found.isEmpty) {
        matched = false;
        _selectedRoute = _routes.first;
      } else {
        _selectedRoute = found.first;
      }
    }

    _isPergi = payload['direction'] == 'Pergi';
    notifyListeners();
    return matched;
  }

  void resetSelection() {
    if (_routes.isNotEmpty) _selectedRoute = _routes.first;
    _isPergi = true;
    notifyListeners();
  }
}
