import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/models.dart';
import 'repository.dart';

/// Production repository. Access control lives in the database (RLS policies
/// in `supabase/migrations/0001_schema.sql`); this class only maps rows.
class SupabaseRepository implements FraudSignalRepository {
  SupabaseRepository(this._client);

  final sb.SupabaseClient _client;
  AppUser? _cached;

  @override
  AppUser? get currentUser => _cached;

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    yield await _loadProfile(_client.auth.currentUser);
    await for (final state in _client.auth.onAuthStateChange) {
      yield await _loadProfile(state.session?.user);
    }
  }

  Future<AppUser?> _loadProfile(sb.User? authUser) async {
    if (authUser == null) {
      _cached = null;
      return null;
    }
    final row = await _client.from('profiles').select().eq('id', authUser.id).maybeSingle();
    if (row == null) {
      _cached = null;
      return null;
    }
    _cached = AppUser(
      id: row['id'] as String,
      email: row['email'] as String,
      displayName: row['display_name'] as String,
      role: Role.values.byName(row['role'] as String),
      orgId: row['org_id'] as String,
    );
    return _cached;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    try {
      final res = await _client.auth.signInWithPassword(email: email.trim(), password: password);
      final user = await _loadProfile(res.user);
      if (user == null) {
        await _client.auth.signOut();
        throw AuthException('Invite-only. This account is not attached to an organization.');
      }
      await _append(AccessAction.signedIn, user);
      return user;
    } on sb.AuthException catch (e) {
      throw AuthException(e.message);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<Organization> organization(String orgId) async {
    final row = await _client.from('organizations').select().eq('id', orgId).single();
    return Organization(
      id: row['id'] as String,
      name: row['name'] as String,
      offer: OfferTier.values.byName(row['offer'] as String),
      identityVerified: row['identity_verified'] as bool,
      seats: row['seats'] as int,
      ownNpis: (row['own_npis'] as List).cast<String>(),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Stream<List<Lead>> watchLeads(AppUser user) {
    return _client
        .from('leads')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_leadFromRow).toList());
  }

  @override
  Future<Lead?> lead(String id) async {
    final row = await _client.from('leads').select().eq('id', id).maybeSingle();
    return row == null ? null : _leadFromRow(row);
  }

  Future<void> _append(AccessAction action, AppUser user, {String? leadId, String? detail}) {
    return _client.from('access_log').insert({
      'user_id': user.id,
      'user_email': user.email,
      'org_id': user.orgId,
      'action': action.name,
      'lead_id': leadId,
      'detail': detail,
    });
  }

  @override
  Future<void> logLeadView(Lead lead, AppUser user) {
    final first = lead.licensedToOrgId == user.orgId && lead.firstViewedAt == null;
    return _append(AccessAction.viewedLead, user,
        leadId: lead.id, detail: first ? 'First view by licensee. Handoff timestamp.' : null);
  }

  @override
  Future<Lead> signOff(Lead lead, AppUser reviewer, {String? notes}) async {
    final row = await _client
        .from('leads')
        .update({
          'status': LeadStatus.signedOff.name,
          'signed_off_by': reviewer.email,
          'signed_off_at': DateTime.now().toUtc().toIso8601String(),
          'investigation_notes': ?notes,
        })
        .eq('id', lead.id)
        .select()
        .single();
    await _append(AccessAction.signedOff, reviewer, leadId: lead.id);
    return _leadFromRow(row);
  }

  @override
  Future<Lead> license(Lead lead, Organization to, AppUser reviewer) async {
    final row = await _client
        .from('leads')
        .update({'status': LeadStatus.licensed.name, 'licensed_to_org_id': to.id})
        .eq('id', lead.id)
        .isFilter('licensed_to_org_id', null) // one firm per lead, enforced at write time
        .select()
        .maybeSingle();
    if (row == null) throw AuthException('This lead is already licensed. One firm per lead.');
    await _append(AccessAction.licensed, reviewer, leadId: lead.id, detail: 'Licensed to ${to.name}, one firm per lead.');
    return _leadFromRow(row);
  }

  @override
  Future<Lead> closeLead(Lead lead, AppUser reviewer, String reason) async {
    final row = await _client
        .from('leads')
        .update({'status': LeadStatus.closed.name, 'investigation_notes': 'Closed: $reason'})
        .eq('id', lead.id)
        .select()
        .single();
    return _leadFromRow(row);
  }

  @override
  Future<void> logExport(Lead lead, AppUser user) =>
      _append(AccessAction.exportedEvidence, user, leadId: lead.id, detail: 'Watermarked evidence card');

  // ---------------------------------------------------------------------------

  @override
  Future<List<Rule>> rules() async {
    final rows = await _client.from('rules').select().order('tier').order('program');
    return rows
        .map((r) => Rule(
              id: r['id'] as String,
              name: r['name'] as String,
              program: Program.values.byName(r['program'] as String),
              tier: Tier.values[(r['tier'] as int) - 1],
              whyItHolds: r['why_it_holds'] as String,
              status: RuleStatus.values.byName(r['status'] as String),
              lift: _num(r['lift']),
              liftLow: _num(r['lift_low']),
              liftHigh: _num(r['lift_high']),
              statusNote: r['status_note'] as String?,
            ))
        .toList();
  }

  @override
  Future<List<BacktestRow>> backtest() async {
    final rows = await _client.from('backtest_rows').select().order('id');
    return rows
        .map((r) => BacktestRow(
              rule: r['rule'] as String,
              tierLabel: r['tier_label'] as String,
              flagged: r['flagged'] as int,
              laterExcluded: r['later_excluded'] as int,
              lift: _num(r['lift'])!,
              liftLow: _num(r['lift_low'])!,
              liftHigh: _num(r['lift_high'])!,
            ))
        .toList();
  }

  @override
  Future<List<PppScanRow>> pppScan() async {
    final rows = await _client.from('ppp_scan_rows').select().order('id');
    return rows
        .map((r) => PppScanRow(
              rule: r['rule'] as String,
              loansFlagged: r['loans_flagged'] as String,
              approvedAmount: _num(r['approved_amount'])!,
              note: r['note'] as String,
            ))
        .toList();
  }

  @override
  Future<List<DataSource>> dataSources() async {
    final rows = await _client.from('data_sources').select().order('id');
    return rows
        .map((r) => DataSource(
              name: r['name'] as String,
              publisher: r['publisher'] as String,
              holds: r['holds'] as String,
              pulled: r['pulled'] as String,
              limits: r['limits'] as String,
              url: r['url'] as String,
              live: r['live'] as bool,
            ))
        .toList();
  }

  @override
  Future<BiasAuditRun> latestBiasAudit() async {
    final r = await _client.from('bias_audit_runs').select().order('run_at', ascending: false).limit(1).single();
    return BiasAuditRun(
      id: r['id'] as String,
      runAt: DateTime.parse(r['run_at'] as String),
      rulesetVersion: r['ruleset_version'] as String,
      censusVintage: r['census_vintage'] as String,
      inputsBanned: (r['inputs_banned'] as List).cast<String>(),
      rows: (r['rows'] as List)
          .cast<Map<String, dynamic>>()
          .map((x) => BiasAuditRow(
                ruleId: x['ruleId'] as String,
                ruleName: x['ruleName'] as String,
                flagRateHighMinorityZips: _num(x['flagRateHighMinorityZips'])!,
                flagRateOtherZips: _num(x['flagRateOtherZips'])!,
                verdict: AuditVerdict.values.byName(x['verdict'] as String),
                note: x['note'] as String,
              ))
          .toList(),
    );
  }

  @override
  Future<List<HeatmapCell>> heatmap() async {
    final rows = await _client.from('heatmap_cells').select();
    return rows
        .map((r) => HeatmapCell(
              state: r['state'] as String,
              providersScored: r['providers_scored'] as int,
              flagsPer1000: _num(r['flags_per_1000'])!,
              dollarsAtIssue: _num(r['dollars_at_issue'])!,
            ))
        .toList();
  }

  @override
  Future<DashboardSummary> dashboard(AppUser user) async {
    final leads = (await _client.from('leads').select('status,hits')).toList();
    int count(LeadStatus s) => leads.where((l) => l['status'] == s.name).length;
    final audit = await latestBiasAudit();
    return DashboardSummary(
      leadsPendingReview: count(LeadStatus.pendingReview),
      tier1Verified: leads
          .where((l) => l['status'] != LeadStatus.closed.name && (l['hits'] as List).any((h) => h['tier'] == 1))
          .length,
      watchList: count(LeadStatus.watchList),
      licensed: count(LeadStatus.licensed),
      recordsScored: 1392616,
      lastRefresh: audit.runAt,
      rulesetVersion: audit.rulesetVersion,
      lastAuditVerdict: audit.overall,
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Stream<List<ScreenRequest>> watchScreens(AppUser user) {
    return _client
        .from('screen_requests')
        .stream(primaryKey: ['id'])
        .order('requested_at', ascending: false)
        .map((rows) => rows.map(_screenFromRow).toList());
  }

  @override
  Future<ScreenRequest> submitScreen({
    required AppUser user,
    required ScreenKind kind,
    required List<String> npis,
    String? targetLabel,
  }) async {
    final row = await _client
        .from('screen_requests')
        .insert({
          'kind': kind.name,
          'npis': npis,
          'target_label': targetLabel,
          'requested_by': user.id,
          'org_id': user.orgId,
        })
        .select()
        .single();
    await _append(AccessAction.ranScreen, user, detail: '${row['id']} ${kind.label}, ${npis.length} NPIs');
    return _screenFromRow(row, requesterEmail: user.email);
  }

  @override
  Future<List<AccessLogEntry>> accessLog(AppUser user) async {
    final rows = await _client.from('access_log').select().order('at', ascending: false).limit(200);
    return rows
        .map((r) => AccessLogEntry(
              id: '${r['id']}',
              at: DateTime.parse(r['at'] as String),
              userId: r['user_id'] as String,
              userEmail: r['user_email'] as String,
              orgId: r['org_id'] as String,
              action: AccessAction.values.byName(r['action'] as String),
              leadId: r['lead_id'] as String?,
              detail: r['detail'] as String?,
            ))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Row mapping
  // ---------------------------------------------------------------------------

  static double? _num(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  Lead _leadFromRow(Map<String, dynamic> r) {
    final hits = (r['hits'] as List).cast<Map<String, dynamic>>().map((h) {
      final pd = h['peerDistribution'] as Map<String, dynamic>?;
      return SignalHit(
        ruleId: h['ruleId'] as String,
        tier: Tier.values[(h['tier'] as int) - 1],
        headline: h['headline'] as String,
        rawValues: (h['rawValues'] as Map).map((k, v) => MapEntry('$k', '$v')),
        subjectValue: _num(h['subjectValue']),
        peerDistribution: pd == null
            ? null
            : PeerDistribution(
                peerGroup: pd['peerGroup'] as String,
                peerCount: pd['peerCount'] as int,
                p50: _num(pd['p50'])!,
                p75: _num(pd['p75'])!,
                p90: _num(pd['p90'])!,
                p95: _num(pd['p95'])!,
                p99: _num(pd['p99'])!,
                unit: pd['unit'] as String,
              ),
      );
    }).toList();
    final prov = r['provenance'] as Map<String, dynamic>;
    return Lead(
      id: r['id'] as String,
      program: Program.values.byName(r['program'] as String),
      entityRef: r['entity_ref'] as String,
      entityKind: r['entity_kind'] as String,
      state: r['state'] as String,
      specialtyOrIndustry: r['specialty_or_industry'] as String,
      dollarsAtIssue: _num(r['dollars_at_issue'])!,
      status: LeadStatus.values.byName(r['status'] as String),
      hits: hits,
      innocentExplanations: (r['innocent_explanations'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => InnocentExplanation(explanation: e['explanation'] as String, whyItFails: e['whyItFails'] as String))
          .toList(),
      provenance: Provenance(
        sourceName: prov['sourceName'] as String,
        sourceUrl: prov['sourceUrl'] as String,
        datasetVersion: prov['datasetVersion'] as String,
        query: prov['query'] as String,
        rowCount: prov['rowCount'] as int,
        sha256: prov['sha256'] as String,
        pulledAt: DateTime.parse(prov['pulledAt'] as String),
        rulesetVersion: prov['rulesetVersion'] as String,
      ),
      createdAt: DateTime.parse(r['created_at'] as String),
      licensedToOrgId: r['licensed_to_org_id'] as String?,
      signedOffBy: r['signed_off_by'] as String?,
      signedOffAt: r['signed_off_at'] == null ? null : DateTime.parse(r['signed_off_at'] as String),
      investigationNotes: r['investigation_notes'] as String?,
      firstViewedAt: r['first_viewed_at'] == null ? null : DateTime.parse(r['first_viewed_at'] as String),
    );
  }

  ScreenRequest _screenFromRow(Map<String, dynamic> r, {String? requesterEmail}) {
    final res = r['result'] as Map<String, dynamic>?;
    return ScreenRequest(
      id: r['id'] as String,
      kind: ScreenKind.values.byName(r['kind'] as String),
      npis: (r['npis'] as List).cast<String>(),
      targetLabel: r['target_label'] as String?,
      requestedBy: requesterEmail ?? (r['requested_by'] as String),
      requestedAt: DateTime.parse(r['requested_at'] as String),
      status: ScreenStatus.values.byName(r['status'] as String),
      result: res == null
          ? null
          : ScreenResult(
              npisScreened: res['npisScreened'] as int,
              tier1Hits: res['tier1Hits'] as int,
              tier2Hits: res['tier2Hits'] as int,
              dollarsAtIssue: _num(res['dollarsAtIssue'])!,
              summary: res['summary'] as String,
              rulesetVersion: res['rulesetVersion'] as String,
            ),
    );
  }
}
