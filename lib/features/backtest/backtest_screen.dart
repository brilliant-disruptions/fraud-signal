import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

class BacktestScreen extends ConsumerWidget {
  const BacktestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(backtestProvider);
    final ppp = ref.watch(pppScanProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Back-test results')),
      body: rows.when(
        loading: () => const LoadingOrError(),
        error: (e, _) => LoadingOrError(error: e),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              'The impossible-hours rule beat chance by about 40 times: providers it flagged in 2019 were later excluded for fraud at 2.5% to 2.7%, against a 0.07% base rate. Peer outliers on their own ran 2 to 7 times chance and none were statistically significant.',
              style: theme.textTheme.bodyMedium,
            ),
            const SectionHeader('Lift over base rate', subtitle: 'Dot is the point estimate, bar the 95% interval, log scale.'),
            Card(child: Padding(padding: const EdgeInsets.all(14), child: LiftChart(rows: data))),
            const SectionHeader('Detail'),
            Card(
              child: Column(children: [
                for (var i = 0; i < data.length; i++) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    title: Text(data[i].rule),
                    subtitle: Text('Tier ${data[i].tierLabel} · ${fmt.count(data[i].flagged)} flagged · ${data[i].laterExcluded} later excluded'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmt.lift(data[i].lift), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${fmt.lift(data[i].liftLow)}–${fmt.lift(data[i].liftHigh)}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Source: CMS 2019 Part B, 14 codes, 107,506 providers · OIG LEIE 09-2026 · ruleset 2026.10.0. An interval reaching below 1x means the rule may be no better than chance.',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SectionHeader('Test design'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Score 2019 Medicare data, then check which flagged providers the OIG excluded for fraud between Jan 2020 and Sept 2026. Providers already excluded before 2020 are removed from both sides. Labels miss civil settlements and the 89% of exclusions with no NPI on file, so every precision figure here is a floor.',
                ),
              ),
            ),
            const SectionHeader('Rules dropped'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'The lifetime-visit rule found nothing: Medicare\'s claim edits already block repeat visits, and 41,994 of 41,995 provider rows show exactly one visit per patient. The long-session share rule flagged 958 providers and none were later excluded.',
                ),
              ),
            ),
            const SectionHeader('PPP scan', subtitle: 'Not yet validated. No public label set exists for PPP, so these are counts, not precision.'),
            ppp.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (scan) => Card(
                child: Column(children: [
                  for (var i = 0; i < scan.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      title: Text(scan[i].rule),
                      subtitle: Text('${scan[i].loansFlagged} · ${scan[i].note}'),
                      trailing: Text(fmt.moneyCompact(scan[i].approvedAmount),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
            ),
            const SectionHeader('What this means for trust'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Public data finds real signal, but statistics alone are not proof, which matches the court rulings. Tier 1 violations are verified findings. Statistical scores are a ranked risk list with the measured lift printed beside it. Neither is ever labeled fraud.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
