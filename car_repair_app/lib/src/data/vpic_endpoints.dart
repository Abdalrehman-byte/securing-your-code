/// Request URLs of the official NHTSA vPIC API.
///
/// Documentation: https://vpic.nhtsa.dot.gov/api/
///
/// This file has no Flutter dependency so that `tool/record_fixtures.dart`
/// builds exactly the same URLs as the app.
class VpicEndpoints {
  const VpicEndpoints._();

  static const String host = 'vpic.nhtsa.dot.gov';
  static const String documentationUrl = 'https://vpic.nhtsa.dot.gov/api/';

  static const List<String> _base = <String>['api', 'vehicles'];
  static const Map<String, String> _json = <String, String>{'format': 'json'};

  static Uri _build(List<String> segments, [Map<String, String> query = _json]) {
    return Uri(
      scheme: 'https',
      host: host,
      pathSegments: <String>[..._base, ...segments],
      queryParameters: query,
    );
  }

  /// `GetAllMakes`: every make in the vPIC data set.
  static Uri allMakes() => _build(const <String>['GetAllMakes']);

  /// `GetVehicleTypesForMakeId`: vehicle types recorded for one make.
  static Uri vehicleTypesForMakeId(int makeId) {
    return _build(<String>['GetVehicleTypesForMakeId', '$makeId']);
  }

  /// `GetModelsForMakeId` when no filter is given, otherwise
  /// `GetModelsForMakeIdYear` with the model year and/or vehicle type.
  static Uri models({required int makeId, int? year, String? vehicleType}) {
    if (year == null && vehicleType == null) {
      return _build(<String>['GetModelsForMakeId', '$makeId']);
    }
    return _build(<String>[
      'GetModelsForMakeIdYear',
      'makeId',
      '$makeId',
      if (year != null) ...<String>['modelyear', '$year'],
      if (vehicleType != null) ...<String>['vehicleType', vehicleType],
    ]);
  }

  /// `GetCanadianVehicleSpecifications`: dimensional specifications by
  /// year, make and model (units left empty, as in the vPIC documentation).
  static Uri canadianSpecs({
    required int year,
    required String make,
    String model = '',
  }) {
    return _build(
      const <String>['GetCanadianVehicleSpecifications', ''],
      <String, String>{
        'year': '$year',
        'make': make,
        'model': model,
        'units': '',
        'format': 'json',
      },
    );
  }

  /// `DecodeVinValues`: flat key/value decode of a full or partial VIN.
  static Uri decodeVinValues(String vin, {int? modelYear}) {
    return _build(
      <String>['DecodeVinValues', vin],
      <String, String>{
        'format': 'json',
        if (modelYear != null) 'modelyear': '$modelYear',
      },
    );
  }
}
