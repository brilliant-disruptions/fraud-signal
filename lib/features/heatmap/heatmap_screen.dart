import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart' as fmt;
import '../../core/providers.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

/// Tile-grid map of the US. Aggregate flag rates by state, no names.
/// This is the only layer the plan allows to be public.
class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  String? _selected;

  // Row, column positions for a compact US tile grid.
  static const Map<String, (int, int)> _grid = {
    'AK': (0, 0), 'ME': (0, 10),
    'WI': (1, 5), 'VT': (1, 9), 'NH': (1, 10),
    'WA': (2, 0), 'ID': (2, 1), 'MT': (2, 2), 'ND': (2, 3), 'MN': (2, 4), 'IL': (2, 5), 'MI': (2, 6), 'NY': (2, 8), 'MA': (2, 9), 'RI': (2, 10),
    'OR': (3, 0), 'NV': (3, 1), 'WY': (3, 2), 'SD': (3, 3), 'IA': (3, 4), 'IN': (3, 5), 'OH': (3, 6), 'PA': (3, 7), 'NJ': (3, 8), 'CT': (3, 9),
    'CA': (4, 0), 'UT': (4, 1), 'CO': (4, 2), 'NE': (4, 3), 'MO': (4, 4), 'KY': (4, 5), 'WV': (4, 6), 'VA': (4, 7), 'MD': (4, 8), 'DE': (4, 9),
    'AZ': (5, 1), 'NM': (5, 2), 'KS': (5, 3), 'AR': (5, 4), 'TN': (5, 5), 'NC': (5, 6), 'SC': (5, 7), 'DC': (5, 8),
    'OK': (6, 3), 'LA': (6, 4), 'MS': (6, 5), 'AL': (6, 6), 'GA': (6, 7),
    'HI': (7, 0), 'TX': (7, 3), 'FL': (7, 8),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = ref.watch(heatmapProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Aggregate heatmap')),
      body: cells.when(
        loading: () => const LoadingOrError(),
        error: (e, _) => LoadingOrError(error: e),
        data: (data) {
          final byState = {for (final c in data) c.state: c};
          final maxRate = data.map((c) => c.flagsPer1000).fold<double>(0, (a, b) => a > b ? a : b);
          final selected = _selected == null ? null : byState[_selected];
          final ranked = List.of(data)..sort((a, b) => b.flagsPer1000.compareTo(a.flagsPer1000));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text('Flags per 1,000 providers scored, by state. No names appear here or anywhere public.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, c) {
                final cell = ((c.maxWidth - 10 * 3) / 11).floorToDouble();
                return SizedBox(
                  height: cell * 8 + 7 * 3,
                  child: Stack(children: [
                    for (final e in _grid.entries)
                      Positioned(
                        left: e.value.$2 * (cell + 3),
                        top: e.value.$1 * (cell + 3),
                        width: cell,
                        height: cell,
                        child: _Tile(
                          state: e.key,
                          cell: byState[e.key],
                          maxRate: maxRate,
                          selected: _selected == e.key,
                          onTap: () => setState(() => _selected = _selected == e.key ? null : e.key),
                        ),
                      ),
                  ]),
                );
              }),
              const SizedBox(height: 8),
              _Legend(maxRate: maxRate),
              if (selected != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Text(selected.state, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: KeyValueTable({
                          'Providers scored': fmt.count(selected.providersScored),
                          'Flags per 1,000': selected.flagsPer1000.toStringAsFixed(1),
                          'Dollars at issue': fmt.moneyCompact(selected.dollarsAtIssue),
                        }),
                      ),
                    ]),
                  ),
                ),
              ],
              const SectionHeader('Highest flag rates'),
              Card(
                child: Column(children: [
                  for (var i = 0; i < 8 && i < ranked.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      dense: true,
                      leading: Text('${i + 1}', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      title: Text(ranked[i].state),
                      subtitle: Text('${fmt.count(ranked[i].providersScored)} scored · ${fmt.moneyCompact(ranked[i].dollarsAtIssue)} at issue'),
                      trailing: Text('${ranked[i].flagsPer1000.toStringAsFixed(1)} ‰', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      onTap: () => setState(() => _selected = ranked[i].state),
                    ),
                  ],
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

Color _heat(double t, ColorScheme scheme) {
  // Light neutral to deep red; perceptually simple and legible in both themes.
  const low = Color(0xFFFFE9C9);
  const high = Color(0xFF8E1B12);
  return Color.lerp(low, high, t.clamp(0, 1))!;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.state, required this.cell, required this.maxRate, required this.selected, required this.onTap});
  final String state;
  final HeatmapCell? cell;
  final double maxRate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = cell == null || maxRate == 0 ? 0.0 : cell!.flagsPer1000 / maxRate;
    final bg = cell == null ? scheme.surfaceContainerHighest : _heat(t, scheme);
    final fg = t > 0.55 ? Colors.white : const Color(0xFF2B1A05);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: selected ? Border.all(color: scheme.primary, width: 2) : null,
          ),
          alignment: Alignment.center,
          child: Text(state, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.maxRate});
  final double maxRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Text('0', style: theme.textTheme.labelSmall),
      const SizedBox(width: 6),
      Expanded(
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: [_heat(0, theme.colorScheme), _heat(0.5, theme.colorScheme), _heat(1, theme.colorScheme)]),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('${maxRate.toStringAsFixed(0)} per 1,000', style: theme.textTheme.labelSmall),
    ]);
  }
}
