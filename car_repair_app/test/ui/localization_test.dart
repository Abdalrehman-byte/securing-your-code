import 'package:car_repair_app/src/app_services.dart';
import 'package:car_repair_app/src/ui/database_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('Arabic: right-to-left layout and Arabic labels', (tester) async {
    final app = AppHarness();
    await app.pump(tester, locale: const Locale('ar'));

    final context = tester.element(find.byType(DatabaseScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context), const Locale('ar'));

    expect(find.text('إصلاح السيارات'), findsOneWidget);
    expect(find.text('قاعدة بيانات السيارات'), findsWidgets);
    expect(find.text('الشركة المصنّعة'), findsOneWidget);
    expect(find.text('سنة الطراز'), findsOneWidget);
    expect(find.text('نوع المركبة'), findsOneWidget);
    expect(find.text('نوع المحرك'), findsOneWidget);
    expect(find.text('بحث'), findsOneWidget);
    expect(find.text('غير متوفر'), findsOneWidget);
    expect(find.text('Not available'), findsNothing);
    expect(find.text('Make'), findsNothing);
  });

  testWidgets('Arabic: source data is shown unchanged, never translated',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester, locale: const Locale('ar'));
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');

    final total = app.fixtures.results('models_honda_2015').length;
    expect(find.text('النتائج: $total'), findsOneWidget);
    expect(find.text('Accord'), findsOneWidget);
    expect(find.text('Civic'), findsOneWidget);
    expect(
      find.text(app.fixtures.url('models_honda_2015').toString()),
      findsOneWidget,
    );
    expect(find.textContaining('مباشرة من المصدر'), findsWidgets);

    final accord = tester.widget<Text>(find.text('Accord'));
    expect(accord.textDirection, TextDirection.ltr);

    await app.search(tester, year: '1950');
    final notice = find.byKey(const Key('no-results'));
    expect(
      find.descendant(of: notice, matching: find.text('غير متوفر')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: notice,
        matching: find.text('لم يُرجِع المصدر أي نتائج لهذا الاستعلام.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('English: left-to-right layout and English labels',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);

    final context = tester.element(find.byType(DatabaseScreen));
    expect(Directionality.of(context), TextDirection.ltr);
    expect(find.text('Car Repair'), findsOneWidget);
    expect(find.text('Car database'), findsWidgets);
    expect(find.text('Make'), findsOneWidget);
    expect(find.text('Model year'), findsOneWidget);
    expect(find.text('Engine type'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
  });

  testWidgets('the language switch changes the UI and is remembered',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    expect(find.text('Car database'), findsWidgets);

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('قاعدة بيانات السيارات'), findsWidgets);
    expect(find.text('Car database'), findsNothing);
    expect(await app.store.read(localeSettingKey), 'ar');

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Car database'), findsWidgets);
    expect(await app.store.read(localeSettingKey), 'en');
  });

  testWidgets('switching language keeps the current results', (tester) async {
    final app = AppHarness();
    await app.pump(tester);
    await app.pickHonda(tester);
    await app.search(tester, year: '2015');
    final total = app.fixtures.results('models_honda_2015').length;
    expect(find.text('Results: $total'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('النتائج: $total'), findsOneWidget);
    expect(find.text('Accord'), findsOneWidget);
  });

  testWidgets('Arabic: the download time keeps its year-month-day order',
      (tester) async {
    final app = AppHarness();
    await app.pump(tester, locale: const Locale('ar'));
    await app.pickHonda(tester);

    final citation = tester.widget<Text>(
      find.byKey(const ValueKey<String>('origin-network')).first,
    );
    // U+2066 ... U+2069 isolate the timestamp as left-to-right text.
    expect(
      citation.data,
      matches(RegExp('\u2066\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}\u2069')),
    );
  });
}
