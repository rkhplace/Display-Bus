import '../models/operation_result.dart';
import '../models/route_model.dart';
import '../services/api_service.dart';

class RouteRepository {
  final ApiService _apiService;

  RouteRepository({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  Future<List<RouteModel>> fetchRoutes() => _apiService.fetchRoutes();

  Future<OperationResult<RouteModel>> addRoute(RouteModel route) =>
      _apiService.addRoute(route);

  Future<OperationResult<void>> deleteRoute(String id) =>
      _apiService.deleteRoute(id);
}
