# Recorded vPIC responses

Every `.json` file here (except `index.json`) is the unmodified body of a
real response from the official NHTSA vPIC API,
<https://vpic.nhtsa.dot.gov/api/>. Nothing was written or edited by hand.

`index.json` lists, for each file, the exact request URL and the UTC time of
the recording. To refresh the recordings:

```
dart run tool/record_fixtures.dart
```

The offline tests replay these bodies in place of the network, so that
search, filtering, display and caching are tested against real data without
needing a connection. `test_live/` runs the same code against the live API.
