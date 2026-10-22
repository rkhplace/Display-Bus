import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/theme/app_colors.dart';
import 'package:runningtext_app/core/utils/feedback_extension.dart';
import 'package:runningtext_app/core/widgets/app_toast.dart';

/// Tombol di dasar layar, seperti "Kirim ke Display" di layar kontrol.
Widget _app() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            const Spacer(),
            ElevatedButton(
              key: const ValueKey('bottom-button'),
              onPressed: () {},
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    ),
  );
}

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byKey(const ValueKey('bottom-button')));

void main() {
  testWidgets('tampil di atas layar, tidak menutupi tombol di bawah', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    _ctx(tester).showFeedback(message: 'Berhasil!', color: AppColors.success);
    await tester.pumpAndSettle();

    final toast = tester.getRect(find.byType(AppToastCard));
    final button = tester.getRect(find.byKey(const ValueKey('bottom-button')));
    expect(toast.bottom, lessThan(button.top));

    await tester.tap(find.text('Kirim'));
  });

  testWidgets('toast baru menggantikan yang lama, tidak mengantre', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    _ctx(tester).showFeedback(message: 'Pertama', color: AppColors.success);
    await tester.pumpAndSettle();
    _ctx(tester).showFeedback(message: 'Kedua', color: AppColors.danger);
    await tester.pumpAndSettle();

    expect(find.byType(AppToastCard), findsOneWidget);
    expect(find.text('Pertama'), findsNothing);
    expect(find.text('Kedua'), findsOneWidget);
  });

  testWidgets('hilang sendiri setelah durasinya habis', (tester) async {
    await tester.pumpWidget(_app());
    _ctx(tester).showFeedback(message: 'Sukses', color: AppColors.success);
    await tester.pumpAndSettle();
    expect(find.text('Sukses'), findsOneWidget);

    await tester.pump(AppToast.successDuration);
    await tester.pumpAndSettle();
    expect(find.text('Sukses'), findsNothing);
  });

  testWidgets('bisa ditutup dengan diketuk', (tester) async {
    await tester.pumpWidget(_app());
    _ctx(tester).showFeedback(message: 'Gagal', color: AppColors.danger);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gagal'));
    await tester.pumpAndSettle();
    expect(find.byType(AppToastCard), findsNothing);
  });
}
