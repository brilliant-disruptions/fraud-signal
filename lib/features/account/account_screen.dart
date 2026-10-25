import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;
    final org = ref.watch(currentOrgProvider).value;
    final log = ref.watch(accessLogProvider);
    final sources = ref.watch(dataSourcesProvider);
    if (user == null) return const Scaffold(body: LoadingOrError());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(repositoryProvider).signOut(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.displayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(user.email, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Divider(height: 20),
                KeyValueTable({
                  'Organization': org?.name ?? user.orgId,
                  'Plan': org?.offer.label ?? '',
                  'Role': '${user.role.label}. ${user.role.description}',
                  'Identity': org?.identityVerified == true ? 'Verified' : 'Pending verification',
                  'Seats': '${org?.seats ?? ''}',
                  'Bulk export': org?.offer.allowsBulkExport == true ? 'Available' : 'Not on this plan',
                  'Backend': AppConfig.useSupabase ? 'Supabase' : 'Demo (in-memory)',
                }),
              ]),
            ),
          ),
          SectionHeader(
            user.role.canSeeOrgLog ? 'Access log' : 'Your activity',
            subtitle: user.role.canSeeOrgLog
                ? 'Every lead view, export, sign-off and license in your organization'
                : 'Every lead view is logged with a timestamp',
            trailing: IconButton(onPressed: () => ref.invalidate(accessLogProvider), icon: const Icon(Icons.refresh)),
          ),
          log.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (entries) => entries.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No activity yet.')))
                : Card(
                    child: Column(children: [
                      for (var i = 0; i < entries.length && i < 50; i++) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        _LogTile(entries[i]),
                      ],
                    ]),
                  ),
          ),
          const SectionHeader('Data sources', subtitle: 'Every pull is saved with its URL, query, row count and SHA-256 hash.'),
          sources.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (list) => Card(
              child: Column(children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  ExpansionTile(
                    leading: Icon(list[i].live ? Icons.cloud_done_outlined : Icons.cloud_queue_outlined,
                        color: list[i].live ? const Color(0xFF2E7D32) : theme.colorScheme.outline),
                    title: Text(list[i].name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(list[i].publisher),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      KeyValueTable({
                        'Holds': list[i].holds,
                        'Pulled': list[i].pulled,
                        'Limits': list[i].limits,
                        if (list[i].url.isNotEmpty) 'URL': list[i].url,
                      }),
                    ],
                  ),
                ],
              ]),
            ),
          ),
          const SectionHeader('Legal guardrails'),
          Card(
            child: Column(children: const [
              _Guardrail('Defamation', 'Output is labeled "risk indicators" with evidence. Buyers may not publish or contact targets.'),
              Divider(indent: 16, endIndent: 16),
              _Guardrail('First-to-file bar', 'Each lead is licensed to one buyer, exclusively, with a timestamped handoff.'),
              Divider(indent: 16, endIndent: 16),
              _Guardrail('Public disclosure bar', 'Leads are starting points; the buyer\'s investigation supplies the non-public facts.'),
              Divider(indent: 16, endIndent: 16),
              _Guardrail('Fee splitting', 'Flat license and subscription fees only. No outcome-based payment.'),
              Divider(indent: 16, endIndent: 16),
              _Guardrail('Seal', 'Nothing about a filed case is discussed publicly. Buyers sign confidentiality terms.'),
              Divider(indent: 16, endIndent: 16),
              _Guardrail('Misuse', 'Vetted buyers only. Every access is logged. Access is revoked on misuse.'),
              Divider(indent: 16, endIndent: 16),
              _Guardrail('Privacy', 'CMS-published aggregates only; never joined to patient-level data.'),
              Divider(indent: 16, endIndent: 16),
              _Guardrail('Profiling', 'No name or ancestry inputs. Bias audit on every run, delivered with the data.'),
            ]),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/rules/heatmap'),
              child: const Text('Public layer: aggregate heatmap'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile(this.e);
  final AccessLogEntry e;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (e.action) {
      AccessAction.viewedLead => Icons.visibility_outlined,
      AccessAction.exportedEvidence => Icons.ios_share_outlined,
      AccessAction.signedOff => Icons.verified_outlined,
      AccessAction.licensed => Icons.handshake_outlined,
      AccessAction.ranScreen => Icons.fact_check_outlined,
      AccessAction.signedIn => Icons.login,
    };
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text('${e.action.label}${e.leadId != null ? ' · ${e.leadId}' : ''}'),
      subtitle: Text('${e.userEmail} · ${fmt.dateTimeUtc(e.at)}${e.detail != null ? '\n${e.detail}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      isThreeLine: e.detail != null,
      onTap: e.leadId == null ? null : () => context.go('/leads/${e.leadId}'),
    );
  }
}

class _Guardrail extends StatelessWidget {
  const _Guardrail(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(body),
    );
  }
}
