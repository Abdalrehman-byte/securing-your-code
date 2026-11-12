import 'package:car_repair_app/src/app.dart';
import 'package:car_repair_app/src/app_services.dart';
import 'package:car_repair_app/src/data/key_value_store.dart';
import 'package:car_repair_app/src/data/response_cache.dart';
import 'package:car_repair_app/src/data/saved_vehicles.dart';
import 'package:car_repair_app/src/data/vpic_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// The whole app wired to recorded real vPIC responses and in-memory storage.
class AppHarness {
  AppHarness({MemoryKeyValueStore? store})
      : store = store ?? MemoryKeyValueStore(),
        network = FakeVpicNetwork(Fixtures.load());

  final MemoryKeyValueStore store;
  final FakeVpicNetwork network;

  Fixtures get fixtures => network.fixtures;

  Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    // A tall phone-width surface so that lazily built lists are on screen.
    tester.view.physicalSize = const Size(900, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = AppServices(
      repository: VpicRepository(
        client: network.client,
        cache: ResponseCache(store),
      ),
      savedVehicles: SavedVehiclesStore(store),
      settings: store,
    );
    await tester.pumpWidget(
      CarRepairApp(
        key: UniqueKey(),
        services: services,
        initialLocale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the make picker, searches for "honda" and picks HONDA (474).
  Future<void> pickHonda(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('make-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('make-search')), 'honda');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('make-474')));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, {String? year}) async {
    if (year != null) {
      await tester.enterText(find.byKey(const Key('year-field')), year);
    }
    await tester.tap(find.byKey(const Key('search-button')));
    await tester.pumpAndSettle();
  }
}
