import 'dart:convert';

import 'package:car_repair_app/src/data/vpic_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  final fixtures = Fixtures.load();

  group('VpicResponse.parse keeps the source data untouched', () {
    for (final name in fixtures.names) {
      test(name, () {
        final expected = fixtures.json(name);
        final parsed = VpicResponse.parse(fixtures.body(name));

        expect(parsed.count, expected['Count']);
        expect(parsed.message, expected['Message']);
        expect(parsed.searchCriteria, expected['SearchCriteria']);

        final expectedResults = expected['Results'] as List<dynamic>;
        expect(parsed.results.length, expectedResults.length);
        // Same records, same order, same keys in the same order, same values.
        expect(
          jsonEncode(<Object?>[for (final r in parsed.results) r.raw]),
          jsonEncode(expectedResults),
        );
      });
    }
  });

  test('GetAllMakes: Count equals the number of records; HONDA is Make_ID 474',
      () {
    final parsed = VpicResponse.parse(fixtures.body('all_makes'));
    expect(parsed.count, parsed.results.length);
    expect(parsed.results.length, greaterThan(10000));
    final honda = parsed.results.singleWhere(
      (r) => r.string(VpicFields.makeName) == 'HONDA',
    );
    expect(honda.integer(VpicFields.makeId), 474);
    expect(honda.raw.keys.toList(), <String>['Make_ID', 'Make_Name']);
  });

  test('model records expose exactly the fields the source returned', () {
    final byYear = VpicResponse.parse(fixtures.body('models_honda_2015'));
    expect(
      byYear.results.first.raw.keys.toList(),
      <String>['Make_ID', 'Make_Name', 'Model_ID', 'Model_Name'],
    );
    final byType = VpicResponse.parse(
      fixtures.body('models_honda_2015_passenger_car'),
    );
    expect(byType.results.first.raw.keys.toList(), <String>[
      'Make_ID',
      'Make_Name',
      'Model_ID',
      'Model_Name',
      'VehicleTypeId',
      'VehicleTypeName',
    ]);
    final fields = byYear.results.first.fields;
    expect(
      fields.map((f) => f.key).toList(),
      byYear.results.first.raw.keys.toList(),
    );
  });

  test('a year the source has no data for parses to an empty result', () {
    final parsed = VpicResponse.parse(fixtures.body('models_honda_1950'));
    expect(parsed.count, 0);
    expect(parsed.results, isEmpty);
  });

  test('Canadian specifications: Name/Value pairs in the source order', () {
    final parsed = VpicResponse.parse(
      fixtures.body('canadian_specs_2015_honda_accord'),
    );
    final expected = fixtures.results('canadian_specs_2015_honda_accord');
    expect(parsed.results, isNotEmpty);
    for (var i = 0; i < parsed.results.length; i++) {
      final specs = (expected[i] as Map<String, dynamic>)['Specs']
          as List<dynamic>;
      final fields = canadianSpecFields(parsed.results[i]);
      expect(fields.length, specs.length);
      for (var j = 0; j < specs.length; j++) {
        final spec = specs[j] as Map<String, dynamic>;
        expect(fields[j].key, spec['Name']);
        expect(fields[j].value, spec['Value']);
      }
    }
  });

  test('canadianSpecFields falls back to the raw fields for another shape',
      () {
    const record = VpicRecord(<String, dynamic>{'Unexpected': 'shape'});
    final fields = canadianSpecFields(record);
    expect(fields.single.key, 'Unexpected');
    expect(fields.single.value, 'shape');
  });

  test('VIN decode: empty strings mean "no data", values are not altered', () {
    final record = VpicResponse.parse(
      fixtures.body('decode_vin_5uxwx7c5_ba_2011'),
    ).results.single;
    final raw = fixtures.results('decode_vin_5uxwx7c5_ba_2011').single
        as Map<String, dynamic>;
    for (final entry in raw.entries) {
      final value = entry.value as String?;
      if (value == null || value.trim().isEmpty) {
        expect(record.string(entry.key), isNull, reason: entry.key);
      } else {
        expect(record.string(entry.key), value, reason: entry.key);
      }
    }
    expect(record.string(VpicFields.fuelTypePrimary), 'Gasoline');
    expect(record.string('EngineConfiguration'), isNull);
    expect(record.integer('ModelYear'), 2011);
  });

  test('vpicDisplayValue', () {
    expect(vpicDisplayValue(null), isNull);
    expect(vpicDisplayValue(''), isNull);
    expect(vpicDisplayValue('   '), isNull);
    expect(vpicDisplayValue('4 W '), '4 W ');
    expect(vpicDisplayValue(474), '474');
    expect(vpicDisplayValue(true), 'true');
    expect(vpicDisplayValue(<String, int>{'a': 1}), '{"a":1}');
  });

  test('bodies that are not a vPIC envelope are rejected, never guessed', () {
    expect(() => VpicResponse.parse('<html>'), throwsFormatException);
    expect(() => VpicResponse.parse('[]'), throwsFormatException);
    expect(() => VpicResponse.parse('{"Count":1}'), throwsFormatException);
    expect(
      () => VpicResponse.parse('{"Results":"none"}'),
      throwsFormatException,
    );
    expect(() => VpicResponse.parse('{"Results":[1]}'), throwsFormatException);
  });
}
