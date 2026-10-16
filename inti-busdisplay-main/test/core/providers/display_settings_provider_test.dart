import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/providers/display_settings_provider.dart';

void main() {
  late DisplaySettingsProvider provider;

  setUp(() {
    provider = DisplaySettingsProvider();
  });

  group('DisplaySettingsProvider - nilai default', () {
    test('nilai awal sesuai default aplikasi', () {
      expect(provider.animMode, 'Scroll Left');
      expect(provider.speed, 50);
      expect(provider.brightness, 80);
      expect(provider.fontSize, 16);
    });
  });

  group('DisplaySettingsProvider - setter', () {
    test('setAnimMode mengubah nilai dan memberi tahu listener', () {
      var notified = false;
      provider.addListener(() => notified = true);

      provider.setAnimMode('Blink');

      expect(provider.animMode, 'Blink');
      expect(notified, isTrue);
    });

    test(
      'setSpeed, setBrightness, setFontSize mengubah nilai masing-masing',
      () {
        provider.setSpeed(75);
        provider.setBrightness(30);
        provider.setFontSize(20);

        expect(provider.speed, 75);
        expect(provider.brightness, 30);
        expect(provider.fontSize, 20);
      },
    );
  });

  group('DisplaySettingsProvider.resetToDefault', () {
    test('mengembalikan semua nilai ke default setelah diubah', () {
      provider.setAnimMode('Blink');
      provider.setSpeed(10);
      provider.setBrightness(10);
      provider.setFontSize(10);

      provider.resetToDefault();

      expect(provider.animMode, 'Scroll Left');
      expect(provider.speed, 50);
      expect(provider.brightness, 80);
      expect(provider.fontSize, 16);
    });
  });

  group('DisplaySettingsProvider.applyFromPayload', () {
    test('menerapkan semua field dari payload preset', () {
      provider.applyFromPayload({
        'animation': 'Running',
        'speed': 90,
        'brightness': 40,
        'fontSize': 24,
      });

      expect(provider.animMode, 'Running');
      expect(provider.speed, 90.0);
      expect(provider.brightness, 40.0);
      expect(provider.fontSize, 24.0);
    });

    test(
      'menggunakan nilai default ketika field payload hilang/null (data preset lama/rusak)',
      () {
        provider.applyFromPayload(<String, dynamic>{});

        expect(provider.animMode, 'Static');
        expect(provider.speed, 50.0);
        expect(provider.brightness, 80.0);
        expect(provider.fontSize, 16.0);
      },
    );
  });
}
