import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/models.dart';

/// Overridden in `main.dart` with the demo or Supabase implementation.
final repositoryProvider = Provider<FraudSignalRepository>(
  (ref) => throw UnimplementedError('repositoryProvider must be overridden'),
);

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(repositoryProvider).watchCurrentUser();
});

final currentOrgProvider = FutureProvider<Organization?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  return ref.watch(repositoryProvider).organization(user.orgId);
});

final leadsProvider = StreamProvider<List<Lead>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(repositoryProvider).watchLeads(user);
});

final leadProvider = FutureProvider.family<Lead?, String>((ref, id) {
  // Re-read whenever the lead list changes so status updates show at once.
  final leads = ref.watch(leadsProvider).value;
  final fromList = leads?.where((l) => l.id == id).firstOrNull;
  if (fromList != null) return Future.value(fromList);
  return ref.watch(repositoryProvider).lead(id);
});

final rulesProvider = FutureProvider<List<Rule>>((ref) => ref.watch(repositoryProvider).rules());
final backtestProvider = FutureProvider<List<BacktestRow>>((ref) => ref.watch(repositoryProvider).backtest());
final pppScanProvider = FutureProvider<List<PppScanRow>>((ref) => ref.watch(repositoryProvider).pppScan());
final dataSourcesProvider = FutureProvider<List<DataSource>>((ref) => ref.watch(repositoryProvider).dataSources());
final biasAuditProvider = FutureProvider<BiasAuditRun>((ref) => ref.watch(repositoryProvider).latestBiasAudit());
final heatmapProvider = FutureProvider<List<HeatmapCell>>((ref) => ref.watch(repositoryProvider).heatmap());

final dashboardProvider = FutureProvider<DashboardSummary?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Future.value(null);
  ref.watch(leadsProvider); // refresh counts when leads change
  return ref.watch(repositoryProvider).dashboard(user);
});

final screensProvider = StreamProvider<List<ScreenRequest>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(repositoryProvider).watchScreens(user);
});

final accessLogProvider = FutureProvider<List<AccessLogEntry>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Future.value(const []);
  ref.watch(leadsProvider);
  ref.watch(screensProvider);
  return ref.watch(repositoryProvider).accessLog(user);
});

/// Lead list filters.
class LeadFilter {
  const LeadFilter({this.program, this.tier, this.status, this.query = ''});
  final Program? program;
  final Tier? tier;
  final LeadStatus? status;
  final String query;

  LeadFilter copyWith({
    Program? Function()? program,
    Tier? Function()? tier,
    LeadStatus? Function()? status,
    String? query,
  }) =>
      LeadFilter(
        program: program != null ? program() : this.program,
        tier: tier != null ? tier() : this.tier,
        status: status != null ? status() : this.status,
        query: query ?? this.query,
      );

  bool get isEmpty => program == null && tier == null && status == null && query.isEmpty;

  bool matches(Lead lead) {
    if (program != null && lead.program != program) return false;
    if (tier != null && !lead.hits.any((h) => h.tier == tier)) return false;
    if (status != null && lead.status != status) return false;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final hay = '${lead.id} ${lead.entityRef} ${lead.state} ${lead.specialtyOrIndustry}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }
}

class LeadFilterNotifier extends Notifier<LeadFilter> {
  @override
  LeadFilter build() => const LeadFilter();
  void set(LeadFilter f) => state = f;
  void clear() => state = const LeadFilter();
}

final leadFilterProvider = NotifierProvider<LeadFilterNotifier, LeadFilter>(LeadFilterNotifier.new);

final filteredLeadsProvider = Provider<List<Lead>>((ref) {
  final leads = ref.watch(leadsProvider).value ?? const [];
  final filter = ref.watch(leadFilterProvider);
  final out = leads.where(filter.matches).toList()
    ..sort((a, b) {
      // Strongest tier first, then dollars.
      final t = a.strongestTier.number.compareTo(b.strongestTier.number);
      if (t != 0) return t;
      return b.dollarsAtIssue.compareTo(a.dollarsAtIssue);
    });
  return out;
});
