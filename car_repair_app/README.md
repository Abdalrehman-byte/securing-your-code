# Car Repair (Flutter, Arabic / English)

A mobile app for car repair. The UI is available in English and Arabic
(right-to-left), switchable from the app bar.

> This app lives in `car_repair_app/` and is independent of the rest of this
> repository.

## Standing data rule

Every piece of data shown in the app comes from a real, documented source and
is shown exactly as that source returned it. Nothing is invented, estimated,
translated or filled in. Where the source has no data, the app shows
**Not available** (Arabic: **غير متوفر**). Every block of data carries a
citation: the source name, the exact request URL, the time it was downloaded
and whether it is a live answer or the copy saved on the device.

## Feature 1: car database

Source: the official **NHTSA vPIC API** (U.S. National Highway Traffic Safety
Administration, Product Information Catalog and Vehicle Listing).
Documentation: <https://vpic.nhtsa.dot.gov/api/>

| What the app shows | vPIC endpoint | Where |
| --- | --- | --- |
| Makes (searchable) | `GetAllMakes` | Make picker |
| Vehicle types of a make (filter options) | `GetVehicleTypesForMakeId/{makeId}` | Vehicle-type filter |
| Models of a make | `GetModelsForMakeId/{makeId}` | Search with no year and no type |
| Models of a make for a model year and/or vehicle type | `GetModelsForMakeIdYear/makeId/{id}[/modelyear/{year}][/vehicleType/{type}]` | Search results |
| Dimensional specifications by year, make and model | `GetCanadianVehicleSpecifications` | Model detail page |
| Full decode of a VIN, including engine fields | `DecodeVinValues/{vin}` | "By VIN" tab |

All request URLs are built in one file, `lib/src/data/vpic_endpoints.dart`.

### What vPIC does not provide (and how the app handles it)

- **A list of years.** vPIC has no endpoint that lists the model years of a
  make or model. The model year is a filter you type; the app sends it to
  vPIC and shows whatever comes back. A year vPIC has nothing for shows
  "Not available".
- **Engine type by make, model and year.** vPIC returns engine fields
  (`FuelTypePrimary`, `EngineCylinders`, `DisplacementL`, ...) only when a
  VIN is decoded. In the database search the engine-type filter therefore
  shows "Not available" with this explanation. In the "By VIN" tab you can
  decode a VIN, save the vehicle, and filter saved vehicles by engine type
  using the value vPIC returned in `FuelTypePrimary`.
- **Labels for specification codes.** The Canadian specifications are
  returned as codes (`OL`, `OW`, `WB`, ...). The app shows the codes and
  values exactly as returned and does not add descriptions or units.
- **Images.** None are shown.

### Search and filters

- Make: search across every make returned by `GetAllMakes`
  (case-insensitive; names starting with the text come first).
- Model year: optional, 4 digits (Arabic-Indic digits are accepted).
- Vehicle type: the options are the types vPIC lists for the chosen make.
- Model: filters the returned models by name as you type.
- Engine type: see above.

### Offline cache

Every response is saved on the device, unmodified, keyed by its request URL
(`lib/src/data/response_cache.dart`, files under the app-support directory).

- A saved copy younger than 7 days is used without a network call.
- An older copy is refreshed from vPIC; if vPIC cannot be reached the saved
  copy is shown and labelled "offline, showing the saved copy".
- The refresh button on a citation always asks vPIC again.
- With no connection and no saved copy the app shows "Not available"; it
  never shows placeholder data.

## Project layout

```
lib/main.dart                    app start-up (storage, HTTP client)
lib/src/data/                    vPIC endpoints, parsing, cache, search
lib/src/l10n/                    English and Arabic UI strings
lib/src/ui/                      screens and shared widgets
test/                            offline tests on recorded real responses
test/fixtures/                   the recorded vPIC responses (see its README)
test_live/                       tests that call the real vPIC API
test_screenshots/                renders the screens to PNG files
tool/record_fixtures.dart        re-records test/fixtures from vPIC
```

## Run

Requires Flutter 3.50 or newer (stable).

```
cd car_repair_app
flutter pub get
flutter run
```

The Android application id and iOS bundle id are the Flutter template
defaults (`com.example.car_repair_app`); change them before publishing.

## Test

```
flutter analyze
flutter test                 # offline: recorded real vPIC responses
flutter test test_live       # calls the real vPIC API (needs internet)
flutter test test_screenshots   # writes build/screenshots/*.png
```

The GitHub Actions workflow `.github/workflows/car-repair-app.yml` runs all
of the above on every push that touches this directory, builds a debug APK
(downloadable from the workflow run as `car-repair-app-debug-apk`) and
attaches the test report to the commit as a check.
