import 'package:flutter/material.dart';

import '../data/search.dart';
import '../data/vpic_models.dart';
import '../data/vpic_repository.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';

/// Searchable list of every make returned by vPIC `GetAllMakes`.
/// Pops with the chosen record.
class MakePickerScreen extends StatefulWidget {
  const MakePickerScreen({super.key, required this.repository});

  final VpicRepository repository;

  @override
  State<MakePickerScreen> createState() => _MakePickerScreenState();
}

class _MakePickerScreenState extends State<MakePickerScreen> {
  Sourced<VpicResponse>? _makes;
  VpicException? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final makes = await widget.repository.allMakes(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _makes = makes;
        _loading = false;
      });
    } on VpicException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _makes = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.selectMake)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('make-search'),
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchMakes,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(child: _buildBody(context, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SourceErrorNotice(error: error, onRetry: _load),
      );
    }
    final makes = _makes!;
    final all = makes.data.results;
    final matches = searchRecords(all, VpicFields.makeName, _query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SourceCitation.of(
            makes,
            onRefresh: () => _load(forceRefresh: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            _query.trim().isEmpty
                ? l10n.results(all.length)
                : l10n.showingOf(matches.length, all.length),
            key: const Key('make-count'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: NotAvailableNotice(
                    reason: all.isEmpty
                        ? l10n.noResultsFromSource
                        : l10n.noMatchInResults,
                  ),
                )
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final make = matches[index];
                    final name = make.string(VpicFields.makeName);
                    final id = make.string(VpicFields.makeId);
                    return ListTile(
                      key: ValueKey<String>('make-$id'),
                      title: name == null
                          ? const NotAvailableText()
                          : SourceText(name),
                      subtitle: id == null
                          ? null
                          : SourceText('${VpicFields.makeId}: $id'),
                      onTap: () => Navigator.of(context).pop(make),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
