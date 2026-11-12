import 'data/key_value_store.dart';
import 'data/saved_vehicles.dart';
import 'data/vpic_repository.dart';

/// Storage key of the UI language chosen by the user (`en` or `ar`).
const String localeSettingKey = 'settings:locale';

/// The objects the UI needs, created once in `main`.
class AppServices {
  const AppServices({
    required this.repository,
    required this.savedVehicles,
    required this.settings,
  });

  final VpicRepository repository;
  final SavedVehiclesStore savedVehicles;
  final KeyValueStore settings;
}
