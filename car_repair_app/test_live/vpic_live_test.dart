// Live tests: these call the real NHTSA vPIC API over the network.
//
//   flutter test test_live
//
// They are kept outside `test/` so that the normal `flutter test` run stays
// offline and deterministic.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:car_repair_app/src/data/key_value_store.dart';
import 'package:car_repair_app/src/data/response_cache.dart';
import 'package:car_repair_app/src/data/search.dart';
import 'package:car_repair_app/src/data/vpic_endpoints.dart';
import 'package:car_repair_app/src/data/vpic_models.dart';
import 'package:car_repair_app/src/data/vpic_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory dir;
  late http.Client liveClient;
  var offlineAttempts = 0;

  final http.Client noNetwork = MockClient((request) async {
    offlineAttempts++;
    throw const SocketException('Network disabled for this test');
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('car_repair_live_');
    liveClient = http.Client();
    offlineAttempts = 0;
  });

  tearDown(() async {
    liveClient.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  VpicRepository online() => VpicRepository(
        client: liveClient,
        cache: ResponseCache(FileKeyValueStore(dir)),
      );

  VpicRepository offline() => VpicRepository(
        client: noNetwork,
        cache: ResponseCache(FileKeyValueStore(dir)),
      );

  List<String?> names(List<VpicRecord> records, String field) {
    return <String?>[for (final r in records) r.string(field)];
  }

  String rawJson(Sourced<VpicResponse> sourced) {
    return jsonEncode(<Object?>[for (final r in sourced.data.results) r.raw]);
  }

  Future<int> hondaId(VpicRepository repository) async {
    final makes = await repository.allMakes();
    final honda = makes.data.results.singleWhere(
      (r) => r.string(VpicFields.makeName) == 'HONDA',
    );
    return honda.integer(VpicFields.makeId)!;
  }

  test('LIVE makes: GetAllMakes downloads and "honda" is found by search',
      () async {
    final stopwatch = Stopwatch()..start();
    final makes = await online().allMakes();
    stopwatch.stop();

    expect(makes.origin, DataOrigin.network);
    expect(makes.url, VpicEndpoints.allMakes());
    expect(makes.data.results, isNotEmpty);
    expect(makes.data.count, makes.data.results.length);

    final searchWatch = Stopwatch()..start();
    final hits = searchRecords(makes.data.results, VpicFields.makeName, 'honda');
    searchWatch.stop();
    expect(hits, isNotEmpty);
    expect(hits.first.string(VpicFields.makeName), 'HONDA');
    expect(hits.first.integer(VpicFields.makeId), isNotNull);

    print('[live] ${makes.url}');
    print(
      '[live] makes returned: ${makes.data.results.length} '
      '(Count=${makes.data.count}) in ${stopwatch.elapsedMilliseconds} ms',
    );
    print(
      '[live] search "honda" -> ${names(hits, VpicFields.makeName)} '
      '(Make_ID ${hits.first.integer(VpicFields.makeId)}) '
      'in ${searchWatch.elapsedMicroseconds / 1000} ms',
    );
  });

  test('LIVE models: make + year filter, then model-name search', () async {
    final repository = online();
    final makeId = await hondaId(repository);
    final models = await repository.models(makeId: makeId, year: 2015);

    expect(models.origin, DataOrigin.network);
    expect(models.data.count, models.data.results.length);
    final modelNames = names(models.data.results, VpicFields.modelName);
    expect(modelNames, containsAll(<String>['Accord', 'Civic', 'CR-V']));
    for (final record in models.data.results) {
      expect(record.integer(VpicFields.makeId), makeId);
      expect(record.string(VpicFields.makeName), 'HONDA');
    }

    final civ = searchRecords(models.data.results, VpicFields.modelName, 'civ');
    expect(names(civ, VpicFields.modelName), <String>['Civic']);

    print('[live] ${models.url}');
    print(
      '[live] HONDA 2015 models returned: ${models.data.results.length}; '
      'search "civ" -> ${names(civ, VpicFields.modelName)}',
    );
  });

  test('LIVE models without a year: GetModelsForMakeId', () async {
    final repository = online();
    final makeId = await hondaId(repository);
    final all = await repository.models(makeId: makeId);
    final year = await repository.models(makeId: makeId, year: 2015);

    expect(all.data.results.length, greaterThan(year.data.results.length));
    expect(
      names(all.data.results, VpicFields.modelName),
      containsAll(names(year.data.results, VpicFields.modelName)),
    );
    print('[live] ${all.url}');
    print('[live] HONDA models (all years) returned: ${all.data.results.length}');
  });

  test('LIVE vehicle-type filter: every type vPIC lists for the make works',
      () async {
    final repository = online();
    final makeId = await hondaId(repository);
    final types = await repository.vehicleTypesForMake(makeId);
    final typeNames = names(types.data.results, VpicFields.vehicleTypeName);
    expect(typeNames, isNotEmpty);
    print('[live] ${types.url}');
    print('[live] vehicle types for HONDA: $typeNames');

    final unfiltered = await repository.models(makeId: makeId, year: 2015);
    var matched = 0;
    for (final type in typeNames) {
      final filtered = await repository.models(
        makeId: makeId,
        year: 2015,
        vehicleType: type,
      );
      for (final record in filtered.data.results) {
        expect(record.string(VpicFields.vehicleTypeName), type);
      }
      expect(
        names(unfiltered.data.results, VpicFields.modelName),
        containsAll(names(filtered.data.results, VpicFields.modelName)),
      );
      matched += filtered.data.results.length;
      print(
        '[live] HONDA 2015, vehicleType "$type": '
        '${filtered.data.results.length} models',
      );
    }
    expect(matched, greaterThan(0));
  });

  test('LIVE year with no data: empty result, nothing invented', () async {
    final repository = online();
    final makeId = await hondaId(repository);
    final models = await repository.models(makeId: makeId, year: 1950);
    expect(models.data.count, 0);
    expect(models.data.results, isEmpty);
    print('[live] ${models.url} -> ${models.data.results.length} results');
  });

  test('LIVE specs: Canadian Vehicle Specifications for 2015 HONDA Accord',
      () async {
    final specs = await online().canadianSpecs(
      year: 2015,
      make: 'HONDA',
      model: 'Accord',
    );
    expect(specs.data.results, isNotEmpty);
    for (final entry in specs.data.results) {
      final fields = canadianSpecFields(entry);
      final byName = <String, Object?>{
        for (final field in fields) field.key: field.value,
      };
      expect(byName['Make'], 'HONDA');
      expect('${byName['Model']}', contains('ACCORD'));
    }
    print('[live] ${specs.url}');
    print(
      '[live] entries: ${specs.data.results.length}; first entry: '
      '${canadianSpecFields(specs.data.results.first).map((f) => '${f.key}=${f.value}').join(', ')}',
    );
  });

  test('LIVE VIN decode (vPIC documentation example 5UXWX7C5*BA, 2011)',
      () async {
    final decoded = await online().decodeVin('5UXWX7C5*BA', modelYear: 2011);
    final record = decoded.data.results.single;
    expect(record.string('Make'), 'BMW');
    expect(record.string('ModelYear'), '2011');
    expect(record.raw.containsKey(VpicFields.fuelTypePrimary), isTrue);
    print('[live] ${decoded.url}');
    print(
      '[live] Make=${record.string('Make')}, Model=${record.string('Model')}, '
      'ModelYear=${record.string('ModelYear')}, '
      'FuelTypePrimary=${record.string('FuelTypePrimary')}, '
      'EngineCylinders=${record.string('EngineCylinders')}, '
      'DisplacementL=${record.string('DisplacementL')}, '
      'ErrorText=${record.string('ErrorText')}',
    );
  });

  test('LIVE caching: second read comes from the device, not the network',
      () async {
    final repository = online();
    final first = await repository.allMakes();
    final stopwatch = Stopwatch()..start();
    final second = await repository.allMakes();
    stopwatch.stop();

    expect(first.origin, DataOrigin.network);
    expect(second.origin, DataOrigin.cache);
    expect(second.fetchedAt.toUtc(), first.fetchedAt.toUtc());
    expect(rawJson(second), rawJson(first));

    final files = dir.listSync().whereType<File>().toList();
    final bytes = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(files.length, 1);
    print(
      '[live] cached read of ${second.data.results.length} makes from disk in '
      '${stopwatch.elapsedMilliseconds} ms; cache = ${files.length} file, '
      '$bytes bytes',
    );
  });

  test('LIVE offline: data downloaded from vPIC is fully usable with no network',
      () async {
    // 1) Online session against the real API.
    final live = online();
    final makeId = await hondaId(live);
    final makes = await live.allMakes();
    final types = await live.vehicleTypesForMake(makeId);
    final models = await live.models(makeId: makeId, year: 2015);
    final specs = await live.canadianSpecs(
      year: 2015,
      make: 'HONDA',
      model: 'Accord',
    );
    final vin = await live.decodeVin('5UXWX7C5*BA', modelYear: 2011);

    // 2) "Restart" with the network cut: new objects, same directory.
    final cut = offline();
    final makes2 = await cut.allMakes();
    final types2 = await cut.vehicleTypesForMake(makeId);
    final models2 = await cut.models(makeId: makeId, year: 2015);
    final specs2 = await cut.canadianSpecs(
      year: 2015,
      make: 'HONDA',
      model: 'Accord',
    );
    final vin2 = await cut.decodeVin('5UXWX7C5*BA', modelYear: 2011);

    final pairs = <(Sourced<VpicResponse>, Sourced<VpicResponse>)>[
      (makes, makes2),
      (types, types2),
      (models, models2),
      (specs, specs2),
      (vin, vin2),
    ];
    for (final (before, after) in pairs) {
      expect(after.origin, DataOrigin.cache, reason: '${after.url}');
      expect(after.url, before.url);
      expect(rawJson(after), rawJson(before), reason: '${after.url}');
      print(
        '[live] offline OK (${after.data.results.length} records identical): '
        '${after.url}',
      );
    }
    expect(offlineAttempts, 0, reason: 'saved copies need no network at all');

    // Search still works on the offline copy.
    final hits = searchRecords(makes2.data.results, VpicFields.makeName, 'honda');
    expect(hits.first.string(VpicFields.makeName), 'HONDA');
    final civ = searchRecords(models2.data.results, VpicFields.modelName, 'civ');
    expect(names(civ, VpicFields.modelName), <String>['Civic']);

    // 3) A query that was never downloaded is reported as unavailable.
    await expectLater(
      cut.models(makeId: makeId, year: 2016),
      throwsA(
        isA<VpicException>()
            .having((e) => e.kind, 'kind', VpicErrorKind.offline),
      ),
    );
    expect(offlineAttempts, 1);
    print('[live] offline, never-downloaded query -> VpicErrorKind.offline');
  });

  test('LIVE refresh: forceRefresh downloads a new copy from vPIC', () async {
    final repository = online();
    final makeId = await hondaId(repository);
    final first = await repository.models(makeId: makeId, year: 2015);
    final cached = await repository.models(makeId: makeId, year: 2015);
    final refreshed = await repository.models(
      makeId: makeId,
      year: 2015,
      forceRefresh: true,
    );
    expect(first.origin, DataOrigin.network);
    expect(cached.origin, DataOrigin.cache);
    expect(refreshed.origin, DataOrigin.network);
    expect(refreshed.fetchedAt.isAfter(first.fetchedAt), isTrue);
    expect(rawJson(refreshed), rawJson(first));
  });
}
