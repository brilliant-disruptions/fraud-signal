import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;
    final org = ref.watch(currentOrgProvider).value;
    final summary = ref.watch(dashboardProvider);
    final leads = ref.watch(leadsProvider).value ?? const [];
    final screens = ref.watch(screensProvider).value ?? const [];

    final topLeads = leads
        .where((l) => l.status == LeadStatus.pendingReview || l.status == LeadStatus.signedOff || l.status == LeadStatus.licensed)
        .take(3)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(org?.name ?? 'Fraud Signal'),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            if (user != null && org != null)
              Text(
                '${user.displayName} · ${user.role.label} · ${org.offer.label}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            const RiskIndicatorNotice(),
            const SizedBox(height: 16),
            summary.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => LoadingOrError(error: e),
              data: (s) => s == null ? const SizedBox.shrink() : _SummaryGrid(summary: s, org: org),
            ),
            if (org?.offer == OfferTier.internal || org?.offer == OfferTier.exclusiveCasePackage || org?.offer == OfferTier.screeningSubscription) ...[
              SectionHeader(
                org?.offer == OfferTier.exclusiveCasePackage ? 'Your licensed leads' : 'Top of the queue',
                subtitle: 'Strongest tier first, then dollars at issue',
                trailing: TextButton(onPressed: () => context.go('/leads'), child: const Text('All leads')),
              ),
              if (topLeads.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No leads above the gate right now.'),
                  ),
                )
              else
                for (final lead in topLeads) ...[
                  LeadCard(lead: lead),
                  const SizedBox(height: 8),
                ],
            ],
            if (org != null && org.offer != OfferTier.exclusiveCasePackage) ...[
              SectionHeader(
                'Screens',
                subtitle: org.offer == OfferTier.complianceSelfAudit
                    ? 'Self-audits on your verified NPIs'
                    : 'Diligence screens and self-audits',
                trailing: TextButton(onPressed: () => context.go('/screens'), child: const Text('All screens')),
              ),
              if (screens.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('Run your first screen'),
                    subtitle: const Text('Enter NPIs to get an exposure report with evidence cards.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/screens/new'),
                  ),
                )
              else
                for (final s in screens.take(2)) ...[
                  _ScreenRow(request: s),
                  const SizedBox(height: 8),
                ],
            ],
            const SectionHeader('Method', subtitle: 'Rules before statistics. Every flag carries an evidence card.'),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.rule_folder_outlined),
                  title: const Text('Rules catalog'),
                  subtitle: const Text('15 signals across three tiers, with measured lift'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/rules'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.query_stats_outlined),
                  title: const Text('Back-test results'),
                  subtitle: const Text('2019 Medicare scored against 2020 to 2026 exclusions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/rules/backtest'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.balance_outlined),
                  title: const Text('Bias audit'),
                  subtitle: Text(summary.value == null
                      ? 'Flag rates across ZIP demographics, every run'
                      : 'Latest run: ${summary.value!.lastAuditVerdict.label}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/rules/bias-audit'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.public_outlined),
                  title: const Text('Aggregate heatmap'),
                  subtitle: const Text('Flag rates by state. No names. The only public layer.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/rules/heatmap'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.org});
  final DashboardSummary summary;
  final Organization? org;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      if (org?.offer == OfferTier.internal)
        StatTile(
          label: 'Pending review',
          value: '${summary.leadsPendingReview}',
          caption: 'Need analyst sign-off',
          accent: AppTheme.amber,
          onTap: () => context.go('/leads'),
        ),
      StatTile(
        label: 'Tier 1 findings',
        value: '${summary.tier1Verified}',
        caption: 'Hard-rule violations',
        accent: tierColor(Tier.hardRule, scheme),
        onTap: () => context.go('/leads'),
      ),
      if (org?.offer == OfferTier.internal || org?.offer == OfferTier.screeningSubscription)
        StatTile(label: 'Watch list', value: '${summary.watchList}', caption: 'Below the lead gate'),
      if (org?.offer == OfferTier.internal || org?.offer == OfferTier.exclusiveCasePackage)
        StatTile(label: 'Licensed', value: '${summary.licensed}', caption: 'One firm per lead'),
      StatTile(
        label: 'Records scored',
        value: fmt.count(summary.recordsScored),
        caption: 'Refreshed ${fmt.date(summary.lastRefresh)}',
      ),
      StatTile(
        label: 'Ruleset',
        value: summary.rulesetVersion,
        caption: 'Bias audit: ${summary.lastAuditVerdict.label}',
        accent: verdictColor(summary.lastAuditVerdict, scheme),
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 106,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) => tiles[i],
      );
    });
  }
}

class _ScreenRow extends StatelessWidget {
  const _ScreenRow({required this.request});
  final ScreenRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(request.status == ScreenStatus.complete ? Icons.task_alt : Icons.hourglass_top_outlined),
        title: Text(request.targetLabel ?? request.kind.label),
        subtitle: Text('${request.kind.label} · ${request.npis.length} NPIs · ${request.status.label}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/screens/${request.id}'),
      ),
    );
  }
}

/// Compact lead row used on the home screen and the leads list.
class LeadCard extends StatelessWidget {
  const LeadCard({super.key, required this.lead});
  final Lead lead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/leads/${lead.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: TierBadge(lead.strongestTier)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lead.program.label,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(fmt.moneyCompact(lead.dollarsAtIssue),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(lead.hits.first.headline,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text('${lead.id} · ${lead.entityRef} · ${lead.state} · ${lead.specialtyOrIndustry}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              StatusChip(lead.status),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (final h in lead.hits) TierBadge(h.tier, compact: true),
              Text('${lead.hits.length} signal${lead.hits.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }
}
