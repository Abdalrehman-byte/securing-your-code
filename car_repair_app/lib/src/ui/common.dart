import 'package:material_ui/material_ui.dart';

import '../data/vpic_models.dart';
import '../data/vpic_repository.dart';
import '../l10n/app_localizations.dart';

/// `yyyy-MM-dd HH:mm` in the device's local time.
String formatTimestamp(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// Text that came from a data source. It is always laid out left-to-right so
/// that it reads exactly as returned, also inside the Arabic (RTL) layout.
class SourceText extends StatelessWidget {
  const SourceText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Text(
      text,
      textDirection: TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      style: style,
    );
  }
}

/// The localized "Not available" marker.
class NotAvailableText extends StatelessWidget {
  const NotAvailableText({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context).notAvailable,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.outline,
      ),
    );
  }
}

/// "Not available" with the reason underneath.
class NotAvailableNotice extends StatelessWidget {
  const NotAvailableNotice({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppLocalizations.of(context).notAvailable,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(reason, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Citation shown next to every piece of source data: the source name, the
/// exact request URL, when it was downloaded and whether it is a saved copy.
class SourceCitation extends StatelessWidget {
  const SourceCitation({
    super.key,
    required this.url,
    required this.fetchedAt,
    required this.origin,
    this.onRefresh,
  });

  SourceCitation.of(Sourced<Object?> sourced, {super.key, this.onRefresh})
      : url = sourced.url,
        fetchedAt = sourced.fetchedAt,
        origin = sourced.origin;

  final Uri url;
  final DateTime fetchedAt;
  final DataOrigin origin;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final String originLabel;
    switch (origin) {
      case DataOrigin.network:
        originLabel = l10n.originNetwork;
      case DataOrigin.cache:
        originLabel = l10n.originCache;
      case DataOrigin.staleCache:
        originLabel = l10n.originStale;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${l10n.source}: ${l10n.sourceName}',
                  style: small?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                SourceText(url.toString(), style: small),
                const SizedBox(height: 2),
                Text(
                  // The timestamp is wrapped in a left-to-right isolate so
                  // that Arabic (RTL) text cannot reorder it into what
                  // would read as day-month-year.
                  '${l10n.fetched}: \u2066${formatTimestamp(fetchedAt)}\u2069 '
                  '($originLabel)',
                  key: ValueKey<String>('origin-${origin.name}'),
                  style: small,
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              tooltip: l10n.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
            ),
        ],
      ),
    );
  }
}

/// Shown when the source could not provide data.
class SourceErrorNotice extends StatelessWidget {
  const SourceErrorNotice({super.key, required this.error, this.onRetry});

  final VpicException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final String reason;
    switch (error.kind) {
      case VpicErrorKind.offline:
        reason = l10n.errorOffline;
      case VpicErrorKind.http:
        reason = '${l10n.errorHttp} (${error.detail})';
      case VpicErrorKind.badResponse:
        reason = l10n.errorBadResponse;
    }
    return Column(
      key: ValueKey<String>('error-${error.kind.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NotAvailableNotice(reason: reason),
        SourceText(error.url.toString(), style: theme.textTheme.bodySmall),
        if (onRetry != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ),
      ],
    );
  }
}

/// Field/value rows of a source record, in the source order. A field with no
/// data shows "Not available" (or is skipped when [hideEmpty] is set).
class RecordFieldsView extends StatelessWidget {
  const RecordFieldsView({
    super.key,
    required this.fields,
    this.hideEmpty = false,
  });

  final List<MapEntry<String, Object?>> fields;
  final bool hideEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final rows = <Widget>[];
    for (final field in fields) {
      final value = vpicDisplayValue(field.value);
      if (value == null && hideEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: SourceText(field.key, style: labelStyle),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: value == null
                    ? const NotAvailableText()
                    : SourceText(value, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// A titled block of content.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
