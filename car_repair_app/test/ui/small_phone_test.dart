import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show BackButton;

import '../support/app_harness.dart';

/// Walks through the whole feature on a small phone (360 x 640). Flutter
/// reports any overflowing layout as an error, which fails the test.
///
/// Every `enterText` is followed by a pump: a focused text field scrolls
/// itself back into view on the next frame, which would undo a scroll made
/// in the same frame.
void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
        'small phone 360x640 (${locale.languageCode}): the whole flow lays '
        'out without overflow', (tester) async {
      final app = AppHarness();
      await app.pump(tester, locale: locale, size: AppHarness.smallPhone);

      // Make picker.
      await tester.tap(find.byKey(const Key('make-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('make-search')), 'honda');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('make-474')));
      await tester.pumpAndSettle();

      // Filters and search.
      await tester.ensureVisible(find.byKey(const Key('year-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('year-field')), '2015');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('search-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('search-button')));
      await tester.pumpAndSettle();

      // Results list.
      await tester.dragUntilVisible(
        find.text('Accord'),
        find.byType(CustomScrollView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      final total = app.fixtures.results('models_honda_2015').length;
      expect(
        // The count sits just above the first result, scrolled out of view.
        tester
            .widget<Text>(
              find.byKey(const Key('results-count'), skipOffstage: false),
            )
            .data,
        contains('$total'),
      );

      // Detail page, scrolled to the end.
      await tester.tap(find.text('Accord'));
      await tester.pumpAndSettle();
      expect(find.text('Model_ID'), findsOneWidget);
      await tester.dragUntilVisible(
        find.byKey(const Key('engine-specs')),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('engine-specs')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // VIN tab: decode, list all fields, save, filter.
      await tester.tap(find.byKey(const Key('tab-vin')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('vin-field')), '5UXWX7C5*BA');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('vin-year-field')), '2011');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('decode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('decode-button')));
      await tester.pumpAndSettle();

      // On this screen the decoded record starts below the fold, so each
      // control is scrolled to before it is used.
      Future<void> scrollTo(Finder target) async {
        await tester.dragUntilVisible(
          target,
          find.byType(ListView),
          const Offset(0, -300),
          maxIteration: 200,
        );
        await tester.pumpAndSettle();
      }

      await scrollTo(find.byKey(const Key('show-empty-fields')));
      await tester.tap(find.byKey(const Key('show-empty-fields')));
      await tester.pumpAndSettle();

      await scrollTo(find.byKey(const Key('save-button')));
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      final chip = find.byKey(const ValueKey<String>('engine-Gasoline'));
      await scrollTo(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await scrollTo(find.text('BMW | X3 | 2011 | Gasoline'));
      expect(find.text('BMW | X3 | 2011 | Gasoline'), findsOneWidget);
    });
  }

  testWidgets('small phone 360x640: error and empty states lay out',
      (tester) async {
    final app = AppHarness();
    app.network.online = false;
    await app.pump(
      tester,
      locale: const Locale('ar'),
      size: AppHarness.smallPhone,
    );

    await tester.tap(find.byKey(const Key('make-field')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('error-offline')),
      findsOneWidget,
    );
    app.network.online = true;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('make-search')), 'honda');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('make-474')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('year-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('year-field')), '1950');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-button')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('no-results')),
      find.byType(CustomScrollView),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-results')), findsOneWidget);
  });
}
