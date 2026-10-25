import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/demo_data.dart' show demoOrgs;
import '../../domain/models.dart';
import '../../domain/rules_engine.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/watermark.dart';

/// The evidence card. Opening it logs a timestamped view; the first view by
/// a licensee is the documented handoff.
class LeadDetailScreen extends ConsumerStatefulWidget {
  const LeadDetailScreen({super.key, required this.leadId});
  final String leadId;

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  bool _logged = false;

  Future<void> _logOnce(Lead lead, AppUser user) async {
    if (_logged) return;
    _logged = true;
    await ref.read(repositoryProvider).logLeadView(lead, user);
    ref.invalidate(accessLogProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;
    final org = ref.watch(currentOrgProvider).value;
    final leadAsync = ref.watch(leadProvider(widget.leadId));
    final rules = ref.watch(rulesProvider).value ?? const <Rule>[];

    return leadAsync.when(
      loading: () => const Scaffold(body: LoadingOrError()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: LoadingOrError(error: e)),
      data: (lead) {
        if (lead == null || user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.lock_outline, title: 'Not available', message: 'This lead is not visible to your organization.'),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _logOnce(lead, user));
        final gate = const RulesEngine().leadGate(
          program: lead.program,
          tier1Count: lead.tier1Count,
          tier2Count: lead.tier2Count,
          dollarsAtIssue: lead.dollarsAtIssue,
        );
        final watermark = '${user.email} · ${fmt.dateTimeUtc(DateTime.now())} · ${lead.id}';

        return Scaffold(
          appBar: AppBar(
            title: Text(lead.id),
            actions: [
              IconButton(
                tooltip: 'Copy evidence card (watermarked)',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () => _export(lead, user, watermark),
              ),
            ],
          ),
          body: Watermarked(
            text: watermark,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  TierBadge(lead.strongestTier),
                  StatusChip(lead.status),
                  Text(lead.program.label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 12),
                Text(fmt.money(lead.dollarsAtIssue), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('dollars at issue', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                KeyValueTable({
                  lead.entityKind: lead.entityRef,
                  'State': lead.state,
                  lead.program == Program.ppp ? 'Industry' : 'Specialty': lead.specialtyOrIndustry,
                  'Created': fmt.dateTime(lead.createdAt),
                  if (lead.signedOffBy != null) 'Signed off': '${lead.signedOffBy} · ${fmt.dateTime(lead.signedOffAt!)}',
                  if (lead.licensedToOrgId != null) 'Licensed to': _orgName(lead.licensedToOrgId!),
                  if (lead.firstViewedAt != null) 'First viewed': fmt.dateTimeUtc(lead.firstViewedAt!),
                }),
                const SizedBox(height: 8),
                const RiskIndicatorNotice(dense: true),

                // Lead gate
                SectionHeader('Lead gate', subtitle: gate.reason),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      _GateCell(label: 'Tier 1', value: '${gate.tier1Count}', ok: gate.tier1Count >= 1),
                      _GateCell(label: 'Tier 2', value: '${gate.tier2Count}', ok: gate.tier2Count >= 2),
                      _GateCell(label: 'Tier 3', value: '${lead.tier3Count}', ok: null),
                      _GateCell(
                        label: 'Floor ${fmt.moneyCompact(gate.materialityFloor)}',
                        value: gate.dollarsAtIssue >= gate.materialityFloor ? 'Met' : 'Below',
                        ok: gate.dollarsAtIssue >= gate.materialityFloor,
                      ),
                    ]),
                  ),
                ),

                // Signals
                SectionHeader('Signals', subtitle: '${lead.hits.length} rule${lead.hits.length == 1 ? '' : 's'} fired. Raw values are from the source record.'),
                for (final hit in lead.hits) ...[
                  _SignalCard(hit: hit, rule: rules.where((r) => r.id == hit.ruleId).firstOrNull),
                  const SizedBox(height: 8),
                ],

                // Innocent explanations
                const SectionHeader('Innocent-explanation checklist', subtitle: 'What a defense lawyer would raise, and why it fails or stays open.'),
                Card(
                  child: Column(children: [
                    for (var i = 0; i < lead.innocentExplanations.length; i++) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _ExplanationTile(lead.innocentExplanations[i]),
                    ],
                  ]),
                ),

                // Provenance
                const SectionHeader('Audit trail', subtitle: 'Anyone can re-run this and get the same answer.'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: KeyValueTable({
                      'Source': lead.provenance.sourceName,
                      'URL': lead.provenance.sourceUrl,
                      'Dataset': lead.provenance.datasetVersion,
                      'Query': lead.provenance.query,
                      'Rows': fmt.count(lead.provenance.rowCount),
                      'SHA-256': lead.provenance.sha256,
                      'Pulled': fmt.dateTimeUtc(lead.provenance.pulledAt),
                      'Ruleset': lead.provenance.rulesetVersion,
                    }, monospaceValues: true),
                  ),
                ),

                if (lead.investigationNotes != null) ...[
                  const SectionHeader('Investigation notes'),
                  Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(lead.investigationNotes!))),
                ],

                // Reviewer actions
                if (user.role.canSignOff && org?.offer == OfferTier.internal) ...[
                  const SectionHeader('Review', subtitle: 'No lead leaves the system without a sign-off. None is ever published.'),
                  _ReviewerActions(lead: lead, user: user),
                ],
                const SizedBox(height: 16),
                Text(
                  'Viewed by ${user.email}. This view is logged. Exports carry the same watermark.'
                  '${org != null && !org.offer.allowsBulkExport ? ' Bulk export is not available on the ${org.offer.label} plan.' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _orgName(String id) => demoOrgs.where((o) => o.id == id).firstOrNull?.name ?? id;

  Future<void> _export(Lead lead, AppUser user, String watermark) async {
    final buf = StringBuffer()
      ..writeln('FRAUD SIGNAL EVIDENCE CARD · ${lead.id}')
      ..writeln('Risk indicators with evidence, not accusations. Confidential. Do not publish or contact the flagged party.')
      ..writeln('Watermark: $watermark')
      ..writeln()
      ..writeln('${lead.entityKind}: ${lead.entityRef} · ${lead.state} · ${lead.specialtyOrIndustry}')
      ..writeln('Program: ${lead.program.label} · Dollars at issue: ${fmt.money(lead.dollarsAtIssue)} · Status: ${lead.status.label}')
      ..writeln();
    for (final h in lead.hits) {
      buf.writeln('[Tier ${h.tier.number}] ${h.headline}');
      for (final e in h.rawValues.entries) {
        buf.writeln('   ${e.key}: ${e.value}');
      }
    }
    buf
      ..writeln()
      ..writeln('Innocent explanations considered:');
    for (final e in lead.innocentExplanations) {
      buf.writeln(' - ${e.explanation}: ${e.whyItFails}');
    }
    final p = lead.provenance;
    buf
      ..writeln()
      ..writeln('Provenance: ${p.sourceName} · ${p.datasetVersion} · ${p.query} · ${p.rowCount} rows · ${p.sha256} · pulled ${fmt.dateTimeUtc(p.pulledAt)} · ruleset ${p.rulesetVersion}');
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    await ref.read(repositoryProvider).logExport(lead, user);
    ref.invalidate(accessLogProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watermarked evidence card copied. Export logged.')));
    }
  }
}

class _GateCell extends StatelessWidget {
  const _GateCell({required this.label, required this.value, required this.ok});
  final String label;
  final String value;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ok == null
        ? theme.colorScheme.onSurfaceVariant
        : ok!
            ? const Color(0xFF2E7D32)
            : theme.colorScheme.outline;
    return Expanded(
      child: Column(children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.hit, required this.rule});
  final SignalHit hit;
  final Rule? rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TierBadge(hit.tier),
            const SizedBox(width: 8),
            if (rule?.lift != null)
              Text('${fmt.lift(rule!.lift!)} chance (${fmt.lift(rule!.liftLow!)} to ${fmt.lift(rule!.liftHigh!)})',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          Text(hit.headline, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          if (rule != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => context.push('/rules/${rule!.id}'),
              child: Text(rule!.name,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
            ),
          ],
          if (hit.peerDistribution != null && hit.subjectValue != null) ...[
            const SizedBox(height: 12),
            PeerDistributionChart(peers: hit.peerDistribution!, subject: hit.subjectValue!),
          ],
          const SizedBox(height: 8),
          const Divider(),
          KeyValueTable(hit.rawValues),
        ]),
      ),
    );
  }
}

class _ExplanationTile extends StatelessWidget {
  const _ExplanationTile(this.e);
  final InnocentExplanation e;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = e.whyItFails.startsWith('Open') || e.whyItFails.startsWith('Plausible') || e.whyItFails.startsWith('Likely') || e.whyItFails.startsWith('Unknown');
    return ListTile(
      leading: Icon(open ? Icons.help_outline : Icons.close, color: open ? AppTheme.amber : theme.colorScheme.onSurfaceVariant),
      title: Text(e.explanation, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(e.whyItFails),
    );
  }
}

class _ReviewerActions extends ConsumerStatefulWidget {
  const _ReviewerActions({required this.lead, required this.user});
  final Lead lead;
  final AppUser user;

  @override
  ConsumerState<_ReviewerActions> createState() => _ReviewerActionsState();
}

class _ReviewerActionsState extends ConsumerState<_ReviewerActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(accessLogProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    final lead = widget.lead;
    final buyers = demoOrgs.where((o) => o.offer == OfferTier.exclusiveCasePackage).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          if (lead.status == LeadStatus.pendingReview || lead.status == LeadStatus.watchList)
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(() => repo.signOff(lead, widget.user)),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Sign off'),
            ),
          if (lead.status == LeadStatus.signedOff)
            FilledButton.tonalIcon(
              onPressed: _busy || buyers.isEmpty
                  ? null
                  : () async {
                      final to = await showModalBottomSheet<Organization>(
                        context: context,
                        showDragHandle: true,
                        builder: (ctx) => SafeArea(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const ListTile(title: Text('License exclusively to'), subtitle: Text('One firm per lead. The first view stamps the handoff.')),
                            for (final o in buyers)
                              ListTile(
                                leading: const Icon(Icons.business_outlined),
                                title: Text(o.name),
                                subtitle: Text(o.offer.label),
                                onTap: () => Navigator.pop(ctx, o),
                              ),
                          ]),
                        ),
                      );
                      if (to != null) await _run(() => repo.license(lead, to, widget.user));
                    },
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('License'),
            ),
          if (lead.status != LeadStatus.closed && lead.status != LeadStatus.licensed)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final reason = await _askReason(context);
                      if (reason != null && reason.trim().isNotEmpty) {
                        await _run(() => repo.closeLead(lead, widget.user, reason.trim()));
                      }
                    },
              icon: const Icon(Icons.do_not_disturb_on_outlined),
              label: const Text('Close as explained'),
            ),
        ]),
      ),
    );
  }

  Future<String?> _askReason(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Which innocent explanation held?'),
        content: TextField(controller: c, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. Group billing confirmed via reassignment records')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Close lead')),
        ],
      ),
    );
  }
}
