// Renders the real app widgets to PNG files, using the recorded real vPIC
// responses in test/fixtures (no network).
//
//   flutter test test_screenshots
//
// Output: build/screenshots/*.png. These are renders made by Flutter's test
// engine, not photos of a device. Fonts: Roboto is taken from the Flutter
// SDK cache; SCREENSHOT_ARABIC_FONT must point to a .ttf with Arabic glyphs
// (the test engine has no system fonts). Without fonts, text is drawn as
// placeholder boxes.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show BackButton;

import '../test/support/app_harness.dart';

const Size _phone = Size(390, 844);
const String _arabicFamily = 'ScreenshotArabic';
final Directory _out = Directory('build/screenshots');

Future<void> _loadFamily(String family, Iterable<File> files) async {
  final existing = files.where((f) => f.existsSync()).toList();
  if (existing.isEmpty) {
    print('[screenshots] no font files for $family');
    return;
  }
  final loader = FontLoader(family);
  for (final file in existing) {
    loader.addFont(
      file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();
  print('[screenshots] $family <- ${existing.map((f) => f.path).join(', ')}');
}

Future<void> _loadFonts() async {
  // Fonts bundled with the app (Material icons).
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final Object? entry in manifest) {
    final map = entry! as Map<String, dynamic>;
    final loader = FontLoader(map['family'] as String);
    for (final Object? font in map['fonts'] as List<dynamic>) {
      final asset = (font! as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
    print('[screenshots] bundled font: ${map['family']}');
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
    await _loadFamily('Roboto', <File>[
      File('$dir/Roboto-Regular.ttf'),
      File('$dir/Roboto-Medium.ttf'),
      File('$dir/Roboto-Bold.ttf'),
    ]);
  }
  final arabic = Platform.environment['SCREENSHOT_ARABIC_FONT'];
  if (arabic != null && arabic.isNotEmpty) {
    await _loadFamily(_arabicFamily, <File>[File(arabic)]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    if (_out.existsSync()) _out.deleteSync(recursive: true);
    _out.createSync(recursive: true);
  });

  final boundaryKey = GlobalKey();

  Future<AppHarness> start(WidgetTester tester, Locale locale) async {
    final app = AppHarness();
    await app.pump(
      tester,
      locale: locale,
      size: _phone,
      fontFamilyFallback: const <String>[_arabicFamily],
      repaintBoundaryKey: boundaryKey,
    );
    return app;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('${_out.path}/$name.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      print('[screenshots] ${file.path} (${file.lengthSync()} bytes)');
    });
  }

  /// Runs [body] with real shadows (tests replace them with outlines).
  Future<void> withShadows(Future<void> Function() body) async {
    debugDisableShadows = false;
    try {
      await body();
    } finally {
      debugDisableShadows = true;
    }
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('$lang: car database', (tester) async {
      await withShadows(() async {
        final app = await start(tester, locale);
        await shot(tester, '${lang}_01_database_empty');

        await tester.tap(find.byKey(const Key('make-field')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('make-search')), 'hond');
        await shot(tester, '${lang}_02_make_search');
        await tester.tap(find.byKey(const ValueKey<String>('make-474')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('year-field')), '2015');
        await tester.pumpAndSettle();
        await shot(tester, '${lang}_03_filters');

        await tester.ensureVisible(find.byKey(const Key('search-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('search-button')));
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.text('Civic'),
          find.byType(CustomScrollView),
          const Offset(0, -200),
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
        await shot(tester, '${lang}_04_results');

        await tester.ensureVisible(find.text('Accord'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accord'));
        await tester.pumpAndSettle();
        await shot(tester, '${lang}_05_model_detail');
        await tester.drag(find.byType(ListView), const Offset(0, -520));
        await shot(tester, '${lang}_06_model_specs');

        // Offline: a query that was never downloaded.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        app.network.online = false;
        await tester.ensureVisible(find.byKey(const Key('year-field')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('year-field')), '2016');
        await tester.ensureVisible(find.byKey(const Key('search-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('search-button')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await shot(tester, '${lang}_07_offline_not_available');
      });
    });

    testWidgets('$lang: VIN decode', (tester) async {
      await withShadows(() async {
        await start(tester, locale);
        await tester.tap(find.byKey(const Key('tab-vin')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('vin-field')),
          '5UXWX7C5*BA',
        );
        await tester.enterText(find.byKey(const Key('vin-year-field')), '2011');
        await tester.tap(find.byKey(const Key('decode-button')));
        await tester.pumpAndSettle();
        await shot(tester, '${lang}_08_vin_decoded');

        await tester.ensureVisible(find.byKey(const Key('save-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-button')));
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.byKey(const ValueKey<String>('engine-Gasoline')),
          find.byType(ListView),
          const Offset(0, -300),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await shot(tester, '${lang}_09_saved_engine_filter');
      });
    });
  }
}
