/// Domain models for the Fraud Signal client.
///
/// Everything here mirrors the product plan in `docs/product-plan.md`:
/// tiered rules, a lead gate, an evidence card on every flag, and access
/// controls that log every lead view. Output is always a *risk indicator*,
/// never an accusation.
library;

enum Program {
  medicare('Medicare', 'MCR'),
  ppp('PPP', 'PPP'),
  childCare('Child care & meals', 'CCM'),
  all('All programs', 'ALL');

  const Program(this.label, this.code);
  final String label;
  final String code;

  /// Materiality floor for the lead gate, in dollars.
  double get materialityFloor => switch (this) {
        Program.medicare => 500000,
        Program.ppp => 1000000,
        Program.childCare => 500000,
        Program.all => 500000,
      };
}

enum Tier {
  hardRule(1, 'Hard rule', 'A program rule or arithmetic makes the record impossible as reported.'),
  peerOutlier(2, 'Peer outlier', 'Far outside a matched peer group. Strong, but never enough alone.'),
  link(3, 'Link', 'Shared addresses, ownership or lender patterns. Corroborates, never decides.');

  const Tier(this.number, this.label, this.description);
  final int number;
  final String label;
  final String description;
}

enum RuleStatus {
  active('Active'),
  notValidated('Not yet validated'),
  dropped('Dropped'),
  planned('Planned');

  const RuleStatus(this.label);
  final String label;
}

class Rule {
  const Rule({
    required this.id,
    required this.name,
    required this.program,
    required this.tier,
    required this.whyItHolds,
    required this.status,
    this.lift,
    this.liftLow,
    this.liftHigh,
    this.statusNote,
  });

  final String id;
  final String name;
  final Program program;
  final Tier tier;
  final String whyItHolds;
  final RuleStatus status;

  /// Back-tested lift over base rate, when measured.
  final double? lift;
  final double? liftLow;
  final double? liftHigh;
  final String? statusNote;
}

/// One rule firing on one record.
class SignalHit {
  const SignalHit({
    required this.ruleId,
    required this.tier,
    required this.headline,
    required this.rawValues,
    this.peerDistribution,
    this.subjectValue,
  });

  final String ruleId;
  final Tier tier;
  final String headline;

  /// Raw values a reviewer can re-check from the source record.
  final Map<String, String> rawValues;

  /// Peer percentiles (p50, p75, p90, p95, p99) for Tier 2 hits.
  final PeerDistribution? peerDistribution;
  final double? subjectValue;
}

class PeerDistribution {
  const PeerDistribution({
    required this.peerGroup,
    required this.peerCount,
    required this.p50,
    required this.p75,
    required this.p90,
    required this.p95,
    required this.p99,
    required this.unit,
  });

  final String peerGroup;
  final int peerCount;
  final double p50, p75, p90, p95, p99;
  final String unit;
}

class InnocentExplanation {
  const InnocentExplanation({required this.explanation, required this.whyItFails});
  final String explanation;
  final String whyItFails;
}

/// Provenance for a lead: enough to re-derive it later.
class Provenance {
  const Provenance({
    required this.sourceName,
    required this.sourceUrl,
    required this.datasetVersion,
    required this.query,
    required this.rowCount,
    required this.sha256,
    required this.pulledAt,
    required this.rulesetVersion,
  });

  final String sourceName;
  final String sourceUrl;
  final String datasetVersion;
  final String query;
  final int rowCount;
  final String sha256;
  final DateTime pulledAt;
  final String rulesetVersion;
}

enum LeadStatus {
  watchList('Watch list', 'Below the lead gate. Internal only.'),
  pendingReview('Pending review', 'Passed the gate. Needs analyst sign-off.'),
  signedOff('Signed off', 'Reviewed. Eligible for licensing.'),
  licensed('Licensed', 'Exclusively licensed to one buyer.'),
  reserved('Reserved', 'Held for an internal filing.'),
  closed('Closed', 'Innocent explanation confirmed.');

  const LeadStatus(this.label, this.description);
  final String label;
  final String description;
}

class Lead {
  const Lead({
    required this.id,
    required this.program,
    required this.entityRef,
    required this.entityKind,
    required this.state,
    required this.specialtyOrIndustry,
    required this.dollarsAtIssue,
    required this.hits,
    required this.status,
    required this.innocentExplanations,
    required this.provenance,
    required this.createdAt,
    this.licensedToOrgId,
    this.signedOffBy,
    this.signedOffAt,
    this.investigationNotes,
    this.firstViewedAt,
  });

  final String id;
  final Program program;

  /// Entity identifier as it appears in the source (NPI, loan number).
  /// Demo data uses synthetic identifiers only.
  final String entityRef;
  final String entityKind;
  final String state;
  final String specialtyOrIndustry;
  final double dollarsAtIssue;
  final List<SignalHit> hits;
  final LeadStatus status;
  final List<InnocentExplanation> innocentExplanations;
  final Provenance provenance;
  final DateTime createdAt;
  final String? licensedToOrgId;
  final String? signedOffBy;
  final DateTime? signedOffAt;
  final String? investigationNotes;
  final DateTime? firstViewedAt;

  int get tier1Count => hits.where((h) => h.tier == Tier.hardRule).length;
  int get tier2Count => hits.where((h) => h.tier == Tier.peerOutlier).length;
  int get tier3Count => hits.where((h) => h.tier == Tier.link).length;
  Tier get strongestTier => hits.map((h) => h.tier).reduce((a, b) => a.number <= b.number ? a : b);

  Lead copyWith({
    LeadStatus? status,
    String? licensedToOrgId,
    String? signedOffBy,
    DateTime? signedOffAt,
    String? investigationNotes,
    DateTime? firstViewedAt,
  }) {
    return Lead(
      id: id,
      program: program,
      entityRef: entityRef,
      entityKind: entityKind,
      state: state,
      specialtyOrIndustry: specialtyOrIndustry,
      dollarsAtIssue: dollarsAtIssue,
      hits: hits,
      status: status ?? this.status,
      innocentExplanations: innocentExplanations,
      provenance: provenance,
      createdAt: createdAt,
      licensedToOrgId: licensedToOrgId ?? this.licensedToOrgId,
      signedOffBy: signedOffBy ?? this.signedOffBy,
      signedOffAt: signedOffAt ?? this.signedOffAt,
      investigationNotes: investigationNotes ?? this.investigationNotes,
      firstViewedAt: firstViewedAt ?? this.firstViewedAt,
    );
  }
}

class BacktestRow {
  const BacktestRow({
    required this.rule,
    required this.tierLabel,
    required this.flagged,
    required this.laterExcluded,
    required this.lift,
    required this.liftLow,
    required this.liftHigh,
  });

  final String rule;
  final String tierLabel;
  final int flagged;
  final int laterExcluded;
  final double lift;
  final double liftLow;
  final double liftHigh;

  /// An interval reaching below 1x means the rule may be no better than chance.
  bool get significant => liftLow > 1;
}

class PppScanRow {
  const PppScanRow({
    required this.rule,
    required this.loansFlagged,
    required this.approvedAmount,
    required this.note,
  });
  final String rule;
  final String loansFlagged;
  final double approvedAmount;
  final String note;
}

class DataSource {
  const DataSource({
    required this.name,
    required this.publisher,
    required this.holds,
    required this.pulled,
    required this.limits,
    required this.url,
    required this.live,
  });
  final String name;
  final String publisher;
  final String holds;
  final String pulled;
  final String limits;
  final String url;
  final bool live;
}

// ---------------------------------------------------------------------------
// Organizations, users, roles and access
// ---------------------------------------------------------------------------

/// The commercial offer an organization holds. Decides what the app shows.
enum OfferTier {
  diligenceScreen('Diligence screen', 'Exposure report on a target, per report under NDA.'),
  complianceSelfAudit('Compliance self-audit', 'Same screen on your own NPIs. Org-verified.'),
  screeningSubscription('Screening subscription', 'All-provider risk scores, monthly refresh, API.'),
  exclusiveCasePackage('Exclusive case package', 'One lead, exclusively licensed, with evidence card.'),
  internal('Internal', 'Brilliant Disruptions analysts and reviewers.');

  const OfferTier(this.label, this.description);
  final String label;
  final String description;

  /// Case-package buyers never get bulk export.
  bool get allowsBulkExport => this == OfferTier.screeningSubscription || this == OfferTier.internal;
}

enum Role {
  viewer('Viewer', 'Reads leads licensed to the org. Every view is logged.'),
  analyst('Analyst', 'Runs screens and drafts investigation notes.'),
  reviewer('Reviewer', 'Signs off leads before release. Internal only.'),
  admin('Admin', 'Manages seats and sees the org access log.');

  const Role(this.label, this.description);
  final String label;
  final String description;

  bool get canSignOff => this == Role.reviewer;
  bool get canRunScreens => this != Role.viewer;
  bool get canSeeOrgLog => this == Role.admin || this == Role.reviewer;
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.offer,
    required this.identityVerified,
    required this.seats,
    this.ownNpis = const [],
  });
  final String id;
  final String name;
  final OfferTier offer;
  final bool identityVerified;
  final int seats;

  /// For compliance self-audits: the NPIs this org has proven it owns.
  final List<String> ownNpis;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.orgId,
  });
  final String id;
  final String email;
  final String displayName;
  final Role role;
  final String orgId;
}

enum AccessAction {
  viewedLead('Viewed lead'),
  exportedEvidence('Exported evidence card'),
  signedOff('Signed off'),
  licensed('Licensed'),
  ranScreen('Ran screen'),
  signedIn('Signed in');

  const AccessAction(this.label);
  final String label;
}

class AccessLogEntry {
  const AccessLogEntry({
    required this.id,
    required this.at,
    required this.userId,
    required this.userEmail,
    required this.orgId,
    required this.action,
    this.leadId,
    this.detail,
  });
  final String id;
  final DateTime at;
  final String userId;
  final String userEmail;
  final String orgId;
  final AccessAction action;
  final String? leadId;
  final String? detail;
}

// ---------------------------------------------------------------------------
// Screens (diligence / self-audit requests)
// ---------------------------------------------------------------------------

enum ScreenKind {
  diligence('Diligence screen', 'Exposure report on a target you are acquiring or lending to.'),
  selfAudit('Compliance self-audit', 'Run the same rules on NPIs your organization owns.');

  const ScreenKind(this.label, this.description);
  final String label;
  final String description;
}

enum ScreenStatus {
  queued('Queued'),
  running('Running'),
  complete('Complete'),
  failed('Failed');

  const ScreenStatus(this.label);
  final String label;
}

class ScreenRequest {
  const ScreenRequest({
    required this.id,
    required this.kind,
    required this.npis,
    required this.requestedBy,
    required this.requestedAt,
    required this.status,
    this.targetLabel,
    this.result,
  });
  final String id;
  final ScreenKind kind;
  final List<String> npis;
  final String requestedBy;
  final DateTime requestedAt;
  final ScreenStatus status;
  final String? targetLabel;
  final ScreenResult? result;
}

class ScreenResult {
  const ScreenResult({
    required this.npisScreened,
    required this.tier1Hits,
    required this.tier2Hits,
    required this.dollarsAtIssue,
    required this.summary,
    required this.rulesetVersion,
  });
  final int npisScreened;
  final int tier1Hits;
  final int tier2Hits;
  final double dollarsAtIssue;
  final String summary;
  final String rulesetVersion;
}

// ---------------------------------------------------------------------------
// Bias audit
// ---------------------------------------------------------------------------

enum AuditVerdict {
  pass('Pass'),
  watch('Watch'),
  fail('Fail');

  const AuditVerdict(this.label);
  final String label;
}

class BiasAuditRow {
  const BiasAuditRow({
    required this.ruleId,
    required this.ruleName,
    required this.flagRateHighMinorityZips,
    required this.flagRateOtherZips,
    required this.verdict,
    required this.note,
  });
  final String ruleId;
  final String ruleName;

  /// Flag rate per 1,000 records in ZIPs above the median minority share.
  final double flagRateHighMinorityZips;
  final double flagRateOtherZips;
  final AuditVerdict verdict;
  final String note;

  double get ratio => flagRateOtherZips == 0 ? 0 : flagRateHighMinorityZips / flagRateOtherZips;
}

class BiasAuditRun {
  const BiasAuditRun({
    required this.id,
    required this.runAt,
    required this.rulesetVersion,
    required this.censusVintage,
    required this.rows,
    required this.inputsBanned,
  });
  final String id;
  final DateTime runAt;
  final String rulesetVersion;
  final String censusVintage;
  final List<BiasAuditRow> rows;

  /// Columns dropped on load and inputs that never feed a score.
  final List<String> inputsBanned;

  AuditVerdict get overall {
    if (rows.any((r) => r.verdict == AuditVerdict.fail)) return AuditVerdict.fail;
    if (rows.any((r) => r.verdict == AuditVerdict.watch)) return AuditVerdict.watch;
    return AuditVerdict.pass;
  }
}

// ---------------------------------------------------------------------------
// Aggregate heatmap (the only public layer; no names)
// ---------------------------------------------------------------------------

class HeatmapCell {
  const HeatmapCell({
    required this.state,
    required this.providersScored,
    required this.flagsPer1000,
    required this.dollarsAtIssue,
  });
  final String state;
  final int providersScored;
  final double flagsPer1000;
  final double dollarsAtIssue;
}

class DashboardSummary {
  const DashboardSummary({
    required this.leadsPendingReview,
    required this.tier1Verified,
    required this.watchList,
    required this.licensed,
    required this.recordsScored,
    required this.lastRefresh,
    required this.rulesetVersion,
    required this.lastAuditVerdict,
  });
  final int leadsPendingReview;
  final int tier1Verified;
  final int watchList;
  final int licensed;
  final int recordsScored;
  final DateTime lastRefresh;
  final String rulesetVersion;
  final AuditVerdict lastAuditVerdict;
}
