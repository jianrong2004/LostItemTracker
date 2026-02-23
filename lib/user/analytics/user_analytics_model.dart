// User-level analytics for the Lost & Found app.
// All models are immutable and backend-agnostic for easy testing
// and future API replacement.

/// Time range for filtering analytics.
enum AnalyticsTimeRange {
  week,
  month,
  year,
  allTime,
}

extension AnalyticsTimeRangeExtension on AnalyticsTimeRange {
  String get label {
    switch (this) {
      case AnalyticsTimeRange.week:
        return 'Week';
      case AnalyticsTimeRange.month:
        return 'Month';
      case AnalyticsTimeRange.year:
        return 'Year';
      case AnalyticsTimeRange.allTime:
        return 'All Time';
    }
  }
}

/// One bucket of time for time-series (e.g. "Jan 15" or "2024-03").
class TimeBucket {
  const TimeBucket({
    required this.label,
    required this.start,
    required this.end,
  });

  final String label;
  final DateTime start;
  final DateTime end;
}

/// Counts of reports by outcome (for lost: pending/returned; for found: pending/claimed).
class ReportOutcomeCounts {
  const ReportOutcomeCounts({
    this.pending = 0,
    this.resolved = 0,
  });

  final int pending;
  final int resolved;

  int get total => pending + resolved;

  double get resolvedRate => total == 0 ? 0.0 : resolved / total;
}

/// Summary card values shown at the top of the report.
class SummaryCards {
  const SummaryCards({
    required this.lostReports,
    required this.foundReports,
    required this.claimsMade,
    required this.lostReturned,
    required this.foundClaimed,
    this.rewardPointsEarned = 0,
    this.voucherRedeemed = 0,
    this.feedbacks = 0,
    this.activeReports = 0,
  });

  final int lostReports;
  final int foundReports;
  final int claimsMade;
  final int lostReturned;
  final int foundClaimed;
  final int rewardPointsEarned;
  final int voucherRedeemed;
  final int feedbacks;
  /// Reports not yet returned/claimed (pending).
  final int activeReports;

  int get totalReports => lostReports + foundReports;

  double get successRate {
    final resolved = lostReturned + foundClaimed;
    final total = lostReports + foundReports;
    return total == 0 ? 0.0 : resolved / total;
  }
}

/// Category name to count (for pie charts).
class CategoryCounts {
  const CategoryCounts(this.counts);
  final Map<String, int> counts;
  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// One point for points accumulation line chart (cumulative points at a time).
class PointsDataPoint {
  const PointsDataPoint({required this.bucket, required this.cumulativePoints});
  final TimeBucket bucket;
  final int cumulativePoints;
}

/// Lat/lng for map markers.
class LocationPoint {
  const LocationPoint({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

/// One data point for activity over time (e.g. reports per day/month).
class ActivityDataPoint {
  const ActivityDataPoint({
    required this.bucket,
    required this.lostCount,
    required this.foundCount,
  });

  final TimeBucket bucket;
  final int lostCount;
  final int foundCount;

  int get total => lostCount + foundCount;
}

/// Claim outcome counts (for pie or bar).
class ClaimOutcomeCounts {
  const ClaimOutcomeCounts({
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
  });

  final int pending;
  final int approved;
  final int rejected;

  int get total => pending + approved + rejected;
}

/// Full analytics report for the current user and selected time range.
class UserAnalyticsReport {
  const UserAnalyticsReport({
    required this.timeRange,
    required this.periodStart,
    required this.periodEnd,
    required this.summary,
    required this.activityOverTime,
    required this.lostOutcomes,
    required this.foundOutcomes,
    required this.claimOutcomes,
    required this.categoryLost,
    required this.categoryFound,
    required this.pointsOverTime,
    required this.lostLocations,
    required this.foundLocations,
  });

  final AnalyticsTimeRange timeRange;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final SummaryCards summary;
  final List<ActivityDataPoint> activityOverTime;
  final ReportOutcomeCounts lostOutcomes;
  final ReportOutcomeCounts foundOutcomes;
  final ClaimOutcomeCounts claimOutcomes;
  final CategoryCounts categoryLost;
  final CategoryCounts categoryFound;
  final List<PointsDataPoint> pointsOverTime;
  final List<LocationPoint> lostLocations;
  final List<LocationPoint> foundLocations;
}
