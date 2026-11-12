// ignore_for_file: avoid_print
import 'package:car_repair_app/src/data/search.dart';
import 'package:car_repair_app/src/data/vpic_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  final fixtures = Fixtures.load();
  final makes = VpicResponse.parse(fixtures.body('all_makes')).results;
  final models2015 =
      VpicResponse.parse(fixtures.body('models_honda_2015')).results;

  List<String?> names(List<VpicRecord> records, String field) {
    return <String?>[for (final r in records) r.string(field)];
  }

  group('make search over the full recorded GetAllMakes list', () {
    test('finds HONDA, prefix match first, case-insensitive', () {
      final stopwatch = Stopwatch()..start();
      final hits = searchRecords(makes, VpicFields.makeName, 'honda');
      stopwatch.stop();
      print(
        '[search] "honda" over ${makes.length} makes -> '
        '${names(hits, VpicFields.makeName)} '
        'in ${stopwatch.elapsedMicroseconds / 1000} ms',
      );
      // Expected list computed independently from the recorded data.
      final expected = <String>[
        for (final r in fixtures.results('all_makes'))
          if (((r as Map<String, dynamic>)['Make_Name'] as String)
              .toLowerCase()
              .contains('honda'))
            r['Make_Name'] as String,
      ];
      expect(expected, contains('HONDA'));
      expect(names(hits, VpicFields.makeName).toSet(), expected.toSet());
      expect(hits.first.string(VpicFields.makeName), 'HONDA');
      expect(hits.first.integer(VpicFields.makeId), 474);

      expect(
        names(searchRecords(makes, VpicFields.makeName, '  HoNdA '), 'Make_Name'),
        names(hits, 'Make_Name'),
      );
    });

    test('an empty query returns the source list unchanged', () {
      expect(identical(searchRecords(makes, VpicFields.makeName, ''), makes),
          isTrue);
      expect(identical(searchRecords(makes, VpicFields.makeName, '  '), makes),
          isTrue);
    });

    test('a query with no match returns nothing (no invented results)', () {
      expect(
        searchRecords(makes, VpicFields.makeName, 'zzzz-not-a-make-zzzz'),
        isEmpty,
      );
    });

    test('results are the original records, not copies or edits', () {
      final hits = searchRecords(makes, VpicFields.makeName, 'toyota');
      expect(hits, isNotEmpty);
      for (final hit in hits) {
        expect(makes.any((m) => identical(m, hit)), isTrue);
      }
    });
  });

  group('model search inside the recorded HONDA 2015 result', () {
    test('"civ" finds only Civic', () {
      expect(
        names(searchRecords(models2015, VpicFields.modelName, 'civ'),
            VpicFields.modelName),
        <String>['Civic'],
      );
    });

    test('matches keep the source order inside each group', () {
      final expected = <String>[
        for (final r in fixtures.results('models_honda_2015'))
          if (((r as Map<String, dynamic>)['Model_Name'] as String)
              .toLowerCase()
              .startsWith('cr'))
            r['Model_Name'] as String,
      ];
      expect(expected, containsAll(<String>['CR-V', 'CR-Z']));
      final hits = names(
        searchRecords(models2015, VpicFields.modelName, 'CR'),
        VpicFields.modelName,
      );
      expect(hits.take(expected.length).toList(), expected);
    });
  });

  group('year input', () {
    test('accepts 4 ASCII, Arabic-Indic or Eastern Arabic-Indic digits', () {
      expect(parseModelYear('2015'), 2015);
      expect(parseModelYear(' 2015 '), 2015);
      expect(parseModelYear('٢٠١٥'), 2015);
      expect(parseModelYear('۲۰۱۵'), 2015);
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('rejects anything else', () {
      expect(parseModelYear(''), isNull);
      expect(parseModelYear('15'), isNull);
      expect(parseModelYear('20155'), isNull);
      expect(parseModelYear('20a5'), isNull);
      expect(parseModelYear('-201'), isNull);
    });
  });

  group('VIN input', () {
    test('upper-cases and accepts letters, digits and *', () {
      expect(normalizeVin(' 5uxwx7c5*ba '), '5UXWX7C5*BA');
      expect(normalizeVin('1HGCM82633A004352'), '1HGCM82633A004352');
    });

    test('rejects empty, too long or unsafe input', () {
      expect(normalizeVin(''), isNull);
      expect(normalizeVin('1HGCM82633A0043521'), isNull);
      expect(normalizeVin('ABC/DEF'), isNull);
      expect(normalizeVin('ABC DEF'), isNull);
      expect(normalizeVin('ABC?x=1'), isNull);
    });
  });

  group('engine-type filter values (source field FuelTypePrimary)', () {
    final decoded = VpicResponse.parse(
      fixtures.body('decode_vin_5uxwx7c5_ba_2011'),
    ).results.single;
    const noData = VpicRecord(<String, dynamic>{'FuelTypePrimary': ''});

    test('distinct values come only from the records; null = no data', () {
      expect(
        distinctFieldValues(
          <VpicRecord>[decoded, noData, decoded],
          VpicFields.fuelTypePrimary,
        ),
        <String?>['Gasoline', null],
      );
    });

    test('filtering keeps exact matches only', () {
      final all = <VpicRecord>[decoded, noData];
      expect(
        filterByFieldValue<VpicRecord>(
          all,
          (r) => r,
          VpicFields.fuelTypePrimary,
          'Gasoline',
        ),
        <VpicRecord>[decoded],
      );
      expect(
        filterByFieldValue<VpicRecord>(
          all,
          (r) => r,
          VpicFields.fuelTypePrimary,
          null,
        ),
        <VpicRecord>[noData],
      );
      expect(
        filterByFieldValue<VpicRecord>(
          all,
          (r) => r,
          VpicFields.fuelTypePrimary,
          'Diesel',
        ),
        isEmpty,
      );
    });
  });
}
