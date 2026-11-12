import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  const fixture = 'decode_vin_5uxwx7c5_ba_2011';

  Future<void> openVinTab(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tab-vin')));
    await tester.pumpAndSettle();
  }

  Future<void> decode(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('vin-field')), '5uxwx7c5*ba');
    await tester.enterText(find.byKey(const Key('vin-year-field')), '2011');
    await tester.tap(find.byKey(const Key('decode-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('decoding shows every returned field exactly, with citation',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await openVinTab(tester);
    await decode(tester);

    expect(app.network.requests.last, app.fixtures.url(fixture));
    expect(find.text(app.fixtures.url(fixture).toString()), findsOneWidget);

    // The source's own message is shown verbatim.
    final message = app.fixtures.json(fixture)['Message'] as String;
    expect(find.text(message), findsOneWidget);

    final record =
        app.fixtures.results(fixture).single as Map<String, dynamic>;
    final withData = <String, String>{
      for (final e in record.entries)
        if ((e.value as String).trim().isNotEmpty) e.key: e.value as String,
    };
    final withoutData = record.length - withData.length;
    expect(withData, isNotEmpty);
    expect(withoutData, greaterThan(0));

    for (final entry in withData.entries) {
      expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      expect(find.text(entry.value), findsWidgets, reason: entry.key);
    }
    expect(withData['FuelTypePrimary'], 'Gasoline');
    expect(withData['ErrorText'], '6 - Incomplete VIN');

    // Fields the source left empty are counted, hidden by default...
    expect(
      find.text('Fields with no data from the source: $withoutData'),
      findsOneWidget,
    );
    expect(find.text('EngineConfiguration'), findsNothing);
    expect(find.text('Not available'), findsNothing);

    // ...and listed as "Not available" on request.
    await tester.tap(find.byKey(const Key('show-empty-fields')));
    await tester.pumpAndSettle();
    expect(find.text('EngineConfiguration'), findsOneWidget);
    expect(find.text('Not available'), findsNWidgets(withoutData));
    for (final key in record.keys) {
      expect(find.text(key), findsOneWidget, reason: key);
    }
  });

  testWidgets('an invalid VIN or year is rejected before any request',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await openVinTab(tester);
    final before = app.network.requests.length;

    await tester.tap(find.byKey(const Key('decode-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a VIN using letters, digits or *'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('vin-field')), 'ABC/../DEF');
    await tester.tap(find.byKey(const Key('decode-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a VIN using letters, digits or *'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('vin-field')), '5UXWX7C5*BA');
    await tester.enterText(find.byKey(const Key('vin-year-field')), '11');
    await tester.tap(find.byKey(const Key('decode-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a 4-digit year'), findsOneWidget);

    expect(app.network.requests.length, before);
  });

  testWidgets('save, filter by engine type (FuelTypePrimary), remove',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await openVinTab(tester);
    expect(find.byKey(const Key('no-saved-vehicles')), findsOneWidget);

    await decode(tester);
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saved-indicator')), findsOneWidget);
    expect(find.byKey(const Key('no-saved-vehicles')), findsNothing);
    expect(
      find.text('Engine type (source field: FuelTypePrimary)'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('saved-count'))).data,
      'Results: 1',
    );
    // The filter option is the value returned by the source.
    final chip = find.byKey(const ValueKey<String>('engine-Gasoline'));
    expect(chip, findsOneWidget);
    expect(find.text('BMW | X3 | 2011 | Gasoline'), findsOneWidget);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('saved-count'))).data,
      'Showing 1 of 1',
    );

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-saved-vehicles')), findsOneWidget);
    expect(find.byKey(const Key('save-button')), findsOneWidget);
  });

  testWidgets('saved vehicles survive an app restart and work offline',
      (tester) async {
    final first = AppHarness();
    await first.pump(tester);
    await openVinTab(tester);
    await decode(tester);
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();

    final second = AppHarness(store: first.store);
    second.network.online = false;
    await second.pump(tester);
    await openVinTab(tester);

    expect(find.text('BMW | X3 | 2011 | Gasoline'), findsOneWidget);
    await tester.tap(find.text('BMW | X3 | 2011 | Gasoline'));
    await tester.pumpAndSettle();

    expect(find.text('FuelTypePrimary'), findsOneWidget);
    expect(find.text('Gasoline'), findsOneWidget);
    expect(
      find.text(second.fixtures.url(fixture).toString()),
      findsOneWidget,
    );
    expect(second.network.requests, isEmpty);
  });
}
