import 'package:car_repair_app/src/ui/common.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('make search: typing "honda" narrows the real GetAllMakes list',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);

    await tester.tap(find.byKey(const Key('make-field')));
    await tester.pumpAndSettle();

    final total = app.fixtures.results('all_makes').length;
    expect(find.text('Results: $total'), findsOneWidget);
    expect(find.text(app.fixtures.url('all_makes').toString()), findsOneWidget);

    await tester.enterText(find.byKey(const Key('make-search')), 'honda');
    await tester.pumpAndSettle();

    final expected = <String>[
      for (final r in app.fixtures.results('all_makes'))
        if (((r as Map<String, dynamic>)['Make_Name'] as String)
            .toLowerCase()
            .contains('honda'))
          r['Make_Name'] as String,
    ];
    expect(find.text('Showing ${expected.length} of $total'), findsOneWidget);
    for (final name in expected) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Make_ID: 474'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('make-search')), 'zzzzqq');
    await tester.pumpAndSettle();
    expect(find.text('Showing 0 of $total'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('No returned record matches this text.'), findsOneWidget);
  });

  testWidgets('search by make + year lists the models exactly as returned',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');

    final expected = app.fixtures.results('models_honda_2015');
    expect(find.text('Results: ${expected.length}'), findsOneWidget);
    expect(find.text('Accord'), findsOneWidget);
    expect(find.text('Civic'), findsOneWidget);
    expect(find.text('CR-V'), findsOneWidget);

    // Citation: source name, exact request URL, live origin.
    final url = app.fixtures.url('models_honda_2015');
    expect(find.text(url.toString()), findsOneWidget);
    expect(find.text('Source: NHTSA vPIC API (official)'), findsWidgets);
    expect(find.textContaining('live from the source'), findsWidgets);
    expect(app.network.requests, contains(url));
  });

  testWidgets('model-name filter narrows the returned records', (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');
    final total = app.fixtures.results('models_honda_2015').length;

    await tester.enterText(find.byKey(const Key('model-filter')), 'civ');
    await tester.pumpAndSettle();
    expect(find.text('Showing 1 of $total'), findsOneWidget);
    expect(find.text('Civic'), findsOneWidget);
    expect(find.text('Accord'), findsNothing);

    await tester.enterText(find.byKey(const Key('model-filter')), 'qqqq');
    await tester.pumpAndSettle();
    expect(find.text('Showing 0 of $total'), findsOneWidget);
    expect(find.byKey(const Key('no-results')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('model-filter')), '');
    await tester.pumpAndSettle();
    expect(find.text('Results: $total'), findsOneWidget);
    expect(find.text('Accord'), findsOneWidget);
  });

  testWidgets('vehicle-type filter options come from the source and filter',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);

    // Options are exactly the VehicleTypeName values vPIC returned.
    for (final type in app.fixtures.results('vehicle_types_honda')) {
      final name = (type as Map<String, dynamic>)['VehicleTypeName'] as String;
      expect(find.byKey(ValueKey<String>('vehicle-type-$name')), findsOneWidget);
    }
    expect(
      find.text(app.fixtures.url('vehicle_types_honda').toString()),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('vehicle-type-Passenger Car')),
    );
    await tester.pumpAndSettle();
    await app.search(tester, year: '2015');

    final expected =
        app.fixtures.results('models_honda_2015_passenger_car');
    expect(find.text('Results: ${expected.length}'), findsOneWidget);
    expect(
      find.text('HONDA | Passenger Car'),
      findsNWidgets(expected.length),
    );
    expect(
      app.network.requests.last,
      app.fixtures.url('models_honda_2015_passenger_car'),
    );
  });

  testWidgets('search without a year uses GetModelsForMakeId', (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester);

    final expected = app.fixtures.results('models_honda');
    expect(find.text('Results: ${expected.length}'), findsOneWidget);
    expect(app.network.requests.last, app.fixtures.url('models_honda'));
  });

  testWidgets('a year the source has nothing for shows "Not available"',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '1950');

    expect(find.text('Results: 0'), findsOneWidget);
    final notice = find.byKey(const Key('no-results'));
    expect(notice, findsOneWidget);
    expect(
      find.descendant(of: notice, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: notice,
        matching: find.text('The source returned no results for this query.'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(app.fixtures.url('models_honda_1950').toString()),
      findsOneWidget,
    );
  });

  testWidgets('an invalid year is rejected before any request', (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    final before = app.network.requests.length;

    await app.search(tester, year: '20');
    expect(find.text('Enter a 4-digit year'), findsOneWidget);
    expect(app.network.requests.length, before);
    expect(find.byKey(const Key('results-count')), findsNothing);
  });

  testWidgets('a year typed with Arabic-Indic digits is understood',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '٢٠١٥');

    expect(app.network.requests.last, app.fixtures.url('models_honda_2015'));
    expect(find.text('Accord'), findsOneWidget);
  });

  testWidgets('search is disabled until a make is selected', (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    final before = app.network.requests.length;

    expect(find.text('Select a make first'), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-button')));
    await tester.pumpAndSettle();
    expect(app.network.requests.length, before);
    expect(find.byKey(const Key('results-count')), findsNothing);
  });

  testWidgets('engine-type filter states "Not available" and why',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);

    final card = find.byKey(const Key('engine-filter'));
    expect(
      find.descendant(of: card, matching: find.text('Engine type')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('does not return engine data'),
      ),
      findsOneWidget,
    );

    // The link leads to the VIN tab, where the source does return engine data.
    await tester.tap(find.byKey(const Key('open-vin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vin-field')), findsOneWidget);
  });

  testWidgets('a source error shows "Not available", the URL and Retry',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    // 1990 was not recorded: the fake network answers 404 for it.
    await app.search(tester, year: '1990');

    final error = find.byKey(const ValueKey<String>('error-http'));
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: error, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(find.textContaining('HTTP 404'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const Key('results-count')), findsNothing);
  });

  testWidgets('source text is laid out left-to-right', (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');

    final text = tester.widget<Text>(
      find.descendant(
        of: find.widgetWithText(SourceText, 'Accord'),
        matching: find.byType(Text),
      ),
    );
    expect(text.data, 'Accord');
    expect(text.textDirection, TextDirection.ltr);
  });
}
