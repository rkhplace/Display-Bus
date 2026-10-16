import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/models/route_model.dart';

void main() {
  group('RouteModel', () {
    test(
      'fullDisplayName menggabungkan code, origin, destination dengan format yang benar',
      () {
        final route = RouteModel(
          code: 'B1',
          origin: 'Bandung',
          destination: 'Garut',
        );
        expect(route.fullDisplayName, 'B1 • Bandung - Garut');
      },
    );

    test('apiRouteName hanya menampilkan origin dan destination', () {
      final route = RouteModel(
        code: 'B1',
        origin: 'Bandung',
        destination: 'Garut',
      );
      expect(route.apiRouteName, 'Bandung - Garut');
    });

    test('toJson tidak menyertakan id (id di-generate server)', () {
      final route = RouteModel(
        id: 'server-generated-id',
        code: 'B1',
        origin: 'Bandung',
        destination: 'Garut',
      );

      final json = route.toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json['code'], 'B1');
      expect(json['origin'], 'Bandung');
      expect(json['destination'], 'Garut');
    });

    test('fromJson berhasil parse response server', () {
      final route = RouteModel.fromJson({
        'id': 'abc-123',
        'code': 'B2',
        'origin': 'Bandung',
        'destination': 'Jakarta',
      });

      expect(route.id, 'abc-123');
      expect(route.code, 'B2');
      expect(route.origin, 'Bandung');
      expect(route.destination, 'Jakarta');
    });

    test(
      'dua RouteModel dengan code/origin/destination sama dianggap setara (id diabaikan)',
      () {
        final a = RouteModel(
          id: 'id-1',
          code: 'B1',
          origin: 'Bandung',
          destination: 'Garut',
        );
        final b = RouteModel(
          id: 'id-2',
          code: 'B1',
          origin: 'Bandung',
          destination: 'Garut',
        );

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      },
    );

    test('RouteModel dengan code berbeda dianggap tidak setara', () {
      final a = RouteModel(code: 'B1', origin: 'Bandung', destination: 'Garut');
      final b = RouteModel(code: 'B2', origin: 'Bandung', destination: 'Garut');

      expect(a, isNot(equals(b)));
    });
  });
}
