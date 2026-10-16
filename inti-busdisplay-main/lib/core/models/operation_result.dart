class OperationResult<T> {
  final bool success;
  final T? data;
  final String? message;

  const OperationResult._({required this.success, this.data, this.message});

  factory OperationResult.success([T? data, String? message]) =>
      OperationResult._(success: true, data: data, message: message);

  factory OperationResult.failure(String message) =>
      OperationResult._(success: false, message: message);
}
