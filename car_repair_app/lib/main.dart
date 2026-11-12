import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/app_services.dart';
import 'src/data/key_value_store.dart';
import 'src/data/response_cache.dart';
import 'src/data/saved_vehicles.dart';
import 'src/data/vpic_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportDir = await getApplicationSupportDirectory();
  final separator = Platform.pathSeparator;
  final cacheStore = FileKeyValueStore(
    Directory('${supportDir.path}${separator}vpic_cache'),
  );
  final userStore = FileKeyValueStore(
    Directory('${supportDir.path}${separator}user_data'),
  );

  final services = AppServices(
    repository: VpicRepository(
      client: http.Client(),
      cache: ResponseCache(cacheStore),
    ),
    savedVehicles: SavedVehiclesStore(userStore),
    settings: userStore,
  );

  final savedLanguage = await userStore.read(localeSettingKey);
  final initialLocale = savedLanguage == 'ar' || savedLanguage == 'en'
      ? Locale(savedLanguage!)
      : null;

  runApp(CarRepairApp(services: services, initialLocale: initialLocale));
}
