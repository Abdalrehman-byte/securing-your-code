// Records real responses of the NHTSA vPIC API for the offline tests.
//
//   dart run tool/record_fixtures.dart [output directory]
//
// Every file is the unmodified response body. `index.json` lists the exact
// request URL and the UTC time of each recording. Nothing is hand-written:
// re-run this tool to refresh the fixtures.
import 'dart:convert';
import 'dart:io';

import 'package:car_repair_app/src/data/vpic_endpoints.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final out = Directory(args.isEmpty ? 'test/fixtures' : args.first);
  await out.create(recursive: true);

  // 474 is the Make_ID that vPIC returns for HONDA; 5UXWX7C5*BA with model
  // year 2011 is the partial-VIN example used in the vPIC documentation.
  final targets = <String, Uri>{
    'all_makes': VpicEndpoints.allMakes(),
    'vehicle_types_honda': VpicEndpoints.vehicleTypesForMakeId(474),
    'models_honda': VpicEndpoints.models(makeId: 474),
    'models_honda_2015': VpicEndpoints.models(makeId: 474, year: 2015),
    'models_honda_2015_passenger_car': VpicEndpoints.models(
      makeId: 474,
      year: 2015,
      vehicleType: 'Passenger Car',
    ),
    'models_honda_1950': VpicEndpoints.models(makeId: 474, year: 1950),
    'canadian_specs_2015_honda_accord': VpicEndpoints.canadianSpecs(
      year: 2015,
      make: 'HONDA',
      model: 'Accord',
    ),
    'canadian_specs_2015_honda_cb300f': VpicEndpoints.canadianSpecs(
      year: 2015,
      make: 'HONDA',
      model: 'CB300F',
    ),
    'decode_vin_5uxwx7c5_ba_2011': VpicEndpoints.decodeVinValues(
      '5UXWX7C5*BA',
      modelYear: 2011,
    ),
  };

  final client = http.Client();
  final index = <Map<String, Object>>[];
  var failed = false;
  for (final entry in targets.entries) {
    final response = await client.get(entry.value);
    stdout.writeln(
      '${response.statusCode} ${response.bodyBytes.length} bytes ${entry.value}',
    );
    if (response.statusCode != 200) {
      failed = true;
      continue;
    }
    final file = '${entry.key}.json';
    await File('${out.path}/$file').writeAsBytes(response.bodyBytes);
    index.add(<String, Object>{
      'file': file,
      'url': entry.value.toString(),
      'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'bytes': response.bodyBytes.length,
    });
  }
  client.close();

  const encoder = JsonEncoder.withIndent('  ');
  await File('${out.path}/index.json').writeAsString(
    '${encoder.convert(index)}\n',
  );
  if (failed) exitCode = 1;
}
