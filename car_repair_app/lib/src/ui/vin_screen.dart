import 'package:flutter/material.dart';

import '../data/saved_vehicles.dart';
import '../data/search.dart';
import '../data/vpic_models.dart';
import '../data/vpic_repository.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';
import 'record_screen.dart';

/// Decodes a VIN with vPIC `DecodeVinValues` (the only vPIC call that returns
/// engine data), lets the user save the result, and filters the saved
/// vehicles by engine type using the source field `FuelTypePrimary`.
class VinScreen extends StatefulWidget {
  const VinScreen({
    super.key,
    required this.repository,
    required this.savedVehicles,
  });

  final VpicRepository repository;
  final SavedVehiclesStore savedVehicles;

  @override
  State<VinScreen> createState() => _VinScreenState();
}

class _VinScreenState extends State<VinScreen> {
  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  bool _vinInvalid = false;
  bool _yearInvalid = false;
  bool _loading = false;
  Sourced<VpicResponse>? _result;
  VpicException? _error;

  List<SavedVehicle> _saved = const <SavedVehicle>[];
  bool _engineFilterOn = false;
  String? _engineFilterValue;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _vinController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final saved = await widget.savedVehicles.load();
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<void> _decode({bool forceRefresh = false}) async {
    final vin = normalizeVin(_vinController.text);
    int? year;
    var yearInvalid = false;
    if (_yearController.text.trim().isNotEmpty) {
      year = parseModelYear(_yearController.text);
      yearInvalid = year == null;
    }
    if (vin == null || yearInvalid) {
      setState(() {
        _vinInvalid = vin == null;
        _yearInvalid = yearInvalid;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _vinInvalid = false;
      _yearInvalid = false;
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.decodeVin(
        vin,
        modelYear: year,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on VpicException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _result = null;
        _loading = false;
      });
    }
  }

  Future<void> _save(Sourced<VpicResponse> result, VpicRecord record) async {
    final saved = await widget.savedVehicles.add(
      SavedVehicle(url: result.url, fetchedAt: result.fetchedAt, record: record),
    );
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<void> _remove(SavedVehicle vehicle) async {
    final saved = await widget.savedVehicles.remove(vehicle.url);
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  bool _isSaved(Uri url) => _saved.any((vehicle) => vehicle.url == url);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TextField(
          key: const Key('vin-field'),
          controller: _vinController,
          maxLength: 17,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.vin,
            helperText: l10n.vinHelper,
            helperMaxLines: 2,
            errorText: _vinInvalid ? l10n.invalidVin : null,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('vin-year-field'),
          controller: _yearController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: l10n.modelYear,
            errorText: _yearInvalid ? l10n.invalidYear : null,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('decode-button'),
          onPressed: _loading ? null : _decode,
          icon: const Icon(Icons.search),
          label: Text(l10n.decode),
        ),
        const SizedBox(height: 16),
        ..._buildResult(context, l10n),
        const Divider(height: 32),
        Text(l10n.savedVehicles, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._buildSaved(context, l10n),
      ],
    );
  }

  List<Widget> _buildResult(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final error = _error;
    if (error != null) {
      return <Widget>[SourceErrorNotice(error: error, onRetry: _decode)];
    }
    final result = _result;
    if (result == null) return const <Widget>[];
    final theme = Theme.of(context);
    final message = result.data.message;
    final records = result.data.results;
    return <Widget>[
      SourceCitation.of(result, onRefresh: () => _decode(forceRefresh: true)),
      const SizedBox(height: 8),
      if (message != null) ...<Widget>[
        Text(l10n.messageFromSource, style: theme.textTheme.labelLarge),
        SourceText(message, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
      ],
      if (records.isEmpty)
        NotAvailableNotice(reason: l10n.noResultsFromSource),
      for (final record in records)
        SectionCard(
          title: l10n.recordAsReturned,
          children: <Widget>[
            DecodedRecordView(record: record),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _isSaved(result.url)
                  ? TextButton.icon(
                      key: const Key('saved-indicator'),
                      onPressed: null,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.saved),
                    )
                  : FilledButton.tonalIcon(
                      key: const Key('save-button'),
                      onPressed: () => _save(result, record),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(l10n.save),
                    ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _buildSaved(BuildContext context, AppLocalizations l10n) {
    if (_saved.isEmpty) {
      return <Widget>[
        Text(l10n.noSavedVehicles, key: const Key('no-saved-vehicles')),
      ];
    }
    final theme = Theme.of(context);
    final values = distinctFieldValues(
      _saved.map((vehicle) => vehicle.record),
      VpicFields.fuelTypePrimary,
    );
    // Drop a filter whose value no longer exists among the saved vehicles.
    final filterOn = _engineFilterOn && values.contains(_engineFilterValue);
    final shown = filterOn
        ? filterByFieldValue<SavedVehicle>(
            _saved,
            (vehicle) => vehicle.record,
            VpicFields.fuelTypePrimary,
            _engineFilterValue,
          )
        : _saved;
    return <Widget>[
      Text(l10n.engineFilterField, style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          ChoiceChip(
            key: const Key('engine-all'),
            label: Text(l10n.all),
            selected: !filterOn,
            onSelected: (_) => setState(() => _engineFilterOn = false),
          ),
          for (final value in values)
            ChoiceChip(
              key: ValueKey<String>('engine-${value ?? 'not-available'}'),
              label: value == null ? Text(l10n.notAvailable) : SourceText(value),
              selected: filterOn && _engineFilterValue == value,
              onSelected: (_) => setState(() {
                _engineFilterOn = true;
                _engineFilterValue = value;
              }),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        filterOn
            ? l10n.showingOf(shown.length, _saved.length)
            : l10n.results(_saved.length),
        key: const Key('saved-count'),
        style: theme.textTheme.bodySmall,
      ),
      for (final vehicle in shown) _buildSavedTile(context, l10n, vehicle),
    ];
  }

  Widget _buildSavedTile(
    BuildContext context,
    AppLocalizations l10n,
    SavedVehicle vehicle,
  ) {
    final record = vehicle.record;
    final vin = record.string(VpicFields.vin);
    final summary = <String>[
      for (final field in const <String>[
        VpicFields.make,
        VpicFields.model,
        VpicFields.modelYear,
        VpicFields.fuelTypePrimary,
      ])
        if (record.string(field) case final String value) value,
    ];
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        key: ValueKey<String>('saved-${vehicle.url}'),
        title: vin == null ? const NotAvailableText() : SourceText(vin),
        subtitle: summary.isEmpty
            ? const NotAvailableText()
            : SourceText(summary.join(' | ')),
        trailing: IconButton(
          tooltip: l10n.remove,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _remove(vehicle),
        ),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RecordScreen(
                title: vin,
                record: record,
                url: vehicle.url,
                fetchedAt: vehicle.fetchedAt,
              ),
            ),
          );
        },
      ),
    );
  }
}
