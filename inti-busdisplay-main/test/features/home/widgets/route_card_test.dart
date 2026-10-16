import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/models/route_model.dart';
import 'package:runningtext_app/core/providers/route_provider.dart';
import 'package:runningtext_app/features/home/widgets/route_card.dart';
import '../../../fakes/fake_route_repository.dart';

Widget _wrap(RouteProvider provider) {
  return ChangeNotifierProvider<RouteProvider>.value(
    value: provider,
    child: const MaterialApp(home: Scaffold(body: RouteCard())),
  );
}

void main() {
  group('RouteCard - tampilan awal', () {
    testWidgets('menampilkan kode rute yang sedang aktif', (tester) async {
      final fakeRepo = FakeRouteRepository()..routesToReturn = [];
      final provider = RouteProvider(routeRepository: fakeRepo);

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text('B1'), findsOneWidget);
    });
  });

  group('RouteCard - menambah rute via dialog', () {
    late FakeRouteRepository fakeRepo;
    late RouteProvider provider;

    setUp(() async {
      fakeRepo = FakeRouteRepository()..routesToReturn = [];
      provider = RouteProvider(routeRepository: fakeRepo);
    });

    testWidgets(
      'berhasil menambah rute baru, memanggil repository, dan menampilkan SnackBar sukses',
      (tester) async {
        fakeRepo.addRouteResult = OperationResult.success(
          RouteModel(
            id: 'srv-1',
            code: 'B5',
            origin: 'Bandung',
            destination: 'Lembang',
          ),
        );

        await tester.pumpWidget(_wrap(provider));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Tambah Rute Baru'), findsOneWidget);

        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(3));
        await tester.enterText(fields.at(0), 'B5');
        await tester.enterText(fields.at(1), 'Bandung');
        await tester.enterText(fields.at(2), 'Lembang');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah Rute Baru'), findsNothing);
        expect(fakeRepo.lastAddedRoute?.code, 'B5');
        expect(fakeRepo.lastAddedRoute?.origin, 'Bandung');
        expect(fakeRepo.lastAddedRoute?.destination, 'Lembang');

        expect(provider.selectedRoute.code, 'B5');
        expect(find.text('Rute berhasil ditambahkan.'), findsOneWidget);
      },
    );

    testWidgets(
      'menampilkan pesan validasi ketika field dikosongkan, tanpa memanggil repository',
      (tester) async {
        await tester.pumpWidget(_wrap(provider));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastAddedRoute, isNull);
        expect(
          find.text('Kode, asal, dan tujuan rute wajib diisi.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'menampilkan pesan error dari server ketika kode rute duplikat',
      (tester) async {
        fakeRepo.addRouteResult = OperationResult.failure(
          'Kode rute sudah terdaftar.',
        );

        await tester.pumpWidget(_wrap(provider));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'B1');
        await tester.enterText(fields.at(1), 'Bandung');
        await tester.enterText(fields.at(2), 'Cianjur');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastAddedRoute, isNull);
        expect(find.text('Kode rute "B1" sudah terdaftar.'), findsOneWidget);
      },
    );
  });

  group('RouteCard - menghapus rute via dialog konfirmasi', () {
    testWidgets(
      'berhasil menghapus rute aktif setelah konfirmasi, dan memindahkan seleksi',
      (tester) async {
        final fakeRepo = FakeRouteRepository()
          ..routesToReturn = [
            RouteModel(
              id: 'r1',
              code: 'B1',
              origin: 'Bandung',
              destination: 'Garut',
            ),
            RouteModel(
              id: 'r2',
              code: 'B2',
              origin: 'Bandung',
              destination: 'Jakarta',
            ),
          ]
          ..deleteRouteResult = OperationResult.success(null);
        final provider = RouteProvider(routeRepository: fakeRepo);

        await tester.pumpWidget(_wrap(provider));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Hapus Rute'), findsOneWidget);
        expect(find.textContaining('B1 • Bandung - Garut'), findsWidgets);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(find.text('Hapus Rute'), findsNothing);
        expect(fakeRepo.lastDeletedId, 'r1');
        expect(provider.routes.any((r) => r.id == 'r1'), isFalse);
        expect(provider.selectedRoute.code, 'B2');
        expect(find.text('Rute berhasil dihapus.'), findsOneWidget);
      },
    );

    testWidgets('membatalkan penghapusan ketika tombol Batal ditekan', (
      tester,
    ) async {
      final fakeRepo = FakeRouteRepository()
        ..routesToReturn = [
          RouteModel(
            id: 'r1',
            code: 'B1',
            origin: 'Bandung',
            destination: 'Garut',
          ),
          RouteModel(
            id: 'r2',
            code: 'B2',
            origin: 'Bandung',
            destination: 'Jakarta',
          ),
        ];
      final provider = RouteProvider(routeRepository: fakeRepo);

      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Rute'), findsNothing);
      expect(fakeRepo.lastDeletedId, isNull);
      expect(provider.routes.length, 2);
    });

    testWidgets(
      'menampilkan peringatan tanpa membuka dialog ketika hanya tersisa 1 rute',
      (tester) async {
        final fakeRepo = FakeRouteRepository()
          ..routesToReturn = [
            RouteModel(id: 'only', code: 'ONLY', origin: 'A', destination: 'B'),
          ];
        final provider = RouteProvider(routeRepository: fakeRepo);

        await tester.pumpWidget(_wrap(provider));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Hapus Rute'), findsNothing);
        expect(find.text('Minimal harus ada 1 rute tersisa!'), findsOneWidget);
      },
    );
  });
}
