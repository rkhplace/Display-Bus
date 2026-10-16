import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/models/operation_result.dart';

void main() {
  group('OperationResult', () {
    test(
      'success() menghasilkan result dengan success true, data, dan message yang benar',
      () {
        final result = OperationResult.success('some-data', 'Berhasil!');

        expect(result.success, isTrue);
        expect(result.data, 'some-data');
        expect(result.message, 'Berhasil!');
      },
    );

    test(
      'success() tanpa argumen tetap valid dengan data dan message null',
      () {
        final result = OperationResult<Object?>.success();

        expect(result.success, isTrue);
        expect(result.data, isNull);
        expect(result.message, isNull);
      },
    );

    test(
      'failure() menghasilkan result dengan success false dan data null',
      () {
        final result = OperationResult<String>.failure('Terjadi kesalahan.');

        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.message, 'Terjadi kesalahan.');
      },
    );
  });
}
