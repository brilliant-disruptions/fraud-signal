/// Client-side implementation of the Tier 1 (hard) rules and the lead gate.
///
/// The production engine runs server-side on the full CMS, OIG and SBA pulls.
/// This Dart version exists so a reviewer can re-check any evidence card from
/// its raw values on the device, and so the app can give instant feedback on a
/// diligence or self-audit request before the server run completes. It must
/// agree with the server on every test case; see `test/rules_engine_test.dart`.
///
/// Thresholds always move in the provider's favor: minimum code times, not
/// typical times; statutory PPP ceilings, not estimates.
library;

import 'models.dart';

const String rulesetVersion = '2026.10.0';

/// A time-based billing code with its *minimum* documented duration.
class TimedCodeLine {
  const TimedCodeLine({required this.code, required this.services, required this.minMinutes});
  final String code;
  final int services;
  final int minMinutes;
}

/// Minimum minutes for the time-based codes the engine scores.
/// Minimums, never typical durations, so the check is conservative.
const Map<String, int> minimumMinutesByCode = {
  '90832': 16, // psychotherapy, 30 min (16-37)
  '90834': 38, // psychotherapy, 45 min (38-52)
  '90837': 53, // psychotherapy, 60 min (53+)
  '90853': 45, // group psychotherapy
  '97110': 8, // therapeutic exercise, each 15 min (8 min rule)
  '97140': 8, // manual therapy, each 15 min
  '97530': 8, // therapeutic activities, each 15 min
  '99214': 30, // established patient visit, moderate (time alternative)
  '99215': 40, // established patient visit, high (time alternative)
  '99205': 60, // new patient visit, high
  '99233': 35, // subsequent hospital care, high
  '99223': 70, // initial hospital care, high
  '96372': 0, // injection, not time based
  '99213': 20,
};

class ImpossibleHoursResult {
  const ImpossibleHoursResult({
    required this.totalHours,
    required this.thresholdHours,
    required this.flagged,
  });
  final double totalHours;
  final double thresholdHours;
  final bool flagged;
}

class PppLoanLine {
  const PppLoanLine({
    required this.loanNumber,
    required this.borrowerKey,
    required this.approvedAmount,
    required this.jobsReported,
    required this.draw,
    this.eidlRefinanceAmount = 0,
    this.naicsCode,
  });

  final String loanNumber;

  /// Normalized business identity (name + address, upper-cased, trimmed).
  final String borrowerKey;
  final double approvedAmount;
  final int jobsReported;

  /// 1 for first draw, 2 for second draw.
  final int draw;
  final double eidlRefinanceAmount;
  final String? naicsCode;

  /// NAICS 72 is accommodation and food services.
  bool get isAccommodationOrFood => naicsCode != null && naicsCode!.startsWith('72');
}

class LoanPerJobResult {
  const LoanPerJobResult({
    required this.loanPerJob,
    required this.ceiling,
    required this.flagged,
    required this.skipped,
    this.skipReason,
  });
  final double loanPerJob;
  final double ceiling;
  final bool flagged;

  /// Data-quality screen: rows with missing or zero jobs are skipped, not flagged.
  final bool skipped;
  final String? skipReason;
}

class LeadGateResult {
  const LeadGateResult({
    required this.isLead,
    required this.tier1Count,
    required this.tier2Count,
    required this.dollarsAtIssue,
    required this.materialityFloor,
    required this.reason,
  });
  final bool isLead;
  final int tier1Count;
  final int tier2Count;
  final double dollarsAtIssue;
  final double materialityFloor;
  final String reason;
}

class RulesEngine {
  const RulesEngine();

  /// Statutory PPP loan ceiling per reported job.
  /// 2.5 months of payroll with pay capped at $100K a year is $20,833.
  /// Restaurants and hotels (NAICS 72) on second draw got 3.5 months: $29,167.
  static const double firstDrawCeilingPerJob = 20833;
  static const double naics72SecondDrawCeilingPerJob = 29167;

  /// Second-draw loans required 300 or fewer employees.
  static const int secondDrawMaxJobs = 300;

  /// 12 hours a day, 250 days a year.
  static const double impossibleHoursThreshold = 12 * 250;

  /// Tier 1: time-based codes adding up to more than 12 hours a day,
  /// 250 days a year, using each code's *minimum* time.
  ImpossibleHoursResult impossibleHours(
    List<TimedCodeLine> lines, {
    double thresholdHours = impossibleHoursThreshold,
  }) {
    var minutes = 0.0;
    for (final line in lines) {
      minutes += line.services * line.minMinutes;
    }
    final hours = minutes / 60;
    return ImpossibleHoursResult(
      totalHours: hours,
      thresholdHours: thresholdHours,
      flagged: hours > thresholdHours,
    );
  }

  /// Tier 1: NPI on the OIG exclusion list before the service year, still paid.
  bool excludedProviderStillPaid({
    required DateTime exclusionDate,
    required int serviceYear,
    required double amountPaid,
    DateTime? reinstatementDate,
  }) {
    if (amountPaid <= 0) return false;
    final serviceYearStart = DateTime(serviceYear);
    if (!exclusionDate.isBefore(serviceYearStart)) return false;
    if (reinstatementDate != null && reinstatementDate.isBefore(serviceYearStart)) {
      return false;
    }
    return true;
  }

  /// Tier 1: loan per reported job above the statutory ceiling.
  /// EIDL refinance is netted out first. [multiplier] of 2 reproduces the
  /// conservative scan in the plan ("above 2x the formula ceiling").
  LoanPerJobResult loanPerJobAboveCeiling(PppLoanLine loan, {double multiplier = 1}) {
    final ceiling = _ceilingFor(loan) * multiplier;
    if (loan.jobsReported <= 0) {
      return LoanPerJobResult(
        loanPerJob: 0,
        ceiling: ceiling,
        flagged: false,
        skipped: true,
        skipReason: 'Jobs reported is missing or zero. Excluded, not flagged.',
      );
    }
    final net = loan.approvedAmount - loan.eidlRefinanceAmount;
    if (net <= 0) {
      return LoanPerJobResult(
        loanPerJob: 0,
        ceiling: ceiling,
        flagged: false,
        skipped: true,
        skipReason: 'Net of EIDL refinance is zero or negative. Excluded.',
      );
    }
    final perJob = net / loan.jobsReported;
    return LoanPerJobResult(
      loanPerJob: perJob,
      ceiling: ceiling,
      flagged: perJob > ceiling,
      skipped: false,
    );
  }

  double _ceilingFor(PppLoanLine loan) {
    if (loan.draw == 2 && loan.isAccommodationOrFood) {
      return naics72SecondDrawCeilingPerJob;
    }
    return firstDrawCeilingPerJob;
  }

  /// Tier 1: second-draw loan reporting more than 300 jobs.
  bool secondDrawOverJobCap(PppLoanLine loan) {
    return loan.draw == 2 && loan.jobsReported > secondDrawMaxJobs;
  }

  /// Tier 1: two first-draw loans to the same business.
  /// Returns borrower keys with more than one first-draw loan.
  Map<String, List<PppLoanLine>> duplicateFirstDraws(Iterable<PppLoanLine> loans) {
    final groups = <String, List<PppLoanLine>>{};
    for (final loan in loans) {
      if (loan.draw != 1) continue;
      final key = normalizeBorrowerKey(loan.borrowerKey);
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => []).add(loan);
    }
    groups.removeWhere((_, list) => list.length < 2);
    return groups;
  }

  /// Upper-case, collapse whitespace, strip punctuation. Names are used only
  /// to match a business to itself, never to score it.
  static String normalizeBorrowerKey(String raw) {
    return raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Tier 1: children or meals billed above licensed capacity.
  bool billedAboveLicensedCapacity({required int billedUnits, required int licensedCapacity}) {
    if (licensedCapacity <= 0) return false; // no license on file: cannot judge
    return billedUnits > licensedCapacity;
  }

  /// Tier 2: subject value at or above the peer 99th percentile.
  /// Cells under the CMS suppression floor are skipped.
  bool peerOutlier({
    required double subjectValue,
    required PeerDistribution peers,
    required int subjectPatientCount,
    int suppressionFloor = 11,
  }) {
    if (subjectPatientCount < suppressionFloor) return false;
    return subjectValue >= peers.p99;
  }

  /// A record becomes a lead only with at least one Tier 1 hit, or at least
  /// two independent Tier 2 signals, plus dollars at issue above the
  /// program's materiality floor. Everything below stays on the watch list.
  LeadGateResult leadGate({
    required Program program,
    required int tier1Count,
    required int tier2Count,
    required double dollarsAtIssue,
  }) {
    final floor = program.materialityFloor;
    final signalOk = tier1Count >= 1 || tier2Count >= 2;
    final dollarsOk = dollarsAtIssue >= floor;
    String reason;
    if (!signalOk && !dollarsOk) {
      reason = 'Needs a Tier 1 hit or two Tier 2 signals, and dollars above the floor.';
    } else if (!signalOk) {
      reason = 'Needs at least one Tier 1 hit or two independent Tier 2 signals.';
    } else if (!dollarsOk) {
      reason = 'Dollars at issue are below the materiality floor.';
    } else if (tier1Count >= 1) {
      reason = 'Tier 1 hit with dollars above the floor.';
    } else {
      reason = 'Two or more independent Tier 2 signals with dollars above the floor.';
    }
    return LeadGateResult(
      isLead: signalOk && dollarsOk,
      tier1Count: tier1Count,
      tier2Count: tier2Count,
      dollarsAtIssue: dollarsAtIssue,
      materialityFloor: floor,
      reason: reason,
    );
  }
}

/// Two-sided exact-ish lift over a base rate, used only to *display* a
/// rule's measured precision beside its score. Never used to decide a lead.
double liftOverBase({required int flagged, required int hits, required double baseRate}) {
  if (flagged == 0 || baseRate <= 0) return 0;
  return (hits / flagged) / baseRate;
}
