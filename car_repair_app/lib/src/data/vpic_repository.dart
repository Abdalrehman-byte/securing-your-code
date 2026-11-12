import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'response_cache.dart';
import 'vpic_endpoints.dart';
import 'vpic_models.dart';

/// Where the data shown to the user came from.
enum DataOrigin {
  /// Downloaded from the source for this request.
  network,

  /// A saved copy that is still within [VpicRepository.maxAge].
  cache,

  /// The source could not be reached; an older saved copy is shown.
  staleCache,
}

enum VpicErrorKind { offline, http, badResponse }

class VpicException implements Exception {
  const VpicException(this.kind, this.url, this.detail);

  final VpicErrorKind kind;
  final Uri url;
  final String detail;

  @override
  String toString() => 'VpicException(${kind.name}, $url, $detail)';
}

/// Data plus the citation needed to show where it came from.
class Sourced<T> {
  const Sourced({
    required this.data,
    required this.url,
    required this.fetchedAt,
    required this.origin,
  });

  final T data;

  /// The exact vPIC request URL that produced [data].
  final Uri url;

  /// When [data] was downloaded from the source.
  final DateTime fetchedAt;

  final DataOrigin origin;
}

/// Reads the NHTSA vPIC API and keeps every response for offline use.
///
/// Policy: a saved copy younger than [maxAge] is used without a network
/// call; otherwise the source is called and the copy replaced. If the source
/// cannot be reached, the saved copy (any age) is returned and flagged as
/// [DataOrigin.staleCache]. With no saved copy a [VpicException] is thrown,
/// and the UI shows "Not available".
class VpicRepository {
  VpicRepository({
    required this.client,
    required this.cache,
    this.maxAge = const Duration(days: 7),
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final http.Client client;
  final ResponseCache cache;
  final DateTime Function() _now;

  final Duration maxAge;
  final Duration timeout;

  Future<Sourced<VpicResponse>> allMakes({bool forceRefresh = false}) {
    return fetch(VpicEndpoints.allMakes(), forceRefresh: forceRefresh);
  }

  Future<Sourced<VpicResponse>> vehicleTypesForMake(
    int makeId, {
    bool forceRefresh = false,
  }) {
    return fetch(
      VpicEndpoints.vehicleTypesForMakeId(makeId),
      forceRefresh: forceRefresh,
    );
  }

  Future<Sourced<VpicResponse>> models({
    required int makeId,
    int? year,
    String? vehicleType,
    bool forceRefresh = false,
  }) {
    return fetch(
      VpicEndpoints.models(makeId: makeId, year: year, vehicleType: vehicleType),
      forceRefresh: forceRefresh,
    );
  }

  Future<Sourced<VpicResponse>> canadianSpecs({
    required int year,
    required String make,
    String model = '',
    bool forceRefresh = false,
  }) {
    return fetch(
      VpicEndpoints.canadianSpecs(year: year, make: make, model: model),
      forceRefresh: forceRefresh,
    );
  }

  Future<Sourced<VpicResponse>> decodeVin(
    String vin, {
    int? modelYear,
    bool forceRefresh = false,
  }) {
    return fetch(
      VpicEndpoints.decodeVinValues(vin, modelYear: modelYear),
      forceRefresh: forceRefresh,
    );
  }

  Future<Sourced<VpicResponse>> fetch(
    Uri url, {
    bool forceRefresh = false,
  }) async {
    final cached = await cache.get(url);
    final cachedParsed = cached == null ? null : _tryParse(cached.body);

    if (!forceRefresh && cached != null && cachedParsed != null) {
      final age = _now().difference(cached.fetchedAt);
      if (age < maxAge) {
        return Sourced<VpicResponse>(
          data: cachedParsed,
          url: url,
          fetchedAt: cached.fetchedAt,
          origin: DataOrigin.cache,
        );
      }
    }

    try {
      final body = await _download(url);
      final parsed = _parse(url, body);
      final fetchedAt = _now();
      await cache.put(url, body, fetchedAt);
      return Sourced<VpicResponse>(
        data: parsed,
        url: url,
        fetchedAt: fetchedAt,
        origin: DataOrigin.network,
      );
    } on VpicException {
      if (cached != null && cachedParsed != null) {
        return Sourced<VpicResponse>(
          data: cachedParsed,
          url: url,
          fetchedAt: cached.fetchedAt,
          origin: DataOrigin.staleCache,
        );
      }
      rethrow;
    }
  }

  Future<String> _download(Uri url) async {
    final http.Response response;
    try {
      response = await client.get(
        url,
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(timeout);
    } on Exception catch (error) {
      // SocketException, TimeoutException, ClientException, TLS errors...
      throw VpicException(VpicErrorKind.offline, url, error.toString());
    }
    if (response.statusCode != 200) {
      throw VpicException(
        VpicErrorKind.http,
        url,
        'HTTP ${response.statusCode}',
      );
    }
    try {
      // JSON is UTF-8 (RFC 8259); vPIC does not always send a charset.
      return utf8.decode(response.bodyBytes);
    } on FormatException catch (error) {
      throw VpicException(VpicErrorKind.badResponse, url, error.message);
    }
  }

  VpicResponse _parse(Uri url, String body) {
    try {
      return VpicResponse.parse(body);
    } on FormatException catch (error) {
      throw VpicException(VpicErrorKind.badResponse, url, error.message);
    }
  }

  VpicResponse? _tryParse(String body) {
    try {
      return VpicResponse.parse(body);
    } on FormatException {
      return null;
    }
  }
}
