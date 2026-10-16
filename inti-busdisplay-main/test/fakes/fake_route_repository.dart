import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/models/route_model.dart';
import 'package:runningtext_app/core/repositories/route_repository.dart';

class FakeRouteRepository extends RouteRepository {
  List<RouteModel> routesToReturn = [];
  OperationResult<RouteModel>? addRouteResult;
  OperationResult<void>? deleteRouteResult;

  RouteModel? lastAddedRoute;
  String? lastDeletedId;
  int fetchRoutesCallCount = 0;

  @override
  Future<List<RouteModel>> fetchRoutes() async {
    fetchRoutesCallCount++;
    return routesToReturn;
  }

  @override
  Future<OperationResult<RouteModel>> addRoute(RouteModel route) async {
    lastAddedRoute = route;
    return addRouteResult ??
        OperationResult.failure('addRouteResult belum dikonfigurasi');
  }

  @override
  Future<OperationResult<void>> deleteRoute(String id) async {
    lastDeletedId = id;
    return deleteRouteResult ??
        OperationResult.failure('deleteRouteResult belum dikonfigurasi');
  }
}
