import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Real vPIC responses recorded by `tool/record_fixtures.dart`
/// (see `test/fixtures/README.md`). Nothing in them is hand-written.
class Fixtures {
  Fixtures._(this._urls, this._bodies);

  static Fixtures? _instance;

  static Fixtures load() => _instance ??= _read();

  static Fixtures _read() {
    final index = jsonDecode(
      File('test/fixtures/index.json').readAsStringSync(),
    ) as List<dynamic>;
    final urls = <String, Uri>{};
    final bodies = <String, String>{};
    for (final Object? item in index) {
      final entry = item! as Map<String, dynamic>;
      final file = entry['file'] as String;
      final name = file.replaceAll('.json', '');
      urls[name] = Uri.parse(entry['url'] as String);
      bodies[name] = utf8.decode(
        File('test/fixtures/$file').readAsBytesSync(),
      );
    }
    return Fixtures._(urls, bodies);
  }

  final Map<String, Uri> _urls;
  final Map<String, String> _bodies;

  Iterable<String> get names => _urls.keys;

  /// The exact request URL the body was recorded from.
  Uri url(String name) => _urls[name]!;

  /// The unmodified recorded body.
  String body(String name) => _bodies[name]!;

  Map<String, dynamic> json(String name) {
    return jsonDecode(body(name)) as Map<String, dynamic>;
  }

  List<dynamic> results(String name) => json(name)['Results'] as List<dynamic>;

  String? bodyForUrl(Uri url) {
    for (final name in names) {
      if (_urls[name] == url) return _bodies[name];
    }
    return null;
  }
}

/// Stands in for the network in offline tests: answers with the recorded
/// real bodies and can be switched "offline" to simulate no connectivity.
class FakeVpicNetwork {
  FakeVpicNetwork(this.fixtures);

  final Fixtures fixtures;

  /// When `false` every request fails like a device with no connection.
  bool online = true;

  /// Overrides the answer for all requests (to simulate server errors).
  http.Response Function(http.Request request)? override;

  /// Every request that was attempted, in order.
  final List<Uri> requests = <Uri>[];

  late final http.Client client = MockClient((request) async {
    requests.add(request.url);
    if (!online) {
      throw const SocketException('Simulated: no network connection');
    }
    final override = this.override;
    if (override != null) return override(request);
    final body = fixtures.bodyForUrl(request.url);
    if (body == null) {
      return http.Response('No fixture recorded for ${request.url}', 404);
    }
    // Like the real GetAllMakes response: JSON with no charset parameter.
    return http.Response.bytes(
      utf8.encode(body),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  });
}
