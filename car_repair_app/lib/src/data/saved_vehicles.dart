import 'dart:convert';

import 'key_value_store.dart';
import 'vpic_models.dart';

/// A VIN decode result the user chose to keep, with its citation.
class SavedVehicle {
  const SavedVehicle({
    required this.url,
    required this.fetchedAt,
    required this.record,
  });

  /// The exact vPIC request URL that returned [record].
  final Uri url;
  final DateTime fetchedAt;

  /// The decode result exactly as returned.
  final VpicRecord record;

  Map<String, Object?> toJson() => <String, Object?>{
        'url': url.toString(),
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'record': record.raw,
      };

  static SavedVehicle? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? url = json['url'];
    final Object? fetchedAt = json['fetchedAt'];
    final Object? record = json['record'];
    if (url is! String || fetchedAt is! String) return null;
    if (record is! Map<String, dynamic>) return null;
    final uri = Uri.tryParse(url);
    final at = DateTime.tryParse(fetchedAt);
    if (uri == null || at == null) return null;
    return SavedVehicle(url: uri, fetchedAt: at, record: VpicRecord(record));
  }
}

/// Persists the saved vehicles on the device.
class SavedVehiclesStore {
  SavedVehiclesStore(this._store);

  static const String storageKey = 'saved-vehicles';

  final KeyValueStore _store;

  Future<List<SavedVehicle>> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return <SavedVehicle>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <SavedVehicle>[];
      return <SavedVehicle>[
        for (final Object? item in decoded)
          if (SavedVehicle.fromJson(item) case final SavedVehicle vehicle)
            vehicle,
      ];
    } on FormatException {
      return <SavedVehicle>[];
    }
  }

  /// Adds [vehicle], replacing an earlier save of the same request URL.
  Future<List<SavedVehicle>> add(SavedVehicle vehicle) async {
    final current = await load();
    final next = <SavedVehicle>[
      for (final item in current)
        if (item.url != vehicle.url) item,
      vehicle,
    ];
    await _write(next);
    return next;
  }

  Future<List<SavedVehicle>> remove(Uri url) async {
    final current = await load();
    final next = <SavedVehicle>[
      for (final item in current)
        if (item.url != url) item,
    ];
    await _write(next);
    return next;
  }

  Future<void> _write(List<SavedVehicle> vehicles) {
    return _store.write(
      storageKey,
      jsonEncode(<Object?>[for (final v in vehicles) v.toJson()]),
    );
  }
}
