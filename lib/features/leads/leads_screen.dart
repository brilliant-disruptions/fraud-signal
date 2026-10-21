import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../home/home_screen.dart' show LeadCard;

class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leadsAsync = ref.watch(leadsProvider);
    final filtered = ref.watch(filteredLeadsProvider);
    final filter = ref.watch(leadFilterProvider);
    final org = ref.watch(currentOrgProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(org?.offer == OfferTier.exclusiveCasePackage ? 'Licensed leads' : 'Leads'),
        actions: [
          if (!filter.isEmpty)
            TextButton(onPressed: () => ref.read(leadFilterProvider.notifier).clear(), child: const Text('Clear')),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search id, NPI, loan, state, specialty',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => ref.read(leadFilterProvider.notifier).set(filter.copyWith(query: v)),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final p in [Program.medicare, Program.ppp, Program.childCare])
                _chip(ref, filter, p.label, filter.program == p, () => filter.copyWith(program: () => filter.program == p ? null : p)),
              const SizedBox(width: 12),
              for (final t in Tier.values)
                _chip(ref, filter, 'Tier ${t.number}', filter.tier == t, () => filter.copyWith(tier: () => filter.tier == t ? null : t)),
              const SizedBox(width: 12),
              for (final s in LeadStatus.values)
                _chip(ref, filter, s.label, filter.status == s, () => filter.copyWith(status: () => filter.status == s ? null : s)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: leadsAsync.when(
            loading: () => const LoadingOrError(),
            error: (e, _) => LoadingOrError(error: e),
            data: (all) {
              if (all.isEmpty) {
                return EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No leads visible to your organization',
                  message: org?.offer == OfferTier.diligenceScreen || org?.offer == OfferTier.complianceSelfAudit
                      ? 'Your plan delivers results through screens. Run one from the Screens tab.'
                      : 'Leads appear here once they are licensed to your organization.',
                );
              }
              if (filtered.isEmpty) {
                return const EmptyState(icon: Icons.filter_alt_off_outlined, title: 'Nothing matches', message: 'Try clearing a filter.');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: filtered.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Text(
                      '${filtered.length} of ${all.length} · sorted by strongest tier, then dollars',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    );
                  }
                  return LeadCard(lead: filtered[i - 1]);
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip(WidgetRef ref, LeadFilter filter, String label, bool selected, LeadFilter Function() next) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => ref.read(leadFilterProvider.notifier).set(next()),
      ),
    );
  }
}
