/// Synthetic demo data.
///
/// Every identifier, name and amount here is invented. Nothing identifies a
/// real provider, borrower or person. The figures in the rules catalog and the
/// back-test tables are the measured results from the product plan; the leads
/// are illustrative records shaped like real engine output.
library;

import '../domain/models.dart';
import '../domain/rules_engine.dart';

final DateTime _pulledAt = DateTime(2026, 10, 20, 14, 12);

const Organization demoInternalOrg = Organization(
  id: 'org_bd',
  name: 'Brilliant Disruptions',
  offer: OfferTier.internal,
  identityVerified: true,
  seats: 5,
);

const Organization demoBuyerOrg = Organization(
  id: 'org_qt1',
  name: 'Harbor & Vale LLP (demo)',
  offer: OfferTier.exclusiveCasePackage,
  identityVerified: true,
  seats: 3,
);

const Organization demoSelfAuditOrg = Organization(
  id: 'org_sa1',
  name: 'Cumberland Health Partners (demo)',
  offer: OfferTier.complianceSelfAudit,
  identityVerified: true,
  seats: 2,
  ownNpis: ['1999990101', '1999990102', '1999990103'],
);

const List<Organization> demoOrgs = [demoInternalOrg, demoBuyerOrg, demoSelfAuditOrg];

/// Demo accounts. Password for all is `demo`.
const List<AppUser> demoUsers = [
  AppUser(id: 'u_rev', email: 'reviewer@demo.fraudsignal', displayName: 'Demo Reviewer', role: Role.reviewer, orgId: 'org_bd'),
  AppUser(id: 'u_ana', email: 'analyst@demo.fraudsignal', displayName: 'Demo Analyst', role: Role.analyst, orgId: 'org_bd'),
  AppUser(id: 'u_buy', email: 'counsel@demo.fraudsignal', displayName: 'Demo Counsel', role: Role.viewer, orgId: 'org_qt1'),
  AppUser(id: 'u_cmp', email: 'compliance@demo.fraudsignal', displayName: 'Demo Compliance Lead', role: Role.admin, orgId: 'org_sa1'),
];

const List<Rule> demoRules = [
  Rule(
    id: 'mcr_excluded_paid',
    name: 'Excluded provider still paid',
    program: Program.medicare,
    tier: Tier.hardRule,
    whyItHolds: 'NPI on the OIG exclusion list before the service year, still in CMS payment data. Payment to an excluded provider breaks program rules on its face.',
    status: RuleStatus.active,
    statusNote: 'Present-tense finding, not a prediction. One identity-verified case in the 2019 cross-match.',
  ),
  Rule(
    id: 'mcr_lifetime_visits',
    name: 'Once-per-lifetime visits billed more than once per patient',
    program: Program.medicare,
    tier: Tier.hardRule,
    whyItHolds: 'Welcome to Medicare and the initial annual wellness visit can be billed once per patient.',
    status: RuleStatus.dropped,
    statusNote: 'Dropped after back-test: Medicare claim edits already block repeats. No hits in 41,995 rows.',
  ),
  Rule(
    id: 'mcr_impossible_hours',
    name: 'Impossible hours',
    program: Program.medicare,
    tier: Tier.hardRule,
    whyItHolds: 'Time-based codes adding up to more than 12 hours a day, 250 days a year, using each code\'s minimum time.',
    status: RuleStatus.active,
    lift: 40, liftLow: 7, liftHigh: 204,
    statusNote: 'Best rule in the back-test. Open explanation: assistants billing under the supervisor.',
  ),
  Rule(
    id: 'ppp_loan_per_job',
    name: 'Loan per reported job above the statutory ceiling',
    program: Program.ppp,
    tier: Tier.hardRule,
    whyItHolds: 'The loan formula caps it: 2.5 months of payroll, pay capped at \$100K a year (\$20,833 first draw; \$29,167 for restaurants and hotels on second draw). EIDL refinance netted out.',
    status: RuleStatus.notValidated,
    statusNote: 'No public label set exists for PPP yet.',
  ),
  Rule(
    id: 'ppp_second_draw_jobs',
    name: 'Second-draw loan reporting more than 300 jobs',
    program: Program.ppp,
    tier: Tier.hardRule,
    whyItHolds: 'Second draws required 300 or fewer employees.',
    status: RuleStatus.notValidated,
  ),
  Rule(
    id: 'ppp_duplicate_first_draw',
    name: 'Two first-draw loans to the same business',
    program: Program.ppp,
    tier: Tier.hardRule,
    whyItHolds: 'Each business could take only one first-draw loan.',
    status: RuleStatus.notValidated,
  ),
  Rule(
    id: 'mcr_peer_p99',
    name: 'Level 5 visit share, payment per patient, or services per patient above the 99th percentile of peers',
    program: Program.medicare,
    tier: Tier.peerOutlier,
    whyItHolds: 'Peer-matched by specialty and state to absorb patient mix.',
    status: RuleStatus.active,
    lift: 2, liftLow: 0.8, liftHigh: 6.8,
    statusNote: 'Any single Tier 2 signal ran about 2x chance and was not significant. Never a lead alone.',
  ),
  Rule(
    id: 'mcr_high_risk_codes',
    name: 'High-risk code concentration',
    program: Program.medicare,
    tier: Tier.peerOutlier,
    whyItHolds: 'Skin substitutes, genetic tests, urine drug panels, braces, non-emergency ambulance: the code families behind recent DOJ takedowns.',
    status: RuleStatus.active,
  ),
  Rule(
    id: 'mcr_yoy_spike',
    name: 'Year-over-year billing spike of 5x or more from a new or dormant provider',
    program: Program.medicare,
    tier: Tier.peerOutlier,
    whyItHolds: 'Fits the bust-out pattern seen in recent schemes.',
    status: RuleStatus.active,
  ),
  Rule(
    id: 'ppp_affiliation',
    name: 'Borrower affiliated with a large or public parent company',
    program: Program.ppp,
    tier: Tier.peerOutlier,
    whyItHolds: 'Affiliation drove most PPP False Claims Act settlements to date.',
    status: RuleStatus.notValidated,
  ),
  Rule(
    id: 'ppp_address_lender',
    name: 'Many loans at one residential address, or lender fraud rates far above peers',
    program: Program.ppp,
    tier: Tier.link,
    whyItHolds: 'Ring and lender patterns; corroborates, never decides.',
    status: RuleStatus.notValidated,
  ),
  Rule(
    id: 'ccm_over_capacity',
    name: 'Children or meals billed above licensed capacity',
    program: Program.childCare,
    tier: Tier.hardRule,
    whyItHolds: 'Licensed capacity is a legal cap; billing above it cannot all be real.',
    status: RuleStatus.planned,
    statusNote: 'Needs state licensing and payment data. Public-records requests go out in Phase 1.',
  ),
  Rule(
    id: 'ccm_closed_site',
    name: 'Claims on days or at sites that were closed',
    program: Program.childCare,
    tier: Tier.hardRule,
    whyItHolds: 'A closed site serves no one; the meal claims at a closed park are the textbook case.',
    status: RuleStatus.planned,
  ),
  Rule(
    id: 'all_new_entity_payments',
    name: 'Large payments within months of the entity forming',
    program: Program.all,
    tier: Tier.peerOutlier,
    whyItHolds: 'Fits the bust-out pattern; legitimate new businesses also grow fast, so never alone.',
    status: RuleStatus.planned,
    statusNote: 'Needs secretary-of-state formation dates.',
  ),
  Rule(
    id: 'all_network',
    name: 'Network: shared officers, registered agents or addresses, with payments flowing between them',
    program: Program.all,
    tier: Tier.link,
    whyItHolds: 'Exposes rings through relationships, never names; raises priority of an already-flagged entity.',
    status: RuleStatus.planned,
  ),
];

Rule ruleById(String id) => demoRules.firstWhere((r) => r.id == id);

const List<BacktestRow> demoBacktest = [
  BacktestRow(rule: 'Impossible hours, over 2,500 h', tierLabel: '1', flagged: 79, laterExcluded: 2, lift: 37, liftLow: 10, liftHigh: 129),
  BacktestRow(rule: 'Impossible hours, over 3,000 h', tierLabel: '1', flagged: 37, laterExcluded: 1, lift: 40, liftLow: 7, liftHigh: 204),
  BacktestRow(rule: 'Lead gate (Tier 1 or two Tier 2)', tierLabel: 'Combined', flagged: 178, laterExcluded: 1, lift: 8, liftLow: 1.5, liftHigh: 46),
  BacktestRow(rule: 'Visits per patient, 90837', tierLabel: '2', flagged: 185, laterExcluded: 1, lift: 7, liftLow: 1.2, liftHigh: 37),
  BacktestRow(rule: 'Visits per patient, 90834', tierLabel: '2', flagged: 195, laterExcluded: 1, lift: 6, liftLow: 1.1, liftHigh: 35),
  BacktestRow(rule: 'Visits per patient, 97110', tierLabel: '2', flagged: 665, laterExcluded: 1, lift: 3, liftLow: 0.5, liftHigh: 16),
  BacktestRow(rule: 'Any single Tier 2 signal', tierLabel: '2', flagged: 1907, laterExcluded: 3, lift: 2, liftLow: 0.8, liftHigh: 6.8),
];

const List<PppScanRow> demoPppScan = [
  PppScanRow(rule: 'Loan per job above 2x the formula ceiling, EIDL refinance netted out', loansFlagged: '6,213 (1,367 over \$1M)', approvedAmount: 5.38e9, note: 'Median \$61,667 per reported job'),
  PppScanRow(rule: 'Two first-draw loans to one business', loansFlagged: '423 loans in 208 groups', approvedAmount: 300.6e6, note: '69 groups over \$1M'),
  PppScanRow(rule: 'Second draw reporting more than 300 jobs', loansFlagged: '3', approvedAmount: 5.1e6, note: 'All report exactly 500 jobs, possibly a placeholder'),
];

const List<DataSource> demoSources = [
  DataSource(name: 'Physician & Other Practitioners, by Provider and Service, 2019', publisher: 'CMS', holds: '10,140,228 rows: provider by billing code, with patients, services and average payment', pulled: '318,492 rows for the 14 test codes', limits: 'Cells under 11 patients are suppressed', url: 'https://data.cms.gov/', live: true),
  DataSource(name: 'Physician & Other Practitioners, by Provider, 2019', publisher: 'CMS', holds: 'One row per provider: totals, plus average patient risk score', pulled: 'Queried for 4,161 excluded providers', limits: 'Risk score is useful for fairer peer groups', url: 'https://data.cms.gov/', live: true),
  DataSource(name: 'List of Excluded Individuals/Entities, 09-2026', publisher: 'HHS Office of Inspector General', holds: '84,093 current exclusions, with legal basis and date', pulled: 'Full file', limits: 'Only 8,924 records (10.6%) carry an NPI, so labels undercount', url: 'https://oig.hhs.gov/exclusions/leie-database-supplement-downloads/', live: true),
  DataSource(name: 'PPP loan-level data, loans of \$150K and up, Sept 2024 release', publisher: 'SBA', holds: '968,524 loans totaling \$515.5B', pulled: 'Full file (452 MB), streamed', limits: 'Jobs are self-reported; race, ethnicity, gender and veteran columns are never read', url: 'https://data.sba.gov/dataset/ppp-foia', live: true),
  DataSource(name: 'Child care licensing and payment records', publisher: 'State human services agencies', holds: 'Licensed capacity and inspections per site; payments per provider where released', pulled: 'Not yet', limits: 'Payments often need a public-records request, so file early', url: '', live: false),
  DataSource(name: 'Child nutrition program sites and claims', publisher: 'State agencies that run USDA meal programs', holds: 'Sponsors, sites, and meals claimed by site and month', pulled: 'Not yet', limits: 'Usually by public-records request; detail varies by state', url: '', live: false),
  DataSource(name: 'Business registries', publisher: 'Secretaries of state', holds: 'Formation date, officers, registered agent and address for the network rule', pulled: 'Not yet', limits: 'Format differs by state; some sell bulk files', url: '', live: false),
  DataSource(name: 'American Community Survey', publisher: 'U.S. Census Bureau', holds: 'Area demographics by ZIP code', pulled: 'Not yet', limits: 'Used only for the bias audit, never as a score input', url: '', live: false),
];

Provenance _cmsProvenance(String query, int rows, String hash) => Provenance(
      sourceName: 'CMS Physician & Other Practitioners, by Provider and Service, 2019',
      sourceUrl: 'https://data.cms.gov/',
      datasetVersion: '2019 (released 2021-06-17, API snapshot 2026-10-20)',
      query: query,
      rowCount: rows,
      sha256: hash,
      pulledAt: _pulledAt,
      rulesetVersion: rulesetVersion,
    );

Provenance _pppProvenance(String query, int rows, String hash) => Provenance(
      sourceName: 'SBA PPP loan-level data, \$150K and up, Sept 2024 release',
      sourceUrl: 'https://data.sba.gov/dataset/ppp-foia',
      datasetVersion: 'public_150k_plus_240930.csv',
      query: query,
      rowCount: rows,
      sha256: hash,
      pulledAt: _pulledAt,
      rulesetVersion: rulesetVersion,
    );

/// Illustrative leads. Identifiers are synthetic (NPIs start 199999, loan
/// numbers start DEMO). Amounts are invented to exercise the gate.
final List<Lead> demoLeads = [
  Lead(
    id: 'L-2026-0001',
    program: Program.medicare,
    entityRef: 'NPI 1999990001',
    entityKind: 'Individual provider',
    state: 'TN',
    specialtyOrIndustry: 'Psychiatry',
    dollarsAtIssue: 1184320,
    status: LeadStatus.signedOff,
    createdAt: DateTime(2026, 10, 20, 15, 2),
    signedOffBy: 'reviewer@demo.fraudsignal',
    signedOffAt: DateTime(2026, 10, 21, 9, 40),
    hits: const [
      SignalHit(
        ruleId: 'mcr_impossible_hours',
        tier: Tier.hardRule,
        headline: '3,412 minimum hours across 90837 and 90834 in 2019 (cap 3,000)',
        rawValues: {
          '90837 services': '2,860',
          '90837 minimum minutes': '53',
          '90834 services': '1,390',
          '90834 minimum minutes': '38',
          'Total minimum hours': '3,406.3',
          'Threshold': '12 h × 250 d = 3,000 h',
        },
      ),
      SignalHit(
        ruleId: 'mcr_peer_p99',
        tier: Tier.peerOutlier,
        headline: 'Visits per patient on 90837 at the 99.6th percentile of TN psychiatry',
        rawValues: {'Patients (90837)': '96', 'Services (90837)': '2,860', 'Visits per patient': '29.8'},
        subjectValue: 29.8,
        peerDistribution: PeerDistribution(peerGroup: 'Psychiatry, TN, office', peerCount: 412, p50: 7.1, p75: 10.4, p90: 14.9, p95: 18.2, p99: 26.0, unit: 'visits per patient'),
      ),
    ],
    innocentExplanations: const [
      InnocentExplanation(explanation: 'Group practice billing under one NPI', whyItFails: 'Provider enrolled as an individual with no reassigned billing; CMS by-provider file shows a single rendering NPI.'),
      InnocentExplanation(explanation: 'Assistants or trainees billing under the supervisor', whyItFails: 'Open. Psychotherapy codes do not permit incident-to billing by unlicensed staff, but a supervising arrangement is possible. Flagged for claims review.'),
      InnocentExplanation(explanation: 'Data-entry error in service counts', whyItFails: 'Counts match across the by-provider and by-service files and across two API pulls.'),
      InnocentExplanation(explanation: 'Facility vs. office billing difference', whyItFails: 'Place of service is office for 98% of lines; the minimum-time check is place-independent.'),
    ],
    provenance: _cmsProvenance('filter[Rndrng_NPI]=1999990001&filter[HCPCS_Cd][in]=90837,90834', 2, 'a3f1…9c2e (demo)'),
    investigationNotes: 'Verify supervising-provider arrangements through state licensing board before handoff.',
    firstViewedAt: DateTime(2026, 10, 21, 9, 12),
  ),
  Lead(
    id: 'L-2026-0002',
    program: Program.medicare,
    entityRef: 'NPI 1999990002',
    entityKind: 'Individual provider',
    state: 'FL',
    specialtyOrIndustry: 'Oncology',
    dollarsAtIssue: 392140,
    status: LeadStatus.reserved,
    createdAt: DateTime(2026, 10, 20, 15, 2),
    hits: const [
      SignalHit(
        ruleId: 'mcr_excluded_paid',
        tier: Tier.hardRule,
        headline: 'Excluded by OIG in 2016 for a program-related crime; paid \$392K in 2019',
        rawValues: {
          'LEIE exclusion date': '2016-05-19',
          'LEIE exclusion type': '1128(a)(1) program-related crime',
          'Reinstatement': 'None on file',
          'CMS 2019 total payment': '\$392,140',
          'Identity match': 'Name, state and specialty match on both records',
        },
      ),
    ],
    innocentExplanations: const [
      InnocentExplanation(explanation: 'Reinstated before 2019', whyItFails: 'No reinstatement record in LEIE 09-2026; exclusion is still current.'),
      InnocentExplanation(explanation: 'Different person with the same name', whyItFails: 'NPI appears on both records; state and specialty also match. Claims review is the next check.'),
      InnocentExplanation(explanation: 'Payments were later recouped', whyItFails: 'Unknown from public data. A recoupment would reduce dollars at issue, not the violation.'),
    ],
    provenance: _cmsProvenance('filter[Rndrng_NPI][in]=(4,161 LEIE NPIs with exclusion < 2019-01-01)', 4161, '7d08…41bb (demo)'),
    investigationNotes: 'Present-tense violation. Held for an internal filing; not for sale. Dollars are below the Medicare floor but Tier 1 verified findings bypass the watch list for review.',
  ),
  Lead(
    id: 'L-2026-0003',
    program: Program.ppp,
    entityRef: 'Loan DEMO-4471020',
    entityKind: 'Borrower',
    state: 'TX',
    specialtyOrIndustry: 'NAICS 621111 Offices of physicians',
    dollarsAtIssue: 2140000,
    status: LeadStatus.pendingReview,
    createdAt: DateTime(2026, 10, 20, 16, 30),
    hits: const [
      SignalHit(
        ruleId: 'ppp_loan_per_job',
        tier: Tier.hardRule,
        headline: '\$2.14M first draw for 18 reported jobs: \$118,889 per job (ceiling \$20,833)',
        rawValues: {
          'Approved amount': '\$2,140,000',
          'EIDL refinance': '\$0',
          'Jobs reported': '18',
          'Loan per job': '\$118,889',
          'Statutory ceiling': '\$20,833',
          'Multiple of ceiling': '5.7x',
        },
      ),
      SignalHit(
        ruleId: 'ppp_duplicate_first_draw',
        tier: Tier.hardRule,
        headline: 'Second first-draw loan to the same normalized business name and address',
        rawValues: {'Matched loan': 'DEMO-4471188', 'Matched amount': '\$1,960,000', 'Same lender': 'Yes', 'Days apart': '11'},
      ),
      SignalHit(
        ruleId: 'ppp_address_lender',
        tier: Tier.link,
        headline: 'Lender\'s flag rate is 4.1x the national rate for loans over \$1M',
        rawValues: {'Lender loans over \$1M': '2,310', 'Lender flag rate': '6.4%', 'National flag rate': '1.6%'},
      ),
    ],
    innocentExplanations: const [
      InnocentExplanation(explanation: 'Jobs field under-reported, payroll genuinely supports the loan', whyItFails: 'Open. Even at the \$100K pay cap, 18 jobs supports \$375K. Payroll records would resolve this.'),
      InnocentExplanation(explanation: 'Two legitimately separate entities with a shared name', whyItFails: 'Same street address, same lender, same NAICS, 11 days apart. Separate EINs would resolve this.'),
      InnocentExplanation(explanation: 'Legitimate affiliate exemption', whyItFails: 'No affiliation disclosed in the SBA file; exemption would not raise the per-job ceiling.'),
    ],
    provenance: _pppProvenance('LoanNumber IN (DEMO-4471020, DEMO-4471188)', 2, 'c91a…0e77 (demo)'),
  ),
  Lead(
    id: 'L-2026-0004',
    program: Program.medicare,
    entityRef: 'NPI 1999990004',
    entityKind: 'Individual provider',
    state: 'CA',
    specialtyOrIndustry: 'Physical therapy',
    dollarsAtIssue: 611900,
    status: LeadStatus.pendingReview,
    createdAt: DateTime(2026, 10, 20, 16, 45),
    hits: const [
      SignalHit(
        ruleId: 'mcr_peer_p99',
        tier: Tier.peerOutlier,
        headline: 'Services per patient on 97110 at the 99.2nd percentile of CA physical therapy',
        rawValues: {'Patients': '212', 'Services': '14,620', 'Services per patient': '69.0'},
        subjectValue: 69.0,
        peerDistribution: PeerDistribution(peerGroup: 'Physical therapy, CA, office', peerCount: 3180, p50: 18.4, p75: 26.1, p90: 36.8, p95: 45.0, p99: 62.5, unit: 'services per patient'),
      ),
      SignalHit(
        ruleId: 'mcr_yoy_spike',
        tier: Tier.peerOutlier,
        headline: 'Billing rose 6.3x from 2018 to 2019 after two dormant years',
        rawValues: {'2017 payment': '\$0', '2018 payment': '\$97,100', '2019 payment': '\$611,900', 'Spike': '6.3x'},
      ),
    ],
    innocentExplanations: const [
      InnocentExplanation(explanation: 'Practice acquired or merged, so volume moved to this NPI', whyItFails: 'Open. CMS by-provider file shows no change in practice address. A merger would show in state business records.'),
      InnocentExplanation(explanation: 'High-acuity patient mix', whyItFails: 'Average patient risk score is at the 48th percentile of peers.'),
      InnocentExplanation(explanation: 'Group billing under one NPI', whyItFails: 'Open. Enrolled as an individual. Reassignment records would resolve this.'),
    ],
    provenance: _cmsProvenance('filter[Rndrng_NPI]=1999990004&filter[HCPCS_Cd]=97110', 1, '55e2…ab10 (demo)'),
  ),
  Lead(
    id: 'L-2026-0005',
    program: Program.ppp,
    entityRef: 'Loan DEMO-5520981',
    entityKind: 'Borrower',
    state: 'GA',
    specialtyOrIndustry: 'NAICS 722511 Full-service restaurants',
    dollarsAtIssue: 1520000,
    status: LeadStatus.licensed,
    licensedToOrgId: 'org_qt1',
    createdAt: DateTime(2026, 10, 19, 11, 5),
    signedOffBy: 'reviewer@demo.fraudsignal',
    signedOffAt: DateTime(2026, 10, 20, 8, 15),
    firstViewedAt: DateTime(2026, 10, 20, 13, 2),
    hits: const [
      SignalHit(
        ruleId: 'ppp_second_draw_jobs',
        tier: Tier.hardRule,
        headline: 'Second draw reporting 500 jobs (cap 300)',
        rawValues: {'Draw': '2', 'Jobs reported': '500', 'Cap': '300', 'Approved amount': '\$1,520,000', 'Note': 'Exactly 500, possibly a placeholder'},
      ),
      SignalHit(
        ruleId: 'ppp_loan_per_job',
        tier: Tier.hardRule,
        headline: 'If jobs were 50 as on the first draw, loan per job is \$30,400 (NAICS 72 ceiling \$29,167)',
        rawValues: {'First-draw jobs': '50', 'Second-draw jobs': '500', 'Per job at 50': '\$30,400', 'Ceiling': '\$29,167'},
      ),
    ],
    innocentExplanations: const [
      InnocentExplanation(explanation: '500 is a data-entry placeholder; real headcount was eligible', whyItFails: 'Likely for the job count. The per-job check at the first-draw headcount still exceeds the ceiling by 4%.'),
      InnocentExplanation(explanation: 'Seasonal employer using the alternative payroll period', whyItFails: 'Open. Would raise allowed payroll; needs payroll records.'),
    ],
    provenance: _pppProvenance('LoanNumber = DEMO-5520981', 1, '0bd4…77f3 (demo)'),
    investigationNotes: 'Exclusively licensed. Handoff logged 2026-10-20 13:02 UTC.',
  ),
  Lead(
    id: 'W-2026-0117',
    program: Program.medicare,
    entityRef: 'NPI 1999990117',
    entityKind: 'Individual provider',
    state: 'OH',
    specialtyOrIndustry: 'Dermatology',
    dollarsAtIssue: 288400,
    status: LeadStatus.watchList,
    createdAt: DateTime(2026, 10, 20, 17, 1),
    hits: const [
      SignalHit(
        ruleId: 'mcr_high_risk_codes',
        tier: Tier.peerOutlier,
        headline: 'Skin substitute codes are 71% of payment (peer p99: 34%)',
        rawValues: {'Skin substitute payment share': '71%', 'Peer p99': '34%'},
        subjectValue: 71,
        peerDistribution: PeerDistribution(peerGroup: 'Dermatology, OH', peerCount: 290, p50: 2, p75: 6, p90: 15, p95: 22, p99: 34, unit: '% of payment'),
      ),
    ],
    innocentExplanations: const [
      InnocentExplanation(explanation: 'Wound-care subspecialty', whyItFails: 'Plausible. Single Tier 2 signal; stays on the watch list.'),
    ],
    provenance: _cmsProvenance('filter[Rndrng_NPI]=1999990117', 14, '9a71…c0d2 (demo)'),
  ),
  Lead(
    id: 'W-2026-0118',
    program: Program.ppp,
    entityRef: 'Loan DEMO-6103377',
    entityKind: 'Borrower',
    state: 'NV',
    specialtyOrIndustry: 'NAICS 541511 Custom computer programming',
    dollarsAtIssue: 640000,
    status: LeadStatus.watchList,
    createdAt: DateTime(2026, 10, 20, 17, 3),
    hits: const [
      SignalHit(
        ruleId: 'ppp_address_lender',
        tier: Tier.link,
        headline: '14 loans at the same residential address',
        rawValues: {'Loans at address': '14', 'Address type': 'Residential (USPS)', 'Total approved': '\$3.9M'},
      ),
    ],
    innocentExplanations: const [
      InnocentExplanation(explanation: 'Registered-agent or virtual-office address', whyItFails: 'Open. USPS marks it residential; a registered agent would show in state records.'),
    ],
    provenance: _pppProvenance('BorrowerAddress = (normalized, demo)', 14, '3c3c…e81a (demo)'),
  ),
];

final List<ScreenRequest> demoScreens = [
  ScreenRequest(
    id: 'S-0007',
    kind: ScreenKind.diligence,
    targetLabel: 'Project Magnolia (demo target)',
    npis: const ['1999990301', '1999990302', '1999990303', '1999990304'],
    requestedBy: 'analyst@demo.fraudsignal',
    requestedAt: DateTime(2026, 10, 18, 10, 20),
    status: ScreenStatus.complete,
    result: const ScreenResult(
      npisScreened: 4,
      tier1Hits: 0,
      tier2Hits: 1,
      dollarsAtIssue: 0,
      summary: 'No hard-rule violations. One peer outlier on level 5 visit share (p99.1) for one NPI; below the lead gate. Low exposure.',
      rulesetVersion: rulesetVersion,
    ),
  ),
  ScreenRequest(
    id: 'S-0008',
    kind: ScreenKind.selfAudit,
    targetLabel: 'Cumberland Health Partners',
    npis: const ['1999990101', '1999990102', '1999990103'],
    requestedBy: 'compliance@demo.fraudsignal',
    requestedAt: DateTime(2026, 10, 20, 9, 5),
    status: ScreenStatus.running,
  ),
];

final BiasAuditRun demoBiasAudit = BiasAuditRun(
  id: 'BA-2026-10-20',
  runAt: DateTime(2026, 10, 20, 18, 40),
  rulesetVersion: rulesetVersion,
  censusVintage: 'ACS 2020-2024 5-year, ZCTA',
  inputsBanned: const [
    'Owner and provider names never feed a score',
    'Inferring origin from a name is banned',
    'Race, ethnicity, gender and veteran columns dropped on load (PPP)',
    'Census demographics used only here, never as a score input',
  ],
  rows: const [
    BiasAuditRow(ruleId: 'mcr_impossible_hours', ruleName: 'Impossible hours', flagRateHighMinorityZips: 0.36, flagRateOtherZips: 0.33, verdict: AuditVerdict.pass, note: 'Ratio 1.09. Within tolerance.'),
    BiasAuditRow(ruleId: 'mcr_excluded_paid', ruleName: 'Excluded provider still paid', flagRateHighMinorityZips: 0.01, flagRateOtherZips: 0.01, verdict: AuditVerdict.pass, note: 'Too few flags to measure skew; rule is a direct program violation.'),
    BiasAuditRow(ruleId: 'mcr_peer_p99', ruleName: 'Peer outliers (p99)', flagRateHighMinorityZips: 11.2, flagRateOtherZips: 9.1, verdict: AuditVerdict.watch, note: 'Ratio 1.23. Urban concentration explains most of it; re-check with place-of-service peer groups.'),
    BiasAuditRow(ruleId: 'mcr_high_risk_codes', ruleName: 'High-risk code concentration', flagRateHighMinorityZips: 4.8, flagRateOtherZips: 4.5, verdict: AuditVerdict.pass, note: 'Ratio 1.07.'),
    BiasAuditRow(ruleId: 'ppp_loan_per_job', ruleName: 'Loan per job above ceiling', flagRateHighMinorityZips: 6.9, flagRateOtherZips: 6.2, verdict: AuditVerdict.pass, note: 'Ratio 1.11.'),
    BiasAuditRow(ruleId: 'ppp_address_lender', ruleName: 'Address and lender links', flagRateHighMinorityZips: 3.1, flagRateOtherZips: 1.4, verdict: AuditVerdict.watch, note: 'Ratio 2.2. Driven by two lenders. Link rule never decides a lead; keep watching.'),
  ],
);

/// Aggregate, no-names heatmap. The only public layer.
const List<HeatmapCell> demoHeatmap = [
  HeatmapCell(state: 'FL', providersScored: 9120, flagsPer1000: 21.4, dollarsAtIssue: 61.2e6),
  HeatmapCell(state: 'TX', providersScored: 8410, flagsPer1000: 18.9, dollarsAtIssue: 54.0e6),
  HeatmapCell(state: 'CA', providersScored: 11230, flagsPer1000: 15.2, dollarsAtIssue: 58.7e6),
  HeatmapCell(state: 'NY', providersScored: 7890, flagsPer1000: 14.8, dollarsAtIssue: 44.1e6),
  HeatmapCell(state: 'MI', providersScored: 3900, flagsPer1000: 16.5, dollarsAtIssue: 20.3e6),
  HeatmapCell(state: 'NJ', providersScored: 3410, flagsPer1000: 15.9, dollarsAtIssue: 17.0e6),
  HeatmapCell(state: 'GA', providersScored: 3280, flagsPer1000: 14.1, dollarsAtIssue: 15.2e6),
  HeatmapCell(state: 'TN', providersScored: 2510, flagsPer1000: 13.7, dollarsAtIssue: 11.9e6),
  HeatmapCell(state: 'LA', providersScored: 1710, flagsPer1000: 17.8, dollarsAtIssue: 9.4e6),
  HeatmapCell(state: 'OH', providersScored: 4420, flagsPer1000: 11.2, dollarsAtIssue: 16.1e6),
  HeatmapCell(state: 'PA', providersScored: 5010, flagsPer1000: 10.4, dollarsAtIssue: 17.8e6),
  HeatmapCell(state: 'IL', providersScored: 4480, flagsPer1000: 11.9, dollarsAtIssue: 17.3e6),
  HeatmapCell(state: 'AZ', providersScored: 2390, flagsPer1000: 12.6, dollarsAtIssue: 9.8e6),
  HeatmapCell(state: 'NV', providersScored: 980, flagsPer1000: 14.4, dollarsAtIssue: 4.9e6),
  HeatmapCell(state: 'NC', providersScored: 3340, flagsPer1000: 9.8, dollarsAtIssue: 10.6e6),
  HeatmapCell(state: 'MA', providersScored: 3120, flagsPer1000: 7.1, dollarsAtIssue: 7.2e6),
  HeatmapCell(state: 'WA', providersScored: 2470, flagsPer1000: 7.8, dollarsAtIssue: 6.3e6),
  HeatmapCell(state: 'CO', providersScored: 1980, flagsPer1000: 8.2, dollarsAtIssue: 5.3e6),
  HeatmapCell(state: 'MN', providersScored: 2150, flagsPer1000: 5.9, dollarsAtIssue: 4.1e6),
  HeatmapCell(state: 'WI', providersScored: 2080, flagsPer1000: 6.4, dollarsAtIssue: 4.3e6),
  HeatmapCell(state: 'MO', providersScored: 2210, flagsPer1000: 9.1, dollarsAtIssue: 6.5e6),
  HeatmapCell(state: 'IN', providersScored: 2260, flagsPer1000: 8.7, dollarsAtIssue: 6.4e6),
  HeatmapCell(state: 'KY', providersScored: 1620, flagsPer1000: 10.9, dollarsAtIssue: 5.7e6),
  HeatmapCell(state: 'AL', providersScored: 1580, flagsPer1000: 12.1, dollarsAtIssue: 6.2e6),
  HeatmapCell(state: 'MS', providersScored: 940, flagsPer1000: 13.9, dollarsAtIssue: 4.2e6),
  HeatmapCell(state: 'SC', providersScored: 1700, flagsPer1000: 10.1, dollarsAtIssue: 5.6e6),
  HeatmapCell(state: 'VA', providersScored: 2840, flagsPer1000: 8.3, dollarsAtIssue: 7.6e6),
  HeatmapCell(state: 'MD', providersScored: 2320, flagsPer1000: 10.7, dollarsAtIssue: 8.0e6),
  HeatmapCell(state: 'OK', providersScored: 1210, flagsPer1000: 11.3, dollarsAtIssue: 4.4e6),
  HeatmapCell(state: 'AR', providersScored: 1010, flagsPer1000: 10.2, dollarsAtIssue: 3.3e6),
  HeatmapCell(state: 'OR', providersScored: 1480, flagsPer1000: 6.6, dollarsAtIssue: 3.2e6),
  HeatmapCell(state: 'UT', providersScored: 1020, flagsPer1000: 7.4, dollarsAtIssue: 2.4e6),
  HeatmapCell(state: 'NM', providersScored: 720, flagsPer1000: 9.6, dollarsAtIssue: 2.2e6),
  HeatmapCell(state: 'KS', providersScored: 1040, flagsPer1000: 7.9, dollarsAtIssue: 2.6e6),
  HeatmapCell(state: 'NE', providersScored: 710, flagsPer1000: 6.1, dollarsAtIssue: 1.4e6),
  HeatmapCell(state: 'IA', providersScored: 1130, flagsPer1000: 5.4, dollarsAtIssue: 1.9e6),
  HeatmapCell(state: 'WV', providersScored: 760, flagsPer1000: 9.9, dollarsAtIssue: 2.4e6),
  HeatmapCell(state: 'CT', providersScored: 1520, flagsPer1000: 8.8, dollarsAtIssue: 4.3e6),
  HeatmapCell(state: 'ID', providersScored: 560, flagsPer1000: 6.0, dollarsAtIssue: 1.1e6),
  HeatmapCell(state: 'MT', providersScored: 400, flagsPer1000: 5.2, dollarsAtIssue: 0.7e6),
  HeatmapCell(state: 'WY', providersScored: 210, flagsPer1000: 4.8, dollarsAtIssue: 0.3e6),
  HeatmapCell(state: 'ND', providersScored: 300, flagsPer1000: 4.1, dollarsAtIssue: 0.4e6),
  HeatmapCell(state: 'SD', providersScored: 330, flagsPer1000: 4.6, dollarsAtIssue: 0.5e6),
  HeatmapCell(state: 'VT', providersScored: 290, flagsPer1000: 3.9, dollarsAtIssue: 0.4e6),
  HeatmapCell(state: 'NH', providersScored: 560, flagsPer1000: 5.1, dollarsAtIssue: 0.9e6),
  HeatmapCell(state: 'ME', providersScored: 540, flagsPer1000: 4.4, dollarsAtIssue: 0.8e6),
  HeatmapCell(state: 'RI', providersScored: 480, flagsPer1000: 7.0, dollarsAtIssue: 1.1e6),
  HeatmapCell(state: 'DE', providersScored: 390, flagsPer1000: 9.3, dollarsAtIssue: 1.2e6),
  HeatmapCell(state: 'DC', providersScored: 610, flagsPer1000: 12.8, dollarsAtIssue: 2.6e6),
  HeatmapCell(state: 'HI', providersScored: 450, flagsPer1000: 5.6, dollarsAtIssue: 0.8e6),
  HeatmapCell(state: 'AK', providersScored: 240, flagsPer1000: 6.9, dollarsAtIssue: 0.6e6),
];

final List<AccessLogEntry> demoAccessLog = [
  AccessLogEntry(id: 'al_1', at: DateTime(2026, 10, 20, 13, 2), userId: 'u_buy', userEmail: 'counsel@demo.fraudsignal', orgId: 'org_qt1', action: AccessAction.viewedLead, leadId: 'L-2026-0005', detail: 'First view by licensee. Handoff timestamp.'),
  AccessLogEntry(id: 'al_2', at: DateTime(2026, 10, 20, 8, 15), userId: 'u_rev', userEmail: 'reviewer@demo.fraudsignal', orgId: 'org_bd', action: AccessAction.signedOff, leadId: 'L-2026-0005'),
  AccessLogEntry(id: 'al_3', at: DateTime(2026, 10, 20, 8, 20), userId: 'u_rev', userEmail: 'reviewer@demo.fraudsignal', orgId: 'org_bd', action: AccessAction.licensed, leadId: 'L-2026-0005', detail: 'Licensed to org_qt1, one firm per lead.'),
  AccessLogEntry(id: 'al_4', at: DateTime(2026, 10, 21, 9, 12), userId: 'u_rev', userEmail: 'reviewer@demo.fraudsignal', orgId: 'org_bd', action: AccessAction.viewedLead, leadId: 'L-2026-0001'),
  AccessLogEntry(id: 'al_5', at: DateTime(2026, 10, 21, 9, 40), userId: 'u_rev', userEmail: 'reviewer@demo.fraudsignal', orgId: 'org_bd', action: AccessAction.signedOff, leadId: 'L-2026-0001'),
  AccessLogEntry(id: 'al_6', at: DateTime(2026, 10, 18, 10, 20), userId: 'u_ana', userEmail: 'analyst@demo.fraudsignal', orgId: 'org_bd', action: AccessAction.ranScreen, detail: 'S-0007 diligence, 4 NPIs'),
];
