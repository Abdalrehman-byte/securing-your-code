import 'dart:convert';

import 'key_value_store.dart';

/// A response body stored exactly as it was received from the source.
class CachedResponse {
  const CachedResponse({
    required this.url,
    required this.body,
    required this.fetchedAt,
  });

  final Uri url;

  /// The unmodified response body.
  final String body;

  /// When the body was downloaded from the source.
  final DateTime fetchedAt;
}

/// Offline cache of raw source responses, keyed by the exact request URL.
class ResponseCache {
  ResponseCache(this._store);

  final KeyValueStore _store;

  static String keyFor(Uri url) => 'response:$url';

  Future<CachedResponse?> get(Uri url) async {
    final raw = await _store.read(keyFor(url));
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Object? storedUrl = decoded['url'];
      final Object? body = decoded['body'];
      final Object? fetchedAt = decoded['fetchedAt'];
      if (storedUrl != url.toString() || body is! String) return null;
      if (fetchedAt is! String) return null;
      final at = DateTime.tryParse(fetchedAt);
      if (at == null) return null;
      return CachedResponse(url: url, body: body, fetchedAt: at);
    } on FormatException {
      return null;
    }
  }

  Future<void> put(Uri url, String body, DateTime fetchedAt) {
    return _store.write(
      keyFor(url),
      jsonEncode(<String, String>{
        'url': url.toString(),
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'body': body,
      }),
    );
  }
}
