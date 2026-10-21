import '../domain/models.dart';

/// Everything the client needs from the backend.
///
/// Two implementations ship: [DemoRepository] (in-memory, synthetic data) and
/// [SupabaseRepository] (production, row-level security by organization).
abstract class FraudSignalRepository {
  // Auth
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<Organization> organization(String orgId);

  // Leads
  Stream<List<Lead>> watchLeads(AppUser user);
  Future<Lead?> lead(String id);

  /// Records a lead view with a timestamp. The first view by a licensee is
  /// the documented handoff.
  Future<void> logLeadView(Lead lead, AppUser user);
  Future<Lead> signOff(Lead lead, AppUser reviewer, {String? notes});
  Future<Lead> license(Lead lead, Organization to, AppUser reviewer);
  Future<Lead> closeLead(Lead lead, AppUser reviewer, String reason);
  Future<void> logExport(Lead lead, AppUser user);

  // Catalog & results
  Future<List<Rule>> rules();
  Future<List<BacktestRow>> backtest();
  Future<List<PppScanRow>> pppScan();
  Future<List<DataSource>> dataSources();
  Future<BiasAuditRun> latestBiasAudit();
  Future<List<HeatmapCell>> heatmap();
  Future<DashboardSummary> dashboard(AppUser user);

  // Screens
  Stream<List<ScreenRequest>> watchScreens(AppUser user);
  Future<ScreenRequest> submitScreen({
    required AppUser user,
    required ScreenKind kind,
    required List<String> npis,
    String? targetLabel,
  });

  // Access log
  Future<List<AccessLogEntry>> accessLog(AppUser user);
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
