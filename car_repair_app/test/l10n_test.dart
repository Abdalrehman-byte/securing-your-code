import 'package:car_repair_app/src/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizations.values['en']!;
  final ar = AppLocalizations.values['ar']!;
  final placeholder = RegExp(r'\{[a-z]+\}');

  test('Arabic and English define exactly the same strings', () {
    expect(ar.keys.toSet(), en.keys.toSet());
  });

  test('no string is empty and placeholders match in both languages', () {
    for (final key in en.keys) {
      expect(en[key]!.trim(), isNotEmpty, reason: key);
      expect(ar[key]!.trim(), isNotEmpty, reason: key);
      expect(
        placeholder.allMatches(ar[key]!).map((m) => m.group(0)).toSet(),
        placeholder.allMatches(en[key]!).map((m) => m.group(0)).toSet(),
        reason: key,
      );
    }
  });

  test('every Arabic string contains Arabic script', () {
    final arabic = RegExp(r'[\u0600-\u06FF]');
    for (final entry in ar.entries) {
      expect(arabic.hasMatch(entry.value), isTrue, reason: entry.key);
    }
  });

  test('"Not available" and counts are produced in both languages', () {
    const english = AppLocalizations(Locale('en'));
    const arabic = AppLocalizations(Locale('ar'));
    expect(english.notAvailable, 'Not available');
    expect(arabic.notAvailable, 'غير متوفر');
    expect(english.results(62), 'Results: 62');
    expect(arabic.results(62), 'النتائج: 62');
    expect(english.showingOf(1, 62), 'Showing 1 of 62');
    expect(arabic.showingOf(1, 62), 'عرض 1 من 62');
  });

  test('both locales are supported', () {
    expect(AppLocalizations.delegate.isSupported(const Locale('ar')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
  });
}
