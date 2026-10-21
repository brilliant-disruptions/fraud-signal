import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_signal/domain/models.dart';
import 'package:fraud_signal/domain/rules_engine.dart';

void main() {
  const engine = RulesEngine();

  group('Impossible hours (Tier 1)', () {
    test('uses minimum code time and flags above 3,000 hours', () {
      // 3,500 sessions of 90837 at the 53-minute minimum = 3,091.7 hours.
      final result = engine.impossibleHours(const [
        TimedCodeLine(code: '90837', services: 3500, minMinutes: 53),
      ]);
      expect(result.totalHours, closeTo(3091.67, 0.01));
      expect(result.flagged, isTrue);
    });

    test('does not flag a busy but possible year', () {
      // 2,500 sessions of 90834 at 38 minutes = 1,583 hours.
      final result = engine.impossibleHours(const [
        TimedCodeLine(code: '90834', services: 2500, minMinutes: 38),
      ]);
      expect(result.flagged, isFalse);
    });

    test('sums across codes and honors a sensitivity threshold', () {
      final lines = const [
        TimedCodeLine(code: '90837', services: 1500, minMinutes: 53), // 1325 h
        TimedCodeLine(code: '90834', services: 2000, minMinutes: 38), // 1266.7 h
      ];
      expect(engine.impossibleHours(lines).flagged, isFalse); // 2591.7 < 3000
      expect(engine.impossibleHours(lines, thresholdHours: 2500).flagged, isTrue);
    });
  });

  group('Excluded provider still paid (Tier 1)', () {
    test('flags payment after an exclusion that predates the service year', () {
      expect(
        engine.excludedProviderStillPaid(
          exclusionDate: DateTime(2016, 5, 19),
          serviceYear: 2019,
          amountPaid: 392000,
        ),
        isTrue,
      );
    });

    test('ignores exclusions dated inside or after the service year', () {
      expect(
        engine.excludedProviderStillPaid(
          exclusionDate: DateTime(2019, 3, 1),
          serviceYear: 2019,
          amountPaid: 10000,
        ),
        isFalse,
      );
    });

    test('ignores providers reinstated before the service year', () {
      expect(
        engine.excludedProviderStillPaid(
          exclusionDate: DateTime(2012, 1, 1),
          reinstatementDate: DateTime(2017, 1, 1),
          serviceYear: 2019,
          amountPaid: 10000,
        ),
        isFalse,
      );
    });
  });

  group('PPP loan per job (Tier 1)', () {
    test('flags above the \$20,833 first-draw ceiling after netting EIDL', () {
      final result = engine.loanPerJobAboveCeiling(const PppLoanLine(
        loanNumber: 'L1',
        borrowerKey: 'Acme LLC',
        approvedAmount: 1250000,
        eidlRefinanceAmount: 10000,
        jobsReported: 20,
        draw: 1,
      ));
      expect(result.loanPerJob, 62000);
      expect(result.flagged, isTrue);
    });

    test('uses the \$29,167 ceiling for NAICS 72 second draws', () {
      final result = engine.loanPerJobAboveCeiling(const PppLoanLine(
        loanNumber: 'L2',
        borrowerKey: 'Diner Inc',
        approvedAmount: 290000,
        jobsReported: 10,
        draw: 2,
        naicsCode: '722511',
      ));
      expect(result.ceiling, 29167);
      expect(result.flagged, isFalse); // 29,000 per job is under the ceiling
    });

    test('skips rows with zero jobs instead of flagging them', () {
      final result = engine.loanPerJobAboveCeiling(const PppLoanLine(
        loanNumber: 'L3',
        borrowerKey: 'Blank Co',
        approvedAmount: 500000,
        jobsReported: 0,
        draw: 1,
      ));
      expect(result.skipped, isTrue);
      expect(result.flagged, isFalse);
    });
  });

  group('PPP structural rules (Tier 1)', () {
    test('second draw over 300 jobs is flagged', () {
      const loan = PppLoanLine(
        loanNumber: 'L4', borrowerKey: 'Big Co', approvedAmount: 2000000, jobsReported: 500, draw: 2);
      expect(engine.secondDrawOverJobCap(loan), isTrue);
      const ok = PppLoanLine(
        loanNumber: 'L5', borrowerKey: 'Mid Co', approvedAmount: 2000000, jobsReported: 300, draw: 2);
      expect(engine.secondDrawOverJobCap(ok), isFalse);
    });

    test('two first draws to one business group together, second draws do not', () {
      final groups = engine.duplicateFirstDraws(const [
        PppLoanLine(loanNumber: 'A', borrowerKey: 'Riverside Dental, LLC', approvedAmount: 600000, jobsReported: 30, draw: 1),
        PppLoanLine(loanNumber: 'B', borrowerKey: 'riverside dental llc', approvedAmount: 650000, jobsReported: 30, draw: 1),
        PppLoanLine(loanNumber: 'C', borrowerKey: 'Riverside Dental LLC', approvedAmount: 600000, jobsReported: 30, draw: 2),
        PppLoanLine(loanNumber: 'D', borrowerKey: 'Other Co', approvedAmount: 600000, jobsReported: 30, draw: 1),
      ]);
      expect(groups.length, 1);
      expect(groups.values.first.map((l) => l.loanNumber), ['A', 'B']);
    });
  });

  group('Lead gate', () {
    test('one Tier 1 hit above the Medicare floor is a lead', () {
      final gate = engine.leadGate(
          program: Program.medicare, tier1Count: 1, tier2Count: 0, dollarsAtIssue: 600000);
      expect(gate.isLead, isTrue);
    });

    test('a single Tier 2 signal never becomes a lead', () {
      final gate = engine.leadGate(
          program: Program.medicare, tier1Count: 0, tier2Count: 1, dollarsAtIssue: 5000000);
      expect(gate.isLead, isFalse);
    });

    test('two Tier 2 signals below the PPP floor stay on the watch list', () {
      final gate = engine.leadGate(
          program: Program.ppp, tier1Count: 0, tier2Count: 2, dollarsAtIssue: 900000);
      expect(gate.isLead, isFalse);
      expect(gate.materialityFloor, 1000000);
    });

    test('peer outlier respects the CMS suppression floor', () {
      const peers = PeerDistribution(
          peerGroup: 'Psychiatry, TN', peerCount: 400, p50: 10, p75: 14, p90: 20, p95: 26, p99: 40, unit: 'visits/patient');
      expect(engine.peerOutlier(subjectValue: 45, peers: peers, subjectPatientCount: 10), isFalse);
      expect(engine.peerOutlier(subjectValue: 45, peers: peers, subjectPatientCount: 11), isTrue);
    });
  });

  group('Capacity rule (Tier 1)', () {
    test('billing above licensed capacity is flagged, missing license is not', () {
      expect(engine.billedAboveLicensedCapacity(billedUnits: 90, licensedCapacity: 60), isTrue);
      expect(engine.billedAboveLicensedCapacity(billedUnits: 90, licensedCapacity: 0), isFalse);
    });
  });
}
