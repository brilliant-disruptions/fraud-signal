import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class BiasAuditScreen extends ConsumerWidget {
  const BiasAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final audit = ref.watch(biasAuditProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bias audit')),
      body: audit.when(
        loading: () => const LoadingOrError(),
        error: (e, _) => LoadingOrError(error: e),
        data: (run) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Row(children: [
              VerdictChip(run.overall),
              const SizedBox(width: 10),
              Text('Run ${run.id} · ${fmt.dateTime(run.runAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            Text(
              'Each run compares flag rates across ZIP codes against Census demographics for those areas. A rule that skews without a behavioral reason is fixed or dropped. This report ships with the data.',
              style: theme.textTheme.bodyMedium,
            ),
            const SectionHeader('Inputs that never feed a score'),
            Card(
              child: Column(children: [
                for (final s in run.inputsBanned)
                  ListTile(dense: true, leading: const Icon(Icons.block, size: 18), title: Text(s)),
              ]),
            ),
            SectionHeader('Flag rate per 1,000 records', subtitle: 'ZIPs above vs. below the median minority share · ${run.censusVintage}'),
            for (final row in run.rows) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(row.ruleName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
                      VerdictChip(row.verdict),
                    ]),
                    const SizedBox(height: 10),
                    _RateBar(label: 'Above median', value: row.flagRateHighMinorityZips, max: _max(run.rows), color: verdictColor(row.verdict, theme.colorScheme)),
                    const SizedBox(height: 6),
                    _RateBar(label: 'Below median', value: row.flagRateOtherZips, max: _max(run.rows), color: theme.colorScheme.outline),
                    const SizedBox(height: 8),
                    Text(row.note,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text('Ruleset ${run.rulesetVersion}. Watch means the ratio is above 1.2 with a plausible behavioral reason; fail means it is not explained and the rule is pulled.',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  double _max(Iterable rows) {
    var m = 0.0;
    for (final r in rows) {
      if (r.flagRateHighMinorityZips > m) m = r.flagRateHighMinorityZips;
      if (r.flagRateOtherZips > m) m = r.flagRateOtherZips;
    }
    return m == 0 ? 1 : m;
  }
}

class _RateBar extends StatelessWidget {
  const _RateBar({required this.label, required this.value, required this.max, required this.color});
  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      SizedBox(width: 92, child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: (value / max).clamp(0, 1), minHeight: 10, color: color, backgroundColor: theme.colorScheme.surfaceContainerHighest),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 40, child: Text(value.toStringAsFixed(2), textAlign: TextAlign.right, style: theme.textTheme.labelMedium)),
    ]);
  }
}
