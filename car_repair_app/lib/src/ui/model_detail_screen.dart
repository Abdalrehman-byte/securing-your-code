import 'package:flutter/material.dart';

import '../data/vpic_models.dart';
import '../data/vpic_repository.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';

/// Everything vPIC returns for one model: the model record itself and, when a
/// model year was queried, the Canadian Vehicle Specifications entries.
class ModelDetailScreen extends StatefulWidget {
  const ModelDetailScreen({
    super.key,
    required this.repository,
    required this.model,
    required this.source,
    required this.queryYear,
    required this.onOpenVin,
  });

  final VpicRepository repository;

  /// The model record exactly as returned.
  final VpicRecord model;

  /// The response the record came from (for the citation).
  final Sourced<VpicResponse> source;

  /// The model year the user searched with, if any.
  final int? queryYear;

  final VoidCallback onOpenVin;

  @override
  State<ModelDetailScreen> createState() => _ModelDetailScreenState();
}

class _ModelDetailScreenState extends State<ModelDetailScreen> {
  bool _specsLoading = false;
  Sourced<VpicResponse>? _specs;
  VpicException? _specsError;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  Future<void> _loadSpecs({bool forceRefresh = false}) async {
    final year = widget.queryYear;
    final make = widget.model.string(VpicFields.makeName);
    final model = widget.model.string(VpicFields.modelName);
    if (year == null || make == null || model == null) return;
    setState(() {
      _specsLoading = true;
      _specsError = null;
    });
    try {
      final specs = await widget.repository.canadianSpecs(
        year: year,
        make: make,
        model: model,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _specs = specs;
        _specsLoading = false;
      });
    } on VpicException catch (error) {
      if (!mounted) return;
      setState(() {
        _specsError = error;
        _specs = null;
        _specsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = widget.model.string(VpicFields.modelName);
    final year = widget.queryYear;
    return Scaffold(
      appBar: AppBar(
        title: name == null ? Text(l10n.details) : SourceText(name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SectionCard(
            title: l10n.recordAsReturned,
            children: <Widget>[
              RecordFieldsView(fields: widget.model.fields),
              const SizedBox(height: 8),
              SourceCitation.of(widget.source),
            ],
          ),
          SectionCard(
            title: l10n.yourQuery,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(flex: 5, child: Text(l10n.modelYear)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Text(
                      year == null ? l10n.anyYear : '$year',
                      key: const Key('query-year'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SectionCard(
            key: const Key('canadian-specs'),
            title: l10n.canadianSpecs,
            children: _buildSpecs(context, l10n),
          ),
          SectionCard(
            key: const Key('engine-specs'),
            title: l10n.engineSpecs,
            children: <Widget>[
              NotAvailableNotice(reason: l10n.engineFilterExplanation),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: widget.onOpenVin,
                  child: Text(l10n.decodeVin),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSpecs(BuildContext context, AppLocalizations l10n) {
    if (widget.queryYear == null) {
      return <Widget>[NotAvailableNotice(reason: l10n.requiresYear)];
    }
    if (_specsLoading) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final error = _specsError;
    if (error != null) {
      return <Widget>[SourceErrorNotice(error: error, onRetry: _loadSpecs)];
    }
    final specs = _specs;
    if (specs == null) {
      return const <Widget>[NotAvailableText()];
    }
    final theme = Theme.of(context);
    final criteria = specs.data.searchCriteria;
    final entries = specs.data.results;
    return <Widget>[
      if (entries.isEmpty)
        NotAvailableNotice(reason: l10n.noResultsFromSource)
      else
        Text(
          l10n.results(entries.length),
          key: const Key('specs-count'),
          style: theme.textTheme.labelLarge,
        ),
      if (criteria != null) ...<Widget>[
        const SizedBox(height: 4),
        Text(l10n.searchCriteria, style: theme.textTheme.bodySmall),
        SourceText(criteria, style: theme.textTheme.bodySmall),
      ],
      for (var i = 0; i < entries.length; i++) ...<Widget>[
        const Divider(height: 24),
        Text(l10n.entry(i + 1), style: theme.textTheme.titleSmall),
        RecordFieldsView(fields: canadianSpecFields(entries[i])),
      ],
      const SizedBox(height: 8),
      SourceCitation.of(
        specs,
        onRefresh: () => _loadSpecs(forceRefresh: true),
      ),
    ];
  }
}
