import 'package:flutter/material.dart';

import '../data/vpic_models.dart';
import '../data/vpic_repository.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';

/// Number of fields of [record] for which the source has no data.
int emptyFieldCount(VpicRecord record) {
  var count = 0;
  for (final value in record.raw.values) {
    if (vpicDisplayValue(value) == null) count++;
  }
  return count;
}

/// Field list of a decoded record with a switch that also lists the fields
/// the source returned empty (shown as "Not available").
class DecodedRecordView extends StatefulWidget {
  const DecodedRecordView({super.key, required this.record});

  final VpicRecord record;

  @override
  State<DecodedRecordView> createState() => _DecodedRecordViewState();
}

class _DecodedRecordViewState extends State<DecodedRecordView> {
  bool _showEmpty = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final empty = emptyFieldCount(widget.record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RecordFieldsView(fields: widget.record.fields, hideEmpty: !_showEmpty),
        const Divider(height: 24),
        Text(
          l10n.emptyFieldCount(empty),
          key: const Key('empty-field-count'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SwitchListTile(
          key: const Key('show-empty-fields'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.showEmptyFields),
          value: _showEmpty,
          onChanged: (value) => setState(() => _showEmpty = value),
        ),
      ],
    );
  }
}

/// Full-screen view of one saved decode result with its citation.
class RecordScreen extends StatelessWidget {
  const RecordScreen({
    super.key,
    required this.title,
    required this.record,
    required this.url,
    required this.fetchedAt,
  });

  final String? title;
  final VpicRecord record;
  final Uri url;
  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = this.title;
    return Scaffold(
      appBar: AppBar(
        title: title == null ? Text(l10n.details) : SourceText(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SectionCard(
            title: l10n.recordAsReturned,
            children: <Widget>[
              DecodedRecordView(record: record),
              const SizedBox(height: 8),
              SourceCitation(
                url: url,
                fetchedAt: fetchedAt,
                origin: DataOrigin.cache,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
