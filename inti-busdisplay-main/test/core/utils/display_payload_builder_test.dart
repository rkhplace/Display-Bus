import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/models/route_model.dart';
import 'package:runningtext_app/core/utils/display_payload_builder.dart';

void main() {
  group('DisplayPayloadBuilder.build', () {
    final route = RouteModel(
      code: 'B1',
      origin: 'Bandung',
      destination: 'Garut',
    );

    test('direction "Pergi" ketika isPergi true', () {
      final payload = DisplayPayloadBuilder.build(
        route: route,
        isPergi: true,
        animMode: 'Scroll Left',
        speed: 50,
        brightness: 80,
        fontSize: 16,
      );

      expect(payload['direction'], 'Pergi');
    });

    test('direction "Pulang" ketika isPergi false', () {
      final payload = DisplayPayloadBuilder.build(
        route: route,
        isPergi: false,
        animMode: 'Scroll Left',
        speed: 50,
        brightness: 80,
        fontSize: 16,
      );

      expect(payload['direction'], 'Pulang');
    });

    test('route memakai fullDisplayName, bukan apiRouteName', () {
      final payload = DisplayPayloadBuilder.build(
        route: route,
        isPergi: true,
        animMode: 'Static',
        speed: 50,
        brightness: 80,
        fontSize: 16,
      );

      expect(payload['route'], 'B1 • Bandung - Garut');
    });

    test('nilai double dikonversi ke int (server tidak menerima desimal)', () {
      final payload = DisplayPayloadBuilder.build(
        route: route,
        isPergi: true,
        animMode: 'Blink',
        speed: 42.9,
        brightness: 77.4,
        fontSize: 15.99,
      );

      expect(payload['speed'], 42);
      expect(payload['brightness'], 77);
      expect(payload['fontSize'], 15);
      expect(payload['speed'], isA<int>());
    });

    test('semua field yang dibutuhkan backend tersedia di payload', () {
      final payload = DisplayPayloadBuilder.build(
        route: route,
        isPergi: true,
        animMode: 'Running',
        speed: 50,
        brightness: 80,
        fontSize: 16,
      );

      expect(payload.keys.toSet(), {
        'route',
        'direction',
        'animation',
        'speed',
        'brightness',
        'fontSize',
      });
    });
  });
}
