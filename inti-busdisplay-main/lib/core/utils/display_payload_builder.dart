import '../models/route_model.dart';

class DisplayPayloadBuilder {
  const DisplayPayloadBuilder._();

  static Map<String, dynamic> build({
    required RouteModel route,
    required bool isPergi,
    required String animMode,
    required double speed,
    required double brightness,
    required double fontSize,
  }) {
    return {
      "route": route.fullDisplayName,
      "direction": isPergi ? "Pergi" : "Pulang",
      "animation": animMode,
      "speed": speed.toInt(),
      "brightness": brightness.toInt(),
      "fontSize": fontSize.toInt(),
    };
  }
}
