import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/models.dart';

class TierBadge extends StatelessWidget {
  const TierBadge(this.tier, {super.key, this.compact = false});
  final Tier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tierColor(tier, scheme);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        compact ? 'T${tier.number}' : 'Tier ${tier.number} · ${tier.label}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final LeadStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(status, scheme);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(status.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
    ]);
  }
}

class VerdictChip extends StatelessWidget {
  const VerdictChip(this.verdict, {super.key});
  final AuditVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = verdictColor(verdict, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Text(verdict.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption, this.accent, this.onTap});
  final String label;
  final String value;
  final String? caption;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: accent ?? theme.colorScheme.onSurface, height: 1.1)),
            ),
            if (caption case final caption?) ...[
              const SizedBox(height: 2),
              Text(caption,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Key/value rows for raw values and provenance.
class KeyValueTable extends StatelessWidget {
  const KeyValueTable(this.entries, {super.key, this.monospaceValues = false});
  final Map<String, String> entries;
  final bool monospaceValues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final e in entries.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 130,
                child: Text(e.key,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  e.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: monospaceValues ? 'monospace' : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

/// Standing disclaimer. The product sells risk indicators with evidence,
/// never accusations.
class RiskIndicatorNotice extends StatelessWidget {
  const RiskIndicatorNotice({super.key, this.dense = false});
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(dense ? 10 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Risk indicators with evidence, not accusations. Nothing here is a finding of fraud. '
            'Do not publish or contact any flagged party.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
          ),
        ),
      ]),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(Icons.science_outlined, size: 16, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo build. Every identifier is synthetic. Any email signs in; the sign-in screen lists the demo roles.',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class LoadingOrError extends StatelessWidget {
  const LoadingOrError({super.key, this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return EmptyState(icon: Icons.error_outline, title: 'Could not load', message: '$error');
    }
    return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
  }
}
