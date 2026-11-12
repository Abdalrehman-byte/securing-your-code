import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('detail shows the model record and Canadian specs as returned',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');

    await tester.tap(find.text('Accord'));
    await tester.pumpAndSettle();

    // The model record: every field name and value the source returned.
    final record = (app.fixtures.results('models_honda_2015').first
        as Map<String, dynamic>);
    expect(record['Model_Name'], 'Accord');
    expect(find.text('Record exactly as returned by the source'), findsOneWidget);
    for (final entry in record.entries) {
      expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      expect(find.text('${entry.value}'), findsWidgets, reason: entry.key);
    }
    expect(find.byKey(const Key('query-year')), findsOneWidget);
    expect(find.text('2015'), findsOneWidget);

    // Canadian Vehicle Specifications: every entry, name and value.
    final specsUrl = app.fixtures.url('canadian_specs_2015_honda_accord');
    expect(app.network.requests.last, specsUrl);
    expect(find.text(specsUrl.toString()), findsOneWidget);

    final entries = app.fixtures.results('canadian_specs_2015_honda_accord');
    expect(entries, isNotEmpty);
    final section = find.byKey(const Key('canadian-specs'));
    expect(
      find.descendant(
        of: section,
        matching: find.text('Results: ${entries.length}'),
      ),
      findsOneWidget,
    );
    final criteria = app.fixtures.json('canadian_specs_2015_honda_accord')
        ['SearchCriteria'] as String;
    expect(find.text(criteria), findsOneWidget);

    final expectedNames = <String, int>{};
    final expectedValues = <String, int>{};
    for (final entry in entries) {
      final specs = (entry as Map<String, dynamic>)['Specs'] as List<dynamic>;
      for (final spec in specs) {
        final name = (spec as Map<String, dynamic>)['Name'] as String;
        final value = spec['Value'] as String;
        expectedNames[name] = (expectedNames[name] ?? 0) + 1;
        expectedValues[value] = (expectedValues[value] ?? 0) + 1;
      }
    }
    for (final name in expectedNames.keys) {
      expect(
        find.descendant(of: section, matching: find.text(name)),
        findsNWidgets(expectedNames[name]!),
        reason: 'spec name $name',
      );
    }
    for (final value in expectedValues.keys) {
      expect(
        find.descendant(of: section, matching: find.text(value)),
        findsAtLeastNWidgets(expectedValues[value]!),
        reason: 'spec value $value',
      );
    }
    for (var i = 1; i <= entries.length; i++) {
      expect(find.text('Entry $i'), findsOneWidget);
    }

    // Engine data is not returned for make/model/year.
    final engine = find.byKey(const Key('engine-specs'));
    expect(
      find.descendant(of: engine, matching: find.text('Not available')),
      findsOneWidget,
    );
  });

  testWidgets('specs the source does not have show "Not available"',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');

    expect(
      app.fixtures.results('canadian_specs_2015_honda_cb300f'),
      isEmpty,
      reason: 'the recorded response has no entries for this model',
    );
    await tester.tap(find.text('CB300F'));
    await tester.pumpAndSettle();

    final section = find.byKey(const Key('canadian-specs'));
    expect(
      find.descendant(of: section, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: section,
        matching: find.text('The source returned no results for this query.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('specs-count')), findsNothing);
    expect(find.text('Entry 1'), findsNothing);
    expect(
      find.text(
        app.fixtures.url('canadian_specs_2015_honda_cb300f').toString(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a year, specs are "Not available" and nothing is asked',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester);
    final requests = app.network.requests.length;

    await tester.tap(find.text('Accord'));
    await tester.pumpAndSettle();

    expect(find.text('Any year'), findsOneWidget);
    final section = find.byKey(const Key('canadian-specs'));
    expect(
      find.descendant(of: section, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(
      find.text('A model year is required to query these specifications.'),
      findsOneWidget,
    );
    expect(app.network.requests.length, requests);
  });

  testWidgets('offline: a detail page opened before is still complete',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');
    await tester.tap(find.text('Accord'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    app.network.online = false;
    await tester.tap(find.text('Accord'));
    await tester.pumpAndSettle();

    final entries = app.fixtures.results('canadian_specs_2015_honda_accord');
    final section = find.byKey(const Key('canadian-specs'));
    expect(
      find.descendant(
        of: section,
        matching: find.text('Results: ${entries.length}'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: section,
        matching: find.textContaining('saved copy on this device'),
      ),
      findsOneWidget,
    );
  });
}
