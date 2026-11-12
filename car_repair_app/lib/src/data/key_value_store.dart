import 'dart:convert';
import 'dart:io';

/// Minimal persistent string storage used for the offline cache, the saved
/// vehicles and the app settings.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// In-memory store (used by widget tests; nothing survives a restart).
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  int get length => _values.length;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// Stores every key in its own file inside [directory] so the data survives
/// app restarts and is readable with no network connection.
class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore(this.directory);

  final Directory directory;

  File fileFor(String key) {
    return File(
      '${directory.path}${Platform.pathSeparator}${stableKeyHash(key)}.json',
    );
  }

  @override
  Future<String?> read(String key) async {
    final file = fileFor(key);
    try {
      if (!await file.exists()) return null;
      final Object? decoded = jsonDecode(await file.readAsString());
      // The key is stored next to the value so a file-name collision or a
      // damaged file can never return the wrong data.
      if (decoded is Map && decoded['key'] == key) {
        final Object? value = decoded['value'];
        if (value is String) return value;
      }
      return null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await directory.create(recursive: true);
    final file = fileFor(key);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(<String, String>{'key': key, 'value': value}),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = fileFor(key);
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Nothing to delete.
    }
  }
}

int _fnv1a32(Iterable<int> bytes, int seed) {
  var hash = seed;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Deterministic, file-name-safe hash of [key] (16 hex characters).
String stableKeyHash(String key) {
  final bytes = utf8.encode(key);
  final a = _fnv1a32(bytes, 0x811C9DC5);
  final b = _fnv1a32(bytes.reversed, 0x9747B28C ^ bytes.length);
  return a.toRadixString(16).padLeft(8, '0') +
      b.toRadixString(16).padLeft(8, '0');
}
