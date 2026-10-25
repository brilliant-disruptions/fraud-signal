import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../domain/models.dart';
import '../../domain/rules_engine.dart';
import '../../widgets/common.dart';

class ScreensScreen extends ConsumerWidget {
  const ScreensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screens = ref.watch(screensProvider);
    final user = ref.watch(currentUserProvider).value;
    final org = ref.watch(currentOrgProvider).value;
    final canRun = user?.role.canRunScreens ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Screens')),
      floatingActionButton: canRun
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/screens/new'),
              icon: const Icon(Icons.add),
              label: const Text('New screen'),
            )
          : null,
      body: screens.when(
        loading: () => const LoadingOrError(),
        error: (e, _) => LoadingOrError(error: e),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No screens yet',
              message: canRun
                  ? 'Run a diligence screen on a target\'s NPIs, or a self-audit on your own.'
                  : 'Your role can view results but not run screens.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  org?.offer == OfferTier.complianceSelfAudit
                      ? 'Self-audits run only on NPIs your organization has verified it owns.'
                      : 'Diligence screens return an exposure report with all rules and evidence cards, under NDA.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }
              final s = list[i - 1];
              return Card(
                child: ListTile(
                  leading: Icon(switch (s.status) {
                    ScreenStatus.complete => Icons.task_alt,
                    ScreenStatus.failed => Icons.error_outline,
                    _ => Icons.hourglass_top_outlined,
                  }),
                  title: Text(s.targetLabel ?? s.kind.label),
                  subtitle: Text('${s.id} · ${s.kind.label} · ${s.npis.length} NPIs · ${fmt.dateTime(s.requestedAt)}'),
                  trailing: Text(s.status.label, style: theme.textTheme.labelMedium),
                  onTap: () => context.go('/screens/${s.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ScreenDetailScreen extends ConsumerWidget {
  const ScreenDetailScreen({super.key, required this.screenId});
  final String screenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = (ref.watch(screensProvider).value ?? const <ScreenRequest>[]).where((x) => x.id == screenId).firstOrNull;
    if (s == null) return Scaffold(appBar: AppBar(), body: const LoadingOrError());
    final r = s.result;
    return Scaffold(
      appBar: AppBar(title: Text(s.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(s.targetLabel ?? s.kind.label, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${s.kind.label} · requested by ${s.requestedBy} · ${fmt.dateTime(s.requestedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (r == null)
            Card(
              child: ListTile(
                leading: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text(s.status.label),
                subtitle: const Text('The engine runs server-side against the current CMS, OIG and SBA pulls. Results appear here.'),
              ),
            )
          else ...[
            Row(children: [
              Expanded(child: StatTile(label: 'NPIs screened', value: '${r.npisScreened}')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Tier 1 hits', value: '${r.tier1Hits}', accent: r.tier1Hits > 0 ? const Color(0xFFB3261E) : null)),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Tier 2 hits', value: '${r.tier2Hits}')),
            ]),
            const SectionHeader('Summary'),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(r.summary))),
            const SizedBox(height: 8),
            Text('Dollars at issue ${fmt.money(r.dollarsAtIssue)} · ruleset ${r.rulesetVersion}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SectionHeader('NPIs'),
          Card(
            child: Column(children: [
              for (final n in s.npis) ListTile(dense: true, leading: const Icon(Icons.badge_outlined, size: 18), title: Text(n, style: const TextStyle(fontFamily: 'monospace'))),
            ]),
          ),
          const SizedBox(height: 12),
          const RiskIndicatorNotice(dense: true),
        ],
      ),
    );
  }
}

/// New screen request. Validates NPIs locally (10 digits, Luhn with the
/// 80840 prefix) before submitting; self-audits are limited to owned NPIs.
class NewScreenScreen extends ConsumerStatefulWidget {
  const NewScreenScreen({super.key});

  @override
  ConsumerState<NewScreenScreen> createState() => _NewScreenScreenState();
}

class _NewScreenScreenState extends ConsumerState<NewScreenScreen> {
  final _label = TextEditingController();
  final _npis = TextEditingController();
  ScreenKind _kind = ScreenKind.diligence;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _npis.dispose();
    super.dispose();
  }

  List<String> _parse() => _npis.text
      .split(RegExp(r'[\s,;]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final npis = _parse();
    final bad = npis.where((n) => !isValidNpi(n)).toList();
    if (npis.isEmpty) {
      setState(() => _error = 'Enter at least one NPI.');
      return;
    }
    if (bad.isNotEmpty) {
      setState(() => _error = 'Not valid NPIs: ${bad.join(', ')}. Demo NPIs starting 199999 are accepted.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final req = await ref.read(repositoryProvider).submitScreen(
            user: user,
            kind: _kind,
            npis: npis,
            targetLabel: _label.text.trim().isEmpty ? null : _label.text.trim(),
          );
      ref.invalidate(accessLogProvider);
      if (mounted) context.go('/screens/${req.id}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final org = ref.watch(currentOrgProvider).value;
    final selfAuditOnly = org?.offer == OfferTier.complianceSelfAudit;
    if (selfAuditOnly && _kind != ScreenKind.selfAudit) _kind = ScreenKind.selfAudit;
    return Scaffold(
      appBar: AppBar(title: const Text('New screen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SegmentedButton<ScreenKind>(
            segments: [
              for (final k in ScreenKind.values)
                ButtonSegment(value: k, label: Text(k.label), enabled: !(selfAuditOnly && k == ScreenKind.diligence)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 8),
          Text(_kind.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            decoration: InputDecoration(labelText: _kind == ScreenKind.diligence ? 'Target label (internal, e.g. project name)' : 'Label'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _npis,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'NPIs',
              hintText: 'One per line, or comma separated',
              alignLabelWithHint: true,
            ),
          ),
          if (_kind == ScreenKind.selfAudit && org != null && org.ownNpis.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final n in org.ownNpis)
                ActionChip(
                  label: Text(n),
                  onPressed: () => setState(() => _npis.text = {..._parse(), n}.join('\n')),
                ),
            ]),
            Text('Verified NPIs owned by ${org.name}.', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
            label: Text(_busy ? 'Submitting' : 'Run screen (ruleset $rulesetVersion)'),
          ),
          const SizedBox(height: 16),
          const RiskIndicatorNotice(dense: true),
          const SizedBox(height: 8),
          Text(
            'Screens run every active rule with the same evidence cards and innocent-explanation checklist as leads. The subject is your own target or practice, so legal exposure is low.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// NPI check digit: Luhn over the 10 digits with the 80840 card-issuer prefix.
/// Demo identifiers starting 199999 are accepted so the sample data works.
bool isValidNpi(String s) {
  if (!RegExp(r'^\d{10}$').hasMatch(s)) return false;
  if (s.startsWith('199999')) return true;
  final digits = '80840$s'.split('').map(int.parse).toList();
  var sum = 0;
  for (var i = digits.length - 1, alt = false; i >= 0; i--, alt = !alt) {
    var d = digits[i];
    if (alt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}
