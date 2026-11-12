import 'package:flutter/material.dart';

import '../data/search.dart';
import '../data/vpic_models.dart';
import '../data/vpic_repository.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';
import 'make_picker_screen.dart';
import 'model_detail_screen.dart';

/// Feature 1: browse the vPIC car database by make, model year, vehicle type
/// and model name.
class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({
    super.key,
    required this.repository,
    required this.onOpenVin,
  });

  final VpicRepository repository;

  /// Opens the VIN tab (the only place vPIC returns engine data).
  final VoidCallback onOpenVin;

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  VpicRecord? _make;
  Sourced<VpicResponse>? _vehicleTypes;
  bool _vehicleTypesFailed = false;
  String? _vehicleType;
  bool _yearInvalid = false;

  bool _loading = false;
  Sourced<VpicResponse>? _result;
  int? _resultYear;
  VpicException? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _yearController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _pickMake() async {
    final picked = await Navigator.of(context).push<VpicRecord>(
      MaterialPageRoute<VpicRecord>(
        builder: (_) => MakePickerScreen(repository: widget.repository),
      ),
    );
    if (picked == null || !mounted) return;
    _requestId++;
    setState(() {
      _make = picked;
      _vehicleTypes = null;
      _vehicleTypesFailed = false;
      _vehicleType = null;
      _result = null;
      _error = null;
      _loading = false;
    });
    await _loadVehicleTypes(picked);
  }

  Future<void> _loadVehicleTypes(VpicRecord make) async {
    final makeId = make.integer(VpicFields.makeId);
    if (makeId == null) {
      setState(() => _vehicleTypesFailed = true);
      return;
    }
    try {
      final types = await widget.repository.vehicleTypesForMake(makeId);
      if (!mounted || !identical(_make, make)) return;
      setState(() => _vehicleTypes = types);
    } on VpicException {
      if (!mounted || !identical(_make, make)) return;
      setState(() => _vehicleTypesFailed = true);
    }
  }

  Future<void> _search({bool forceRefresh = false}) async {
    final makeId = _make?.integer(VpicFields.makeId);
    if (makeId == null) return;
    int? year;
    if (_yearController.text.trim().isNotEmpty) {
      year = parseModelYear(_yearController.text);
      if (year == null) {
        setState(() => _yearInvalid = true);
        return;
      }
    }
    FocusScope.of(context).unfocus();
    final requestId = ++_requestId;
    setState(() {
      _yearInvalid = false;
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.models(
        makeId: makeId,
        year: year,
        vehicleType: _vehicleType,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _result = result;
        _resultYear = year;
        _loading = false;
      });
    } on VpicException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _result = null;
        _loading = false;
      });
    }
  }

  void _openModel(VpicRecord model, Sourced<VpicResponse> source) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ModelDetailScreen(
          repository: widget.repository,
          model: model,
          source: source,
          queryYear: _resultYear,
          onOpenVin: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            widget.onOpenVin();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(child: _buildFilters(context)),
        ),
        ..._buildResults(context),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final makeName = _make?.string(VpicFields.makeName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Make
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: const Key('make-field'),
            leading: const Icon(Icons.factory_outlined),
            title: Text(l10n.make),
            subtitle: makeName == null
                ? Text(l10n.selectMake)
                : SourceText(makeName),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: _pickMake,
          ),
        ),
        const SizedBox(height: 12),
        // Model year
        TextField(
          key: const Key('year-field'),
          controller: _yearController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: l10n.modelYear,
            helperText: l10n.yearHelper,
            helperMaxLines: 3,
            errorText: _yearInvalid ? l10n.invalidYear : null,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        // Vehicle type
        Text(l10n.vehicleType, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        _buildVehicleTypes(context, l10n),
        const SizedBox(height: 12),
        // Model name
        TextField(
          key: const Key('model-filter'),
          controller: _modelController,
          decoration: InputDecoration(
            labelText: l10n.modelNameFilter,
            prefixIcon: const Icon(Icons.filter_list),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        // Engine type: not offered by the source for make/model/year.
        Card(
          key: const Key('engine-filter'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.engineType, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                const NotAvailableText(),
                const SizedBox(height: 4),
                Text(
                  l10n.engineFilterExplanation,
                  style: theme.textTheme.bodySmall,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const Key('open-vin'),
                    onPressed: widget.onOpenVin,
                    child: Text(l10n.decodeVin),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('search-button'),
          onPressed: _make == null || _loading ? null : _search,
          icon: const Icon(Icons.search),
          label: Text(l10n.search),
        ),
      ],
    );
  }

  Widget _buildVehicleTypes(BuildContext context, AppLocalizations l10n) {
    if (_make == null) {
      return Text(
        l10n.selectMakeFirst,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (_vehicleTypesFailed) return const NotAvailableText();
    final types = _vehicleTypes;
    if (types == null) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final names = <String>[
      for (final type in types.data.results)
        if (type.string(VpicFields.vehicleTypeName) case final String name)
          name,
    ];
    if (names.isEmpty) return const NotAvailableText();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            ChoiceChip(
              key: const Key('vehicle-type-all'),
              label: Text(l10n.all),
              selected: _vehicleType == null,
              onSelected: (_) => setState(() => _vehicleType = null),
            ),
            for (final name in names)
              ChoiceChip(
                key: ValueKey<String>('vehicle-type-$name'),
                label: SourceText(name),
                selected: _vehicleType == name,
                onSelected: (_) => setState(() => _vehicleType = name),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SourceCitation.of(types),
      ],
    );
  }

  List<Widget> _buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    if (_loading) {
      return const <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    final error = _error;
    if (error != null) {
      return <Widget>[
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: SourceErrorNotice(error: error, onRetry: _search),
          ),
        ),
      ];
    }
    final result = _result;
    if (result == null) return const <Widget>[];

    final all = result.data.results;
    final query = _modelController.text;
    final shown = searchRecords(all, VpicFields.modelName, query);
    return <Widget>[
      SliverPadding(
        padding: padding,
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SourceCitation.of(
                result,
                onRefresh: () => _search(forceRefresh: true),
              ),
              const SizedBox(height: 8),
              Text(
                query.trim().isEmpty
                    ? l10n.results(all.length)
                    : l10n.showingOf(shown.length, all.length),
                key: const Key('results-count'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (shown.isEmpty)
                NotAvailableNotice(
                  key: const Key('no-results'),
                  reason: all.isEmpty
                      ? l10n.noResultsFromSource
                      : l10n.noMatchInResults,
                ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final model = shown[index];
            final name = model.string(VpicFields.modelName);
            final details = <String>[
              if (model.string(VpicFields.makeName) case final String make)
                make,
              if (model.string(VpicFields.vehicleTypeName)
                  case final String type)
                type,
            ];
            return ListTile(
              key: ValueKey<String>(
                'model-${model.string(VpicFields.modelId)}',
              ),
              title:
                  name == null ? const NotAvailableText() : SourceText(name),
              subtitle:
                  details.isEmpty ? null : SourceText(details.join(' | ')),
              trailing: const Icon(Icons.info_outline),
              onTap: () => _openModel(model, result),
            );
          },
          childCount: shown.length,
        ),
      ),
    ];
  }
}
