import 'dart:convert';

/// Field names exactly as they appear in vPIC responses.
class VpicFields {
  const VpicFields._();

  static const String makeId = 'Make_ID';
  static const String makeName = 'Make_Name';
  static const String modelId = 'Model_ID';
  static const String modelName = 'Model_Name';
  static const String vehicleTypeName = 'VehicleTypeName';

  // DecodeVinValues
  static const String vin = 'VIN';
  static const String make = 'Make';
  static const String model = 'Model';
  static const String modelYear = 'ModelYear';
  static const String fuelTypePrimary = 'FuelTypePrimary';
  static const String errorCode = 'ErrorCode';
  static const String errorText = 'ErrorText';

  // GetCanadianVehicleSpecifications
  static const String specs = 'Specs';
  static const String specName = 'Name';
  static const String specValue = 'Value';
}

/// One element of the `Results` array, kept exactly as returned.
class VpicRecord {
  const VpicRecord(this.raw);

  /// The decoded JSON object, untouched (key order is preserved).
  final Map<String, dynamic> raw;

  /// The value of [key] as text, or `null` when the source has no data.
  String? string(String key) => vpicDisplayValue(raw[key]);

  int? integer(String key) {
    final Object? value = raw[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  List<MapEntry<String, Object?>> get fields {
    return <MapEntry<String, Object?>>[
      for (final entry in raw.entries) MapEntry<String, Object?>(entry.key, entry.value),
    ];
  }
}

/// The standard vPIC response envelope.
class VpicResponse {
  const VpicResponse({
    required this.count,
    required this.message,
    required this.searchCriteria,
    required this.results,
  });

  /// `Count` as returned.
  final int? count;

  /// `Message` as returned.
  final String? message;

  /// `SearchCriteria` as returned.
  final String? searchCriteria;

  /// `Results` as returned, in the source order.
  final List<VpicRecord> results;

  /// Parses a raw body. Throws [FormatException] when the body is not a
  /// vPIC envelope; nothing is guessed or filled in.
  factory VpicResponse.parse(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('vPIC response is not a JSON object');
    }
    final Object? results = decoded['Results'];
    if (results is! List) {
      throw const FormatException('vPIC response has no "Results" array');
    }
    final records = <VpicRecord>[];
    for (final Object? item in results) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('vPIC "Results" item is not an object');
      }
      records.add(VpicRecord(item));
    }
    final Object? count = decoded['Count'];
    final Object? message = decoded['Message'];
    final Object? criteria = decoded['SearchCriteria'];
    return VpicResponse(
      count: count is int ? count : null,
      message: message is String ? message : null,
      searchCriteria: criteria is String ? criteria : null,
      results: List<VpicRecord>.unmodifiable(records),
    );
  }
}

/// Text to show for a source value, or `null` when the source has no data
/// (JSON null, empty or blank string). Values are never altered.
String? vpicDisplayValue(Object? value) {
  if (value == null) return null;
  if (value is String) return value.trim().isEmpty ? null : value;
  if (value is num || value is bool) return value.toString();
  return jsonEncode(value);
}

/// Name/Value pairs of one `GetCanadianVehicleSpecifications` result, in the
/// source order. Falls back to the raw fields if the shape is different.
List<MapEntry<String, Object?>> canadianSpecFields(VpicRecord record) {
  final Object? specs = record.raw[VpicFields.specs];
  if (specs is! List) return record.fields;
  final fields = <MapEntry<String, Object?>>[];
  for (final Object? spec in specs) {
    if (spec is! Map) return record.fields;
    final Object? name = spec[VpicFields.specName];
    if (name is! String) return record.fields;
    fields.add(MapEntry<String, Object?>(name, spec[VpicFields.specValue]));
  }
  return fields;
}
