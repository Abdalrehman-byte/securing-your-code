import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('a repeated search is served from the saved copy', (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');
    expect(find.byKey(const ValueKey<String>('origin-network')), findsWidgets);
    final requests = app.network.requests.length;

    await app.search(tester);
    expect(app.network.requests.length, requests, reason: 'no new download');
    expect(find.textContaining('saved copy on this device'), findsOneWidget);
    expect(find.text('Accord'), findsOneWidget);
  });

  testWidgets('offline: saved searches work, new ones say "Not available"',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');
    final total = app.fixtures.results('models_honda_2015').length;

    app.network.online = false;

    // Saved query: still fully available.
    await app.search(tester);
    expect(find.text('Results: $total'), findsOneWidget);
    expect(find.text('Accord'), findsOneWidget);
    expect(find.textContaining('saved copy on this device'), findsOneWidget);

    // Query that was never downloaded: nothing is shown or invented.
    await app.search(tester, year: '2016');
    final error = find.byKey(const ValueKey<String>('error-offline'));
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: error, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Could not reach the source and there is no saved copy on this device.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('results-count')), findsNothing);
    expect(find.text('Accord'), findsNothing);
  });

  testWidgets('refresh while offline keeps the saved copy and says so',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');

    app.network.online = false;
    await tester.tap(find.byTooltip('Refresh from the source'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('offline, showing the saved copy'),
      findsOneWidget,
    );
    expect(find.text('Accord'), findsOneWidget);
  });

  testWidgets('cold start with no network: makes, types and models from cache',
      (tester) async {
    // Session 1 (online) fills the device storage.
    final first = AppHarness();
    await first.pump(tester);
    await first.pickHonda(tester);
    await first.search(tester, year: '2015');

    // Session 2: a new app instance on the same storage, network down.
    final second = AppHarness(store: first.store);
    second.network.online = false;
    await second.pump(tester);

    await tester.tap(find.byKey(const Key('make-field')));
    await tester.pumpAndSettle();
    final makes = second.fixtures.results('all_makes').length;
    expect(find.text('Results: $makes'), findsOneWidget);
    expect(find.textContaining('saved copy on this device'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('make-search')), 'honda');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('make-474')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('vehicle-type-Passenger Car')),
      findsOneWidget,
    );

    await second.search(tester, year: '2015');
    final models = second.fixtures.results('models_honda_2015').length;
    expect(find.text('Results: $models'), findsOneWidget);
    expect(find.text('Accord'), findsOneWidget);
    expect(find.text('Civic'), findsOneWidget);

    // The network was never reached in session 2.
    expect(second.network.requests, isEmpty);
  });

  testWidgets('cold start with no network and no cache: "Not available"',
      (tester) async {
    final app = AppHarness();
    app.network.online = false;
    await app.pump(tester);

    await tester.tap(find.byKey(const Key('make-field')));
    await tester.pumpAndSettle();
    final error = find.byKey(const ValueKey<String>('error-offline'));
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: error, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('make-count')), findsNothing);

    // Connectivity returns: Retry loads the real list.
    app.network.online = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    final makes = app.fixtures.results('all_makes').length;
    expect(find.text('Results: $makes'), findsOneWidget);
  });
}
