import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/models/route_model.dart';
import 'package:runningtext_app/core/providers/route_provider.dart';

import '../../fakes/fake_route_repository.dart';

void main() {
  late FakeRouteRepository fakeRepo;
  late RouteProvider provider;

  setUp(() {
    fakeRepo = FakeRouteRepository();

    fakeRepo.routesToReturn = [];
    provider = RouteProvider(routeRepository: fakeRepo);
  });

  group('RouteProvider - inisialisasi', () {
    test(
      'memuat rute default (B1, B2) ketika server tidak mengembalikan apa pun',
      () async {
        await pumpEventQueue();

        expect(provider.routes.length, 2);
        expect(provider.routes.first.code, 'B1');
        expect(provider.selectedRoute.code, 'B1');
      },
    );

    test('menggunakan rute dari server ketika tersedia', () async {
      final serverRoutes = [
        RouteModel(
          id: '1',
          code: 'X1',
          origin: 'Surabaya',
          destination: 'Malang',
        ),
      ];
      final repo = FakeRouteRepository()..routesToReturn = serverRoutes;
      final p = RouteProvider(routeRepository: repo);

      await pumpEventQueue();

      expect(p.routes, serverRoutes);
      expect(p.selectedRoute.code, 'X1');
    });
  });

  group('RouteProvider.addRoute - validasi', () {
    test(
      'menolak jika salah satu field kosong, tanpa memanggil repository',
      () async {
        final result = await provider.addRoute(
          code: '',
          origin: 'Bandung',
          destination: 'Garut',
        );

        expect(result.success, isFalse);
        expect(fakeRepo.lastAddedRoute, isNull);
      },
    );

    test('menolak kode rute yang sudah terdaftar (case-insensitive)', () async {
      await pumpEventQueue();

      final result = await provider.addRoute(
        code: 'b1',
        origin: 'Bandung',
        destination: 'Sumedang',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('sudah terdaftar'));
      expect(fakeRepo.lastAddedRoute, isNull);
    });

    test(
      'menolak kombinasi origin-destination yang sudah ada di arah yang sama',
      () async {
        await pumpEventQueue();

        final result = await provider.addRoute(
          code: 'B3',
          origin: 'Bandung',
          destination: 'Garut',
        );

        expect(result.success, isFalse);
        expect(fakeRepo.lastAddedRoute, isNull);
      },
    );

    test(
      'menolak kombinasi origin-destination yang sudah ada di arah SEBALIKNYA',
      () async {
        await pumpEventQueue();

        final result = await provider.addRoute(
          code: 'B3',
          origin: 'Garut',
          destination: 'Bandung',
        );

        expect(result.success, isFalse);
        expect(result.message, contains('toggle Pergi/Pulang'));
        expect(fakeRepo.lastAddedRoute, isNull);
      },
    );

    test(
      'berhasil menambah rute baru yang valid, memanggil repository dengan data ter-trim',
      () async {
        await pumpEventQueue();

        final newRoute = RouteModel(
          id: 'srv-1',
          code: 'B5',
          origin: 'Bandung',
          destination: 'Lembang',
        );
        fakeRepo.addRouteResult = OperationResult.success(newRoute);

        final result = await provider.addRoute(
          code: '  B5  ',
          origin: '  Bandung  ',
          destination: '  Lembang  ',
        );

        expect(result.success, isTrue);
        expect(fakeRepo.lastAddedRoute?.code, 'B5');
        expect(fakeRepo.lastAddedRoute?.origin, 'Bandung');
        expect(provider.routes, contains(newRoute));
        expect(provider.selectedRoute, newRoute);
      },
    );

    test('ketika repository gagal, state routes tidak berubah', () async {
      await pumpEventQueue();
      final routesBefore = List.of(provider.routes);

      fakeRepo.addRouteResult = OperationResult.failure('Server sedang down.');

      final result = await provider.addRoute(
        code: 'B9',
        origin: 'Bandung',
        destination: 'Cianjur',
      );

      expect(result.success, isFalse);
      expect(provider.routes, routesBefore);
    });
  });

  group('RouteProvider.deleteRoute', () {
    test('menolak hapus jika hanya tersisa 1 rute', () async {
      final singleRouteRepo = FakeRouteRepository()
        ..routesToReturn = [
          RouteModel(id: '1', code: 'ONLY', origin: 'A', destination: 'B'),
        ];
      final p = RouteProvider(routeRepository: singleRouteRepo);
      await pumpEventQueue();

      final result = await p.deleteRoute(p.routes.first);

      expect(result.success, isFalse);
      expect(result.message, contains('Minimal harus ada 1 rute'));
    });

    test(
      'berhasil menghapus rute dan memindahkan seleksi jika yang dihapus sedang aktif',
      () async {
        final repo = FakeRouteRepository()
          ..routesToReturn = [
            RouteModel(id: '1', code: 'B1', origin: 'A', destination: 'B'),
            RouteModel(id: '2', code: 'B2', origin: 'A', destination: 'C'),
          ]
          ..deleteRouteResult = OperationResult.success(null);
        final p = RouteProvider(routeRepository: repo);
        await pumpEventQueue();

        final target = p.routes.first;
        final result = await p.deleteRoute(target);

        expect(result.success, isTrue);
        expect(p.routes.contains(target), isFalse);
        expect(p.selectedRoute, isNot(target));
        expect(repo.lastDeletedId, '1');
      },
    );

    test(
      'menolak menghapus rute bawaan lokal (tanpa id) tanpa memanggil server',
      () async {
        await pumpEventQueue();
        expect(provider.isUsingLocalFallback, isTrue);

        final target = provider.routes.first;
        final result = await provider.deleteRoute(target);

        expect(result.success, isFalse);
        expect(result.message, contains('belum tersinkron'));
        expect(provider.routes.contains(target), isTrue);
        expect(fakeRepo.lastDeletedId, isNull);
      },
    );
  });

  group('RouteProvider.refreshRoutes', () {
    test(
      'memuat rute server setelah sebelumnya gagal, dan mempertahankan '
      'rute terpilih jika masih ada',
      () async {
        await pumpEventQueue();
        expect(provider.isUsingLocalFallback, isTrue);
        provider.setRoute(provider.routes[1]); // B2 Bandung - Jakarta

        fakeRepo.routesToReturn = [
          RouteModel(
            id: 's1',
            code: 'B1',
            origin: 'Bandung',
            destination: 'Garut',
          ),
          RouteModel(
            id: 's2',
            code: 'B2',
            origin: 'Bandung',
            destination: 'Jakarta',
          ),
        ];
        await provider.refreshRoutes();

        expect(provider.isUsingLocalFallback, isFalse);
        expect(provider.selectedRoute.id, 's2');
        expect(provider.isLoadingRoutes, isFalse);
      },
    );

    test('mempertahankan daftar lama ketika server tidak terjangkau', () async {
      await pumpEventQueue();
      fakeRepo.routesToReturn = [
        RouteModel(id: 's1', code: 'X1', origin: 'A', destination: 'B'),
      ];
      await provider.refreshRoutes();
      fakeRepo.routesToReturn = [];

      await provider.refreshRoutes();

      expect(provider.routes.single.id, 's1');
    });

    test('panggilan beruntun hanya memicu satu request', () async {
      await pumpEventQueue();
      final before = fakeRepo.fetchRoutesCallCount;

      await Future.wait([provider.refreshRoutes(), provider.refreshRoutes()]);

      expect(fakeRepo.fetchRoutesCallCount, before + 1);
    });
  });

  group('RouteProvider.addRoute - batas panjang', () {
    test('menolak kode lebih dari 10 karakter', () async {
      await pumpEventQueue();
      final result = await provider.addRoute(
        code: 'ABCDEFGHIJK',
        origin: 'Bandung',
        destination: 'Cimahi',
      );
      expect(result.success, isFalse);
      expect(result.message, contains('maksimal 10'));
      expect(fakeRepo.lastAddedRoute, isNull);
    });

    test('menolak nama kota lebih dari 40 karakter', () async {
      await pumpEventQueue();
      final result = await provider.addRoute(
        code: 'B9',
        origin: 'A' * 41,
        destination: 'Cimahi',
      );
      expect(result.success, isFalse);
      expect(result.message, contains('maksimal 40'));
    });
  });

  group('RouteProvider - setter & payload preset', () {
    test('setDirection dan setRoute mengubah state', () async {
      await pumpEventQueue();

      final second = provider.routes[1];
      provider.setRoute(second);
      provider.setDirection(false);

      expect(provider.selectedRoute, second);
      expect(provider.isPergi, isFalse);
    });

    test('applyRouteFromPayload menerapkan rute & arah dari preset', () async {
      await pumpEventQueue();
      final target = provider.routes[1];

      provider.applyRouteFromPayload({
        'route': target.fullDisplayName,
        'direction': 'Pulang',
      });

      expect(provider.selectedRoute, target);
      expect(provider.isPergi, isFalse);
    });

    test(
      'applyRouteFromPayload fallback ke rute pertama jika nama rute tidak dikenali',
      () async {
        await pumpEventQueue();

        provider.applyRouteFromPayload({
          'route': 'Rute yang tidak ada di daftar',
          'direction': 'Pergi',
        });

        expect(provider.selectedRoute, provider.routes.first);
      },
    );

    test(
      'resetSelection mengembalikan ke rute pertama dan arah Pergi',
      () async {
        await pumpEventQueue();
        provider.setRoute(provider.routes[1]);
        provider.setDirection(false);

        provider.resetSelection();

        expect(provider.selectedRoute, provider.routes.first);
        expect(provider.isPergi, isTrue);
      },
    );
  });
}
