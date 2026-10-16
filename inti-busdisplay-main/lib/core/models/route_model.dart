class RouteModel {
  final String? id;
  final String code;
  final String origin;
  final String destination;

  RouteModel({
    this.id,
    required this.code,
    required this.origin,
    required this.destination,
  });

  String get fullDisplayName => '$code • $origin - $destination';
  String get apiRouteName => '$origin - $destination';

  Map<String, dynamic> toJson() => {
    'code': code,
    'origin': origin,
    'destination': destination,
  };

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String?,
      code: json['code'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteModel &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          origin == other.origin &&
          destination == other.destination;

  @override
  int get hashCode => code.hashCode ^ origin.hashCode ^ destination.hashCode;
}
