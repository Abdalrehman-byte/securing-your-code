import 'vpic_models.dart';

/// Converts Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) digits to
/// ASCII digits so that numbers typed with an Arabic keyboard are accepted.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

final RegExp _fourDigits = RegExp(r'^[0-9]{4}$');

/// Parses a 4-digit model year typed by the user, or returns `null`.
///
/// No range is enforced here: the year is only a query filter and the source
/// decides whether it has data for it.
int? parseModelYear(String input) {
  final text = normalizeDigits(input).trim();
  if (!_fourDigits.hasMatch(text)) return null;
  return int.parse(text);
}

final RegExp _vinPattern = RegExp(r'^[A-Z0-9*]{1,17}$');

/// Upper-cases a VIN typed by the user and accepts only letters, digits and
/// `*` (vPIC's placeholder for unknown characters), up to 17 characters.
String? normalizeVin(String input) {
  final text = normalizeDigits(input).trim().toUpperCase();
  return _vinPattern.hasMatch(text) ? text : null;
}

/// Case-insensitive search of [records] by the text of [field].
///
/// Records whose value starts with [query] come first, then the ones that
/// contain it; inside each group the source order is kept. An empty query
/// returns all records unchanged. Records are never modified.
List<VpicRecord> searchRecords(
  List<VpicRecord> records,
  String field,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return records;
  final prefix = <VpicRecord>[];
  final contains = <VpicRecord>[];
  for (final record in records) {
    final value = record.string(field)?.toLowerCase();
    if (value == null) continue;
    if (value.startsWith(needle)) {
      prefix.add(record);
    } else if (value.contains(needle)) {
      contains.add(record);
    }
  }
  return <VpicRecord>[...prefix, ...contains];
}

/// Distinct values of [field] among [records], in first-seen order. A `null`
/// element stands for records where the source has no data for the field.
List<String?> distinctFieldValues(Iterable<VpicRecord> records, String field) {
  final seen = <String?>{};
  for (final record in records) {
    seen.add(record.string(field));
  }
  return seen.toList();
}

/// Keeps the items whose record has exactly [value] in [field]
/// (`null` = the source has no data for the field).
List<T> filterByFieldValue<T>(
  Iterable<T> items,
  VpicRecord Function(T item) recordOf,
  String field,
  String? value,
) {
  return <T>[
    for (final item in items)
      if (recordOf(item).string(field) == value) item,
  ];
}
