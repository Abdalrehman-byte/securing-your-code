import 'dart:convert';
import 'dart:io';

import 'package:car_repair_app/src/data/key_value_store.dart';
import 'package:car_repair_app/src/data/response_cache.dart';
import 'package:car_repair_app/src/data/saved_vehicles.dart';
import 'package:car_repair_app/src/data/vpic_endpoints.dart';
import 'package:car_repair_app/src/data/vpic_models.dart';
import 'package:car_repair_app/src/data/vpic_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/fixtures.dart';

void main() {
  final fixtures = Fixtures.load();
  late Directory dir;
  late FakeVpicNetwork network;
  late DateTime now;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('car_repair_cache_test_');
    network = FakeVpicNetwork(fixtures);
    now = DateTime.utc(2026, 11, 12, 12);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// A repository as created at app start: a new object reading [dir].
  VpicRepository newRepository() {
    return VpicRepository(
      client: network.client,
      cache: ResponseCache(FileKeyValueStore(dir)),
      now: () => now,
    );
  }

  String rawJson(Sourced<VpicResponse> sourced) {
    return jsonEncode(<Object?>[for (final r in sourced.data.results) r.raw]);
  }

  group('FileKeyValueStore', () {
    test('writes, reads back, overwrites and deletes', () async {
      final store = FileKeyValueStore(dir);
      expect(await store.read('a'), isNull);
      await store.write('a', 'one');
      expect(await store.read('a'), 'one');
      await store.write('a', 'two');
      expect(await store.read('a'), 'two');
      await store.delete('a');
      expect(await store.read('a'), isNull);
      await store.delete('a');
    });

    test('data survives a new store object on the same directory', () async {
      await FileKeyValueStore(dir).write('k', 'القيمة ✓ value');
      expect(await FileKeyValueStore(dir).read('k'), 'القيمة ✓ value');
    });

    test('creates the directory when it does not exist yet', () async {
      final nested = Directory('${dir.path}/a/b');
      await FileKeyValueStore(nested).write('k', 'v');
      expect(await FileKeyValueStore(nested).read('k'), 'v');
    });

    test('a damaged file reads as "nothing saved"', () async {
      final store = FileKeyValueStore(dir);
      await store.write('k', 'v');
      await store.fileFor('k').writeAsString('{ not json');
      expect(await store.read('k'), isNull);
    });

    test('file names are stable and file-system safe', () {
      final url = VpicEndpoints.allMakes().toString();
      expect(stableKeyHash(url), stableKeyHash(url));
      expect(stableKeyHash(url), matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(stableKeyHash(url), isNot(stableKeyHash('$url ')));
    });
  });

  group('ResponseCache', () {
    test('returns the body byte-for-byte with its download time', () async {
      final cache = ResponseCache(FileKeyValueStore(dir));
      final url = fixtures.url('all_makes');
      final body = fixtures.body('all_makes');
      expect(await cache.get(url), isNull);
      await cache.put(url, body, now);
      final cached = await cache.get(url);
      expect(cached!.body, body);
      expect(cached.fetchedAt, now);
      expect(cached.url, url);
    });

    test('is keyed by the exact URL', () async {
      final cache = ResponseCache(FileKeyValueStore(dir));
      await cache.put(
        VpicEndpoints.models(makeId: 474, year: 2015),
        fixtures.body('models_honda_2015'),
        now,
      );
      expect(
        await cache.get(VpicEndpoints.models(makeId: 474, year: 2016)),
        isNull,
      );
    });
  });

  group('VpicRepository caching', () {
    test('first call downloads, second call is served from the device',
        () async {
      final repository = newRepository();

      final first = await repository.models(makeId: 474, year: 2015);
      expect(first.origin, DataOrigin.network);
      expect(first.url, fixtures.url('models_honda_2015'));
      expect(first.fetchedAt, now);
      expect(network.requests, <Uri>[fixtures.url('models_honda_2015')]);

      final second = await repository.models(makeId: 474, year: 2015);
      expect(second.origin, DataOrigin.cache);
      expect(second.fetchedAt, now);
      expect(network.requests.length, 1, reason: 'no second download');
      expect(rawJson(second), rawJson(first));
      expect(
        rawJson(second),
        jsonEncode(fixtures.results('models_honda_2015')),
      );
    });

    test('the saved file holds the exact response body', () async {
      await newRepository().allMakes();
      final cached = await ResponseCache(FileKeyValueStore(dir))
          .get(fixtures.url('all_makes'));
      expect(cached!.body, fixtures.body('all_makes'));
    });

    test('offline after an app restart: every saved query still works',
        () async {
      // Online session.
      final online = newRepository();
      final makes = await online.allMakes();
      final types = await online.vehicleTypesForMake(474);
      final models = await online.models(makeId: 474, year: 2015);
      final specs = await online.canadianSpecs(
        year: 2015,
        make: 'HONDA',
        model: 'Accord',
      );
      final vin = await online.decodeVin('5UXWX7C5*BA', modelYear: 2011);
      final requestsWhileOnline = network.requests.length;
      expect(requestsWhileOnline, 5);

      // Connection lost, app restarted (new objects, same directory).
      network.online = false;
      final offline = newRepository();
      final makes2 = await offline.allMakes();
      final types2 = await offline.vehicleTypesForMake(474);
      final models2 = await offline.models(makeId: 474, year: 2015);
      final specs2 = await offline.canadianSpecs(
        year: 2015,
        make: 'HONDA',
        model: 'Accord',
      );
      final vin2 = await offline.decodeVin('5UXWX7C5*BA', modelYear: 2011);

      for (final sourced in <Sourced<VpicResponse>>[
        makes2,
        types2,
        models2,
        specs2,
        vin2,
      ]) {
        expect(sourced.origin, DataOrigin.cache);
        expect(sourced.fetchedAt, now);
      }
      expect(rawJson(makes2), rawJson(makes));
      expect(rawJson(types2), rawJson(types));
      expect(rawJson(models2), rawJson(models));
      expect(rawJson(specs2), rawJson(specs));
      expect(rawJson(vin2), rawJson(vin));
      expect(makes2.data.results.length, makes.data.results.length);
      expect(network.requests.length, requestsWhileOnline,
          reason: 'fresh saved copies are used without touching the network');
    });

    test('offline with nothing saved: fails as "offline", invents nothing',
        () async {
      network.online = false;
      await expectLater(
        newRepository().models(makeId: 474, year: 2015),
        throwsA(
          isA<VpicException>()
              .having((e) => e.kind, 'kind', VpicErrorKind.offline)
              .having((e) => e.url, 'url', fixtures.url('models_honda_2015')),
        ),
      );
      expect(Directory(dir.path).listSync(), isEmpty);
    });

    test('a saved copy older than maxAge is refreshed when online', () async {
      final repository = newRepository();
      await repository.models(makeId: 474, year: 2015);
      final firstFetch = now;

      now = now.add(const Duration(days: 8));
      final refreshed = await repository.models(makeId: 474, year: 2015);
      expect(refreshed.origin, DataOrigin.network);
      expect(refreshed.fetchedAt, now);
      expect(refreshed.fetchedAt, isNot(firstFetch));
      expect(network.requests.length, 2);
    });

    test('an old saved copy is still shown offline, flagged as stale',
        () async {
      final repository = newRepository();
      final first = await repository.models(makeId: 474, year: 2015);
      final firstFetch = now;

      now = now.add(const Duration(days: 30));
      network.online = false;
      final stale = await repository.models(makeId: 474, year: 2015);
      expect(stale.origin, DataOrigin.staleCache);
      expect(stale.fetchedAt, firstFetch, reason: 'the real download time');
      expect(rawJson(stale), rawJson(first));
    });

    test('forceRefresh downloads again even when the copy is fresh', () async {
      final repository = newRepository();
      await repository.models(makeId: 474, year: 2015);
      now = now.add(const Duration(minutes: 5));
      final refreshed = await repository.models(
        makeId: 474,
        year: 2015,
        forceRefresh: true,
      );
      expect(refreshed.origin, DataOrigin.network);
      expect(refreshed.fetchedAt, now);
      expect(network.requests.length, 2);
    });

    test('forceRefresh while offline keeps the saved copy', () async {
      final repository = newRepository();
      final first = await repository.models(makeId: 474, year: 2015);
      network.online = false;
      final kept = await repository.models(
        makeId: 474,
        year: 2015,
        forceRefresh: true,
      );
      expect(kept.origin, DataOrigin.staleCache);
      expect(rawJson(kept), rawJson(first));
    });

    test('a server error is reported and never cached', () async {
      network.override = (_) => http.Response('Service Unavailable', 503);
      final repository = newRepository();
      await expectLater(
        repository.models(makeId: 474, year: 2015),
        throwsA(
          isA<VpicException>()
              .having((e) => e.kind, 'kind', VpicErrorKind.http)
              .having((e) => e.detail, 'detail', 'HTTP 503'),
        ),
      );
      expect(Directory(dir.path).listSync(), isEmpty);
    });

    test('a server error falls back to the saved copy when there is one',
        () async {
      final repository = newRepository();
      final first = await repository.models(makeId: 474, year: 2015);
      network.override = (_) => http.Response('Service Unavailable', 503);
      now = now.add(const Duration(days: 8));
      final fallback = await repository.models(makeId: 474, year: 2015);
      expect(fallback.origin, DataOrigin.staleCache);
      expect(rawJson(fallback), rawJson(first));
    });

    test('an unreadable 200 response is rejected and never cached', () async {
      network.override = (_) => http.Response('<html>maintenance</html>', 200);
      final repository = newRepository();
      await expectLater(
        repository.allMakes(),
        throwsA(
          isA<VpicException>()
              .having((e) => e.kind, 'kind', VpicErrorKind.badResponse),
        ),
      );
      expect(Directory(dir.path).listSync(), isEmpty);
    });

    test('a damaged cache file is ignored and downloaded again', () async {
      final repository = newRepository();
      await repository.models(makeId: 474, year: 2015);
      final store = FileKeyValueStore(dir);
      final key = ResponseCache.keyFor(fixtures.url('models_honda_2015'));
      await store.fileFor(key).writeAsString('garbage');

      final again = await repository.models(makeId: 474, year: 2015);
      expect(again.origin, DataOrigin.network);
      expect(network.requests.length, 2);
    });

    test('UTF-8 names are decoded correctly without a charset header',
        () async {
      // Names with non-ASCII characters, taken from the recorded data itself.
      final nonAscii = <String>[
        for (final r in fixtures.results('all_makes'))
          if (((r as Map<String, dynamic>)['Make_Name'] as String)
              .runes
              .any((c) => c > 127))
            r['Make_Name'] as String,
      ];
      expect(nonAscii, isNotEmpty);

      final makes = await newRepository().allMakes();
      final names = <String?>{
        for (final r in makes.data.results) r.string(VpicFields.makeName),
      };
      expect(names, containsAll(nonAscii));
    });
  });

  group('SavedVehiclesStore', () {
    test('keeps the decoded record and its citation exactly', () async {
      final repository = newRepository();
      final decoded = await repository.decodeVin(
        '5UXWX7C5*BA',
        modelYear: 2011,
      );
      final record = decoded.data.results.single;

      final saved = await SavedVehiclesStore(FileKeyValueStore(dir)).add(
        SavedVehicle(
          url: decoded.url,
          fetchedAt: decoded.fetchedAt,
          record: record,
        ),
      );
      expect(saved.length, 1);

      // "Restart": a new store object on the same directory.
      final loaded = await SavedVehiclesStore(FileKeyValueStore(dir)).load();
      expect(loaded.length, 1);
      expect(loaded.single.url, fixtures.url('decode_vin_5uxwx7c5_ba_2011'));
      expect(loaded.single.fetchedAt, now);
      expect(
        jsonEncode(loaded.single.record.raw),
        jsonEncode(fixtures.results('decode_vin_5uxwx7c5_ba_2011').single),
      );
    });

    test('saving the same request twice keeps one entry; remove deletes it',
        () async {
      final store = SavedVehiclesStore(FileKeyValueStore(dir));
      final decoded = await newRepository().decodeVin(
        '5UXWX7C5*BA',
        modelYear: 2011,
      );
      final vehicle = SavedVehicle(
        url: decoded.url,
        fetchedAt: decoded.fetchedAt,
        record: decoded.data.results.single,
      );
      await store.add(vehicle);
      expect((await store.add(vehicle)).length, 1);
      expect(await store.remove(decoded.url), isEmpty);
      expect(await store.load(), isEmpty);
    });

    test('unreadable saved data loads as an empty list', () async {
      final files = FileKeyValueStore(dir);
      await files.write(SavedVehiclesStore.storageKey, 'not json');
      expect(await SavedVehiclesStore(files).load(), isEmpty);
    });
  });
}
