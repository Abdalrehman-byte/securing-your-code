import 'package:car_repair_app/src/data/vpic_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  const base = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  test('request URLs follow the documented vPIC endpoints', () {
    expect(
      VpicEndpoints.allMakes().toString(),
      '$base/GetAllMakes?format=json',
    );
    expect(
      VpicEndpoints.vehicleTypesForMakeId(474).toString(),
      '$base/GetVehicleTypesForMakeId/474?format=json',
    );
    expect(
      VpicEndpoints.models(makeId: 474).toString(),
      '$base/GetModelsForMakeId/474?format=json',
    );
    expect(
      VpicEndpoints.models(makeId: 474, year: 2015).toString(),
      '$base/GetModelsForMakeIdYear/makeId/474/modelyear/2015?format=json',
    );
    expect(
      VpicEndpoints.models(
        makeId: 474,
        year: 2015,
        vehicleType: 'Passenger Car',
      ).toString(),
      '$base/GetModelsForMakeIdYear/makeId/474/modelyear/2015/vehicleType/Passenger%20Car?format=json',
    );
    expect(
      VpicEndpoints.models(makeId: 474, vehicleType: 'Truck').toString(),
      '$base/GetModelsForMakeIdYear/makeId/474/vehicleType/Truck?format=json',
    );
    expect(
      VpicEndpoints.canadianSpecs(
        year: 2015,
        make: 'HONDA',
        model: 'Accord',
      ).toString(),
      '$base/GetCanadianVehicleSpecifications/?year=2015&make=HONDA&model=Accord&units&format=json',
    );
    expect(
      VpicEndpoints.decodeVinValues('5UXWX7C5*BA', modelYear: 2011).toString(),
      '$base/DecodeVinValues/5UXWX7C5*BA?format=json&modelyear=2011',
    );
    expect(
      VpicEndpoints.decodeVinValues('5UXWX7C5*BA').toString(),
      '$base/DecodeVinValues/5UXWX7C5*BA?format=json',
    );
  });

  test('every recorded fixture comes from the official vPIC host over HTTPS',
      () {
    final fixtures = Fixtures.load();
    expect(fixtures.names, isNotEmpty);
    for (final name in fixtures.names) {
      final url = fixtures.url(name);
      expect(url.scheme, 'https', reason: name);
      expect(url.host, VpicEndpoints.host, reason: name);
      expect(url.path, startsWith('/api/vehicles/'), reason: name);
    }
  });

  test('fixtures were recorded from exactly the URLs the app requests', () {
    final fixtures = Fixtures.load();
    expect(fixtures.url('all_makes'), VpicEndpoints.allMakes());
    expect(
      fixtures.url('vehicle_types_honda'),
      VpicEndpoints.vehicleTypesForMakeId(474),
    );
    expect(fixtures.url('models_honda'), VpicEndpoints.models(makeId: 474));
    expect(
      fixtures.url('models_honda_2015'),
      VpicEndpoints.models(makeId: 474, year: 2015),
    );
    expect(
      fixtures.url('models_honda_2015_passenger_car'),
      VpicEndpoints.models(
        makeId: 474,
        year: 2015,
        vehicleType: 'Passenger Car',
      ),
    );
    expect(
      fixtures.url('models_honda_1950'),
      VpicEndpoints.models(makeId: 474, year: 1950),
    );
    expect(
      fixtures.url('canadian_specs_2015_honda_accord'),
      VpicEndpoints.canadianSpecs(year: 2015, make: 'HONDA', model: 'Accord'),
    );
    expect(
      fixtures.url('canadian_specs_2015_honda_cb300f'),
      VpicEndpoints.canadianSpecs(year: 2015, make: 'HONDA', model: 'CB300F'),
    );
    expect(
      fixtures.url('decode_vin_5uxwx7c5_ba_2011'),
      VpicEndpoints.decodeVinValues('5UXWX7C5*BA', modelYear: 2011),
    );
  });
}
