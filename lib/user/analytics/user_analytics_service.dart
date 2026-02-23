import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_analytics_model.dart';

/// Fetches and aggregates the current user's data for the analytics report.
///
/// Queries: lost_item_reports, found_item_reports, lost_item_claims.
/// Time filtering is applied in memory after fetching (to avoid composite index requirements).
class UserAnalyticsService {
  UserAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Builds a full report for [userId] and [timeRange].
  Future<UserAnalyticsReport> getReport({
    required String userId,
    required AnalyticsTimeRange timeRange,
  }) async {
    final now = DateTime.now();
    final DateTime? start = _rangeStart(now, timeRange);
    final DateTime end = now;

    final lostSnap = await _firestore
        .collection('lost_item_reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .get();

    final foundSnap = await _firestore
        .collection('found_item_reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .get();

    final claimsSnap = await _firestore
        .collection('lost_item_claims')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .get();

    final lostDocs = _filterByDate(
      lostSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      start,
      end,
    );
    final foundDocs = _filterByDate(
      foundSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      start,
      end,
    );
    final claimDocs = _filterByDate(
      claimsSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      start,
      end,
    );

    final rewardsSnap = await _firestore
        .collection('user_rewards')
        .doc(userId)
        .get();
    final vouchersSnap = await _firestore
        .collection('user_vouchers')
        .where('userId', isEqualTo: userId)
        .get();
    final feedbackSnap = await _firestore
        .collection('user_feedback')
        .where('userId', isEqualTo: userId)
        .get();
    final activitiesSnap = await _firestore
        .collection('user_reward_activities')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .get();
    final activityDocs = _filterByDate(
      activitiesSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      start,
      end,
    );

    final summary = _buildSummary(
      lostDocs,
      foundDocs,
      claimDocs,
      rewardsSnap,
      vouchersSnap,
      feedbackSnap,
    );
    final rangeStart = start ?? _earliest(lostDocs, foundDocs, claimDocs);
    final activityOverTime = _buildActivityOverTime(
      lostDocs,
      foundDocs,
      rangeStart,
      end,
      timeRange,
    );
    final lostOutcomes = _buildLostOutcomes(lostDocs);
    final foundOutcomes = _buildFoundOutcomes(foundDocs);
    final claimOutcomes = _buildClaimOutcomes(claimDocs);
    final categoryLost = _buildCategoryCounts(lostDocs);
    final categoryFound = _buildCategoryCounts(foundDocs);
    final pointsOverTime = _buildPointsOverTime(
      activityDocs,
      rangeStart,
      end,
      timeRange,
    );
    final lostLocations = _buildLocations(lostDocs);
    final foundLocations = _buildLocations(foundDocs);

    return UserAnalyticsReport(
      timeRange: timeRange,
      periodStart: start,
      periodEnd: end,
      summary: summary,
      activityOverTime: activityOverTime,
      lostOutcomes: lostOutcomes,
      foundOutcomes: foundOutcomes,
      claimOutcomes: claimOutcomes,
      categoryLost: categoryLost,
      categoryFound: categoryFound,
      pointsOverTime: pointsOverTime,
      lostLocations: lostLocations,
      foundLocations: foundLocations,
    );
  }

  DateTime? _rangeStart(DateTime now, AnalyticsTimeRange range) {
    switch (range) {
      case AnalyticsTimeRange.week:
        return now.subtract(const Duration(days: 7));
      case AnalyticsTimeRange.month:
        return now.subtract(const Duration(days: 30));
      case AnalyticsTimeRange.year:
        return now.subtract(const Duration(days: 365));
      case AnalyticsTimeRange.allTime:
        return null;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterByDate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime? start,
    DateTime end,
  ) {
    if (start == null) return docs;
    return docs.where((d) {
      final ts = d.data()['createdAt'];
      if (ts == null) return false;
      final dt = ts is Timestamp ? ts.toDate() : null;
      if (dt == null) return false;
      return !dt.isBefore(start) && !dt.isAfter(end);
    }).toList();
  }

  DateTime _earliest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> lost,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> found,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> claims,
  ) {
    DateTime? e;
    for (final d in [...lost, ...found, ...claims]) {
      final ts = d.data()['createdAt'];
      if (ts == null) continue;
      final dt = ts is Timestamp ? ts.toDate() : null;
      if (dt != null && (e == null || dt.isBefore(e))) e = dt;
    }
    return e ?? DateTime.now().subtract(const Duration(days: 365));
  }

  SummaryCards _buildSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> lostDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> foundDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> claimDocs,
    DocumentSnapshot rewardsSnap,
    QuerySnapshot vouchersSnap,
    QuerySnapshot feedbackSnap,
  ) {
    int lostReturned = 0;
    int lostPending = 0;
    for (final d in lostDocs) {
      if ((d.data()['itemReturnStatus'] as String? ?? '') == 'returned') {
        lostReturned++;
      } else {
        lostPending++;
      }
    }
    int foundClaimed = 0;
    int foundPending = 0;
    for (final d in foundDocs) {
      if ((d.data()['itemReturnStatus'] as String? ?? '') == 'claimed') {
        foundClaimed++;
      } else {
        foundPending++;
      }
    }
    int rewardPoints = 0;
    if (rewardsSnap.exists) {
      final data = rewardsSnap.data() as Map<String, dynamic>? ?? {};
      rewardPoints = (data['lifetimePoints'] as num?)?.toInt() ??
          (data['totalPoints'] as num?)?.toInt() ?? 0;
    }
    return SummaryCards(
      lostReports: lostDocs.length,
      foundReports: foundDocs.length,
      claimsMade: claimDocs.length,
      lostReturned: lostReturned,
      foundClaimed: foundClaimed,
      rewardPointsEarned: rewardPoints,
      voucherRedeemed: vouchersSnap.docs.length,
      feedbacks: feedbackSnap.docs.length,
      activeReports: lostPending + foundPending,
    );
  }

  CategoryCounts _buildCategoryCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = <String, int>{};
    for (final d in docs) {
      final cat = d.data()['category'] as String? ?? 'Uncategorized';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return CategoryCounts(counts);
  }

  List<PointsDataPoint> _buildPointsOverTime(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activityDocs,
    DateTime rangeStart,
    DateTime rangeEnd,
    AnalyticsTimeRange timeRange,
  ) {
    final buckets = _createBuckets(rangeStart, rangeEnd, timeRange);
    final points = <PointsDataPoint>[];
    for (final b in buckets) {
      int cumulative = 0;
      for (final d in activityDocs) {
        final ts = d.data()['createdAt'];
        if (ts == null) continue;
        final dt = ts is Timestamp ? ts.toDate() : null;
        if (dt != null && !dt.isAfter(b.end)) {
          cumulative += (d.data()['pointsDelta'] as num?)?.toInt() ?? 0;
        }
      }
      points.add(PointsDataPoint(bucket: b, cumulativePoints: cumulative));
    }
    return points;
  }

  List<LocationPoint> _buildLocations(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list = <LocationPoint>[];
    for (final d in docs) {
      final data = d.data();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        list.add(LocationPoint(latitude: lat, longitude: lng));
      }
    }
    return list;
  }

  ReportOutcomeCounts _buildLostOutcomes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int pending = 0, resolved = 0;
    for (final d in docs) {
      final s = d.data()['itemReturnStatus'] as String? ?? 'pending';
      if (s == 'returned') {
        resolved++;
      } else {
        pending++;
      }
    }
    return ReportOutcomeCounts(pending: pending, resolved: resolved);
  }

  ReportOutcomeCounts _buildFoundOutcomes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int pending = 0, resolved = 0;
    for (final d in docs) {
      final s = d.data()['itemReturnStatus'] as String? ?? 'pending';
      if (s == 'claimed') {
        resolved++;
      } else {
        pending++;
      }
    }
    return ReportOutcomeCounts(pending: pending, resolved: resolved);
  }

  ClaimOutcomeCounts _buildClaimOutcomes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int pending = 0, approved = 0, rejected = 0;
    for (final d in docs) {
      final s = d.data()['claimStatus'] as String? ?? 'pending';
      switch (s.toLowerCase()) {
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
        default:
          pending++;
      }
    }
    return ClaimOutcomeCounts(
      pending: pending,
      approved: approved,
      rejected: rejected,
    );
  }

  List<ActivityDataPoint> _buildActivityOverTime(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> lostDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> foundDocs,
    DateTime rangeStart,
    DateTime rangeEnd,
    AnalyticsTimeRange timeRange,
  ) {
    final buckets = _createBuckets(rangeStart, rangeEnd, timeRange);
    final points = <ActivityDataPoint>[];

    for (final b in buckets) {
      int lost = 0, found = 0;
      for (final d in lostDocs) {
        final ts = d.data()['createdAt'];
        if (ts == null) continue;
        final dt = ts is Timestamp ? ts.toDate() : null;
        if (dt != null && !dt.isBefore(b.start) && dt.isBefore(b.end)) lost++;
      }
      for (final d in foundDocs) {
        final ts = d.data()['createdAt'];
        if (ts == null) continue;
        final dt = ts is Timestamp ? ts.toDate() : null;
        if (dt != null && !dt.isBefore(b.start) && dt.isBefore(b.end)) found++;
      }
      points.add(ActivityDataPoint(
        bucket: b,
        lostCount: lost,
        foundCount: found,
      ));
    }
    return points;
  }

  List<TimeBucket> _createBuckets(
    DateTime start,
    DateTime end,
    AnalyticsTimeRange timeRange,
  ) {
    final buckets = <TimeBucket>[];
    // For allTime, show at most last 12 months to keep chart readable.
    final effectiveEnd = end;
    DateTime effectiveStart = start;
    if (timeRange == AnalyticsTimeRange.allTime) {
      int m = end.month - 11;
      int y = end.year;
      if (m <= 0) {
        m += 12;
        y--;
      }
      effectiveStart = DateTime(y, m, 1);
    }

    if (timeRange == AnalyticsTimeRange.week || timeRange == AnalyticsTimeRange.month) {
      var d = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
      while (d.isBefore(effectiveEnd) || d.isAtSameMomentAs(effectiveEnd)) {
        final next = d.add(const Duration(days: 1));
        buckets.add(TimeBucket(
          label: _dayLabel(d),
          start: d,
          end: next,
        ));
        d = next;
      }
      if (buckets.isEmpty) {
        buckets.add(TimeBucket(
          label: _dayLabel(effectiveStart),
          start: effectiveStart,
          end: effectiveEnd,
        ));
      }
    } else {
      var d = DateTime(effectiveStart.year, effectiveStart.month, 1);
      while (d.isBefore(effectiveEnd) || d.isAtSameMomentAs(effectiveEnd)) {
        final next = DateTime(d.year, d.month + 1, 1);
        buckets.add(TimeBucket(
          label: _monthLabel(d),
          start: d,
          end: next.isAfter(effectiveEnd) ? effectiveEnd : next,
        ));
        d = next;
      }
      if (buckets.isEmpty) {
        buckets.add(TimeBucket(
          label: _monthLabel(effectiveStart),
          start: effectiveStart,
          end: effectiveEnd,
        ));
      }
    }
    return buckets;
  }

  String _dayLabel(DateTime d) =>
      '${d.month}/${d.day}';

  String _monthLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
