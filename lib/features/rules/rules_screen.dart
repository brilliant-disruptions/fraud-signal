import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rulesAsync = ref.watch(rulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Method')),
      body: rulesAsync.when(
        loading: () => const LoadingOrError(),
        error: (e, _) => LoadingOrError(error: e),
        data: (rules) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(children: [
                Expanded(child: _NavTile(icon: Icons.query_stats_outlined, label: 'Back-test', onTap: () => context.go('/rules/backtest'))),
                const SizedBox(width: 8),
                Expanded(child: _NavTile(icon: Icons.balance_outlined, label: 'Bias audit', onTap: () => context.go('/rules/bias-audit'))),
                const SizedBox(width: 8),
                Expanded(child: _NavTile(icon: Icons.public_outlined, label: 'Heatmap', onTap: () => context.go('/rules/heatmap'))),
              ]),
              const SizedBox(height: 4),
              for (final tier in Tier.values) ...[
                SectionHeader('Tier ${tier.number} · ${tier.label}', subtitle: tier.description),
                for (final r in rules.where((r) => r.tier == tier)) ...[
                  _RuleTile(rule: r),
                  const SizedBox(height: 8),
                ],
              ],
              const SectionHeader('Lead gate'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'A record becomes a lead only with at least one Tier 1 hit, or at least two independent Tier 2 signals, '
                    'plus dollars at issue above a materiality floor (\$500K for Medicare, \$1M for PPP). '
                    'Everything below the gate stays internal as a watch list.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.labelMedium),
          ]),
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule});
  final Rule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = rule.status == RuleStatus.dropped;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/rules/${rule.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(rule.program.label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(),
              _StatusPill(rule.status),
            ]),
            const SizedBox(height: 6),
            Text(rule.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: dim ? TextDecoration.lineThrough : null,
                  color: dim ? theme.colorScheme.onSurfaceVariant : null,
                )),
            if (rule.lift != null) ...[
              const SizedBox(height: 6),
              Text('${fmt.lift(rule.lift!)} chance · 95% interval ${fmt.lift(rule.liftLow!)} to ${fmt.lift(rule.liftHigh!)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: rule.liftLow! > 1 ? theme.colorScheme.primary : theme.colorScheme.outline, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final RuleStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      RuleStatus.active => const Color(0xFF2E7D32),
      RuleStatus.notValidated => AppTheme.amber,
      RuleStatus.dropped => scheme.outline,
      RuleStatus.planned => scheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(status.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class RuleDetailScreen extends ConsumerWidget {
  const RuleDetailScreen({super.key, required this.ruleId});
  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(rulesProvider).value ?? const <Rule>[];
    final rule = rules.where((r) => r.id == ruleId).firstOrNull;
    final leads = ref.watch(leadsProvider).value ?? const <Lead>[];
    if (rule == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingOrError());
    }
    final firing = leads.where((l) => l.hits.any((h) => h.ruleId == rule.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Tier ${rule.tier.number} rule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(children: [TierBadge(rule.tier), const SizedBox(width: 8), _StatusPill(rule.status)]),
          const SizedBox(height: 10),
          Text(rule.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(rule.program.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SectionHeader('Why it holds up'),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(rule.whyItHolds))),
          if (rule.lift != null) ...[
            const SectionHeader('Measured precision', subtitle: 'Back-tested against later OIG exclusions. A floor, since labels undercount.'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(child: _Metric('Lift', fmt.lift(rule.lift!))),
                  Expanded(child: _Metric('Low', fmt.lift(rule.liftLow!))),
                  Expanded(child: _Metric('High', fmt.lift(rule.liftHigh!))),
                  Expanded(child: _Metric('Significant', rule.liftLow! > 1 ? 'Yes' : 'No')),
                ]),
              ),
            ),
          ],
          if (rule.statusNote != null) ...[
            const SectionHeader('Status note'),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(rule.statusNote!))),
          ],
          if (firing.isNotEmpty) ...[
            SectionHeader('Fires on', subtitle: '${firing.length} visible lead${firing.length == 1 ? '' : 's'}'),
            Card(
              child: Column(children: [
                for (var i = 0; i < firing.length; i++) ...[
                  if (i > 0) const Divider(indent: 16),
                  ListTile(
                    title: Text(firing[i].id),
                    subtitle: Text('${firing[i].entityRef} · ${fmt.moneyCompact(firing[i].dollarsAtIssue)}'),
                    trailing: StatusChip(firing[i].status),
                    onTap: () => context.go('/leads/${firing[i].id}'),
                  ),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}
