import 'dart:async';

import '../domain/models.dart';
import '../domain/rules_engine.dart';
import 'demo_data.dart';
import 'repository.dart';

/// In-memory repository seeded with synthetic data. Used when no Supabase
/// configuration is supplied, so the app runs anywhere for demos and tests.
class DemoRepository implements FraudSignalRepository {
  DemoRepository({this.latency = const Duration(milliseconds: 250)}) {
    _leads = List.of(demoLeads);
    _screens = List.of(demoScreens);
    _log = List.of(demoAccessLog);
  }

  final Duration latency;
  final _userController = StreamController<AppUser?>.broadcast();
  final _leadsController = StreamController<List<Lead>>.broadcast();
  final _screensController = StreamController<List<ScreenRequest>>.broadcast();

  AppUser? _user;
  late List<Lead> _leads;
  late List<ScreenRequest> _screens;
  late List<AccessLogEntry> _log;
  int _seq = 100;

  Future<void> _wait() => latency == Duration.zero ? Future<void>.value() : Future<void>.delayed(latency);

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    yield _user;
    yield* _userController.stream;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    await _wait();
    final normalized = email.trim().toLowerCase();
    final user = demoUsers.where((u) => u.email == normalized).firstOrNull;
    if (user == null || password != 'demo') {
      throw AuthException('Invite-only. That email is not on an organization account, or the password is wrong.');
    }
    _user = user;
    _userController.add(user);
    _append(AccessAction.signedIn, user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _userController.add(null);
  }

  @override
  Future<Organization> organization(String orgId) async =>
      demoOrgs.firstWhere((o) => o.id == orgId);

  // ---------------------------------------------------------------------------
  // Leads
  // ---------------------------------------------------------------------------

  List<Lead> _visibleTo(AppUser user) {
    final org = demoOrgs.firstWhere((o) => o.id == user.orgId);
    switch (org.offer) {
      case OfferTier.internal:
        return List.of(_leads);
      case OfferTier.exclusiveCasePackage:
        return _leads.where((l) => l.licensedToOrgId == org.id).toList();
      case OfferTier.screeningSubscription:
        return _leads
            .where((l) => l.status == LeadStatus.signedOff || l.status == LeadStatus.watchList)
            .toList();
      case OfferTier.complianceSelfAudit:
        return _leads.where((l) => org.ownNpis.any(l.entityRef.contains)).toList();
      case OfferTier.diligenceScreen:
        return const [];
    }
  }

  @override
  Stream<List<Lead>> watchLeads(AppUser user) async* {
    yield _visibleTo(user);
    yield* _leadsController.stream.map((_) => _visibleTo(user));
  }

  @override
  Future<Lead?> lead(String id) async => _leads.where((l) => l.id == id).firstOrNull;

  Lead _replace(Lead updated) {
    final i = _leads.indexWhere((l) => l.id == updated.id);
    _leads[i] = updated;
    _leadsController.add(_leads);
    return updated;
  }

  void _append(AccessAction action, AppUser user, {String? leadId, String? detail}) {
    _log.insert(
      0,
      AccessLogEntry(
        id: 'al_${_seq++}',
        at: DateTime.now(),
        userId: user.id,
        userEmail: user.email,
        orgId: user.orgId,
        action: action,
        leadId: leadId,
        detail: detail,
      ),
    );
  }

  @override
  Future<void> logLeadView(Lead lead, AppUser user) async {
    final isLicenseeFirstView = lead.licensedToOrgId == user.orgId && lead.firstViewedAt == null;
    _append(
      AccessAction.viewedLead,
      user,
      leadId: lead.id,
      detail: isLicenseeFirstView ? 'First view by licensee. Handoff timestamp.' : null,
    );
    if (lead.firstViewedAt == null) {
      _replace(lead.copyWith(firstViewedAt: DateTime.now()));
    }
  }

  @override
  Future<Lead> signOff(Lead lead, AppUser reviewer, {String? notes}) async {
    await _wait();
    if (!reviewer.role.canSignOff) throw AuthException('Only reviewers can sign off a lead.');
    _append(AccessAction.signedOff, reviewer, leadId: lead.id);
    return _replace(lead.copyWith(
      status: LeadStatus.signedOff,
      signedOffBy: reviewer.email,
      signedOffAt: DateTime.now(),
      investigationNotes: notes ?? lead.investigationNotes,
    ));
  }

  @override
  Future<Lead> license(Lead lead, Organization to, AppUser reviewer) async {
    await _wait();
    if (!reviewer.role.canSignOff) throw AuthException('Only reviewers can license a lead.');
    if (lead.status != LeadStatus.signedOff) {
      throw AuthException('A lead must be signed off before it is licensed.');
    }
    if (_leads.any((l) => l.id == lead.id && l.licensedToOrgId != null)) {
      throw AuthException('This lead is already licensed. One firm per lead.');
    }
    _append(AccessAction.licensed, reviewer, leadId: lead.id, detail: 'Licensed to ${to.name}, one firm per lead.');
    return _replace(lead.copyWith(status: LeadStatus.licensed, licensedToOrgId: to.id));
  }

  @override
  Future<Lead> closeLead(Lead lead, AppUser reviewer, String reason) async {
    await _wait();
    if (!reviewer.role.canSignOff) throw AuthException('Only reviewers can close a lead.');
    return _replace(lead.copyWith(status: LeadStatus.closed, investigationNotes: 'Closed: $reason'));
  }

  @override
  Future<void> logExport(Lead lead, AppUser user) async {
    _append(AccessAction.exportedEvidence, user, leadId: lead.id, detail: 'Watermarked evidence card');
  }

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  @override
  Future<List<Rule>> rules() async => demoRules;
  @override
  Future<List<BacktestRow>> backtest() async => demoBacktest;
  @override
  Future<List<PppScanRow>> pppScan() async => demoPppScan;
  @override
  Future<List<DataSource>> dataSources() async => demoSources;
  @override
  Future<BiasAuditRun> latestBiasAudit() async => demoBiasAudit;
  @override
  Future<List<HeatmapCell>> heatmap() async => demoHeatmap;

  @override
  Future<DashboardSummary> dashboard(AppUser user) async {
    final visible = _visibleTo(user);
    return DashboardSummary(
      leadsPendingReview: visible.where((l) => l.status == LeadStatus.pendingReview).length,
      tier1Verified: visible.where((l) => l.tier1Count > 0 && l.status != LeadStatus.closed).length,
      watchList: visible.where((l) => l.status == LeadStatus.watchList).length,
      licensed: visible.where((l) => l.status == LeadStatus.licensed).length,
      recordsScored: 1392616,
      lastRefresh: DateTime(2026, 10, 20, 14, 12),
      rulesetVersion: rulesetVersion,
      lastAuditVerdict: demoBiasAudit.overall,
    );
  }

  // ---------------------------------------------------------------------------
  // Screens
  // ---------------------------------------------------------------------------

  List<ScreenRequest> _screensFor(AppUser user) {
    final org = demoOrgs.firstWhere((o) => o.id == user.orgId);
    if (org.offer == OfferTier.internal) return List.of(_screens);
    final orgEmails = demoUsers.where((u) => u.orgId == org.id).map((u) => u.email).toSet();
    return _screens.where((s) => orgEmails.contains(s.requestedBy)).toList();
  }

  @override
  Stream<List<ScreenRequest>> watchScreens(AppUser user) async* {
    yield _screensFor(user);
    yield* _screensController.stream.map((_) => _screensFor(user));
  }

  @override
  Future<ScreenRequest> submitScreen({
    required AppUser user,
    required ScreenKind kind,
    required List<String> npis,
    String? targetLabel,
  }) async {
    await _wait();
    if (!user.role.canRunScreens) throw AuthException('Viewers cannot run screens.');
    final org = demoOrgs.firstWhere((o) => o.id == user.orgId);
    if (kind == ScreenKind.selfAudit) {
      final notOwned = npis.where((n) => !org.ownNpis.contains(n)).toList();
      if (org.offer != OfferTier.internal && notOwned.isNotEmpty) {
        throw AuthException('Self-audits run only on NPIs your organization has verified it owns. Not verified: ${notOwned.join(', ')}.');
      }
    }
    final id = 'S-${(_seq++).toString().padLeft(4, '0')}';
    var request = ScreenRequest(
      id: id,
      kind: kind,
      npis: npis,
      targetLabel: targetLabel,
      requestedBy: user.email,
      requestedAt: DateTime.now(),
      status: ScreenStatus.queued,
    );
    _screens.insert(0, request);
    _screensController.add(_screens);
    _append(AccessAction.ranScreen, user, detail: '$id ${kind.label}, ${npis.length} NPIs');

    // Simulate the server run completing.
    unawaited(Future<void>.delayed(const Duration(seconds: 3), () {
      final i = _screens.indexWhere((s) => s.id == id);
      if (i < 0) return;
      request = ScreenRequest(
        id: id,
        kind: kind,
        npis: npis,
        targetLabel: targetLabel,
        requestedBy: user.email,
        requestedAt: request.requestedAt,
        status: ScreenStatus.complete,
        result: ScreenResult(
          npisScreened: npis.length,
          tier1Hits: 0,
          tier2Hits: 0,
          dollarsAtIssue: 0,
          summary: 'Demo run. No hard-rule violations and no peer outliers on ${npis.length} NPI${npis.length == 1 ? '' : 's'}. Production runs the full ruleset server-side against the current CMS, OIG and SBA pulls.',
          rulesetVersion: rulesetVersion,
        ),
      );
      _screens[i] = request;
      _screensController.add(_screens);
    }));
    return request;
  }

  // ---------------------------------------------------------------------------
  // Access log
  // ---------------------------------------------------------------------------

  @override
  Future<List<AccessLogEntry>> accessLog(AppUser user) async {
    final org = demoOrgs.firstWhere((o) => o.id == user.orgId);
    if (org.offer == OfferTier.internal) return List.of(_log);
    if (user.role.canSeeOrgLog) return _log.where((e) => e.orgId == org.id).toList();
    return _log.where((e) => e.userId == user.id).toList();
  }
}
