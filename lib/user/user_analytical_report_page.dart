import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'analytics/user_analytics_model.dart';
import 'analytics/user_analytics_service.dart';

/// User-level analytics report. Only analyzes the current user's data.
/// Time range: Week, Month, Year, All Time. Includes summary cards, charts, download and share.
class UserAnalyticalReportPage extends StatefulWidget {
  const UserAnalyticalReportPage({super.key});

  @override
  State<UserAnalyticalReportPage> createState() =>
      _UserAnalyticalReportPageState();
}

class _UserAnalyticalReportPageState extends State<UserAnalyticalReportPage> {
  final UserAnalyticsService _analyticsService = UserAnalyticsService();
  final User? _user = FirebaseAuth.instance.currentUser;
  final ScreenshotController _screenshotController = ScreenshotController();

  AnalyticsTimeRange _timeRange = AnalyticsTimeRange.month;
  UserAnalyticsReport? _report;
  bool _isLoading = true;
  String? _error;
  bool _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final uid = _user?.uid;
    if (uid == null) {
      setState(() {
        _error = 'Please sign in to view analytics';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await _analyticsService.getReport(
        userId: uid,
        timeRange: _timeRange,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onTimeRangeChanged(AnalyticsTimeRange range) {
    if (_timeRange == range) return;
    setState(() => _timeRange = range);
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('Please log in to view your analytics report'),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Screenshot(
            controller: _screenshotController,
            child: Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTimeRangeSelector(),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _buildErrorCard()
                  else if (_report != null) ...[
                      _buildSummaryCards(_report!.summary),
                      const SizedBox(height: 24),
                      _buildActivityChart(_report!.activityOverTime),
                      const SizedBox(height: 24),
                      _buildPointsAccumulationChart(_report!.pointsOverTime),
                      const SizedBox(height: 24),
                      _buildCategoryPieCharts(),
                      const SizedBox(height: 24),
                      _buildLocationMap(),
                      const SizedBox(height: 24),
                      _buildClaimOutcomesSection(),
                      const SizedBox(height: 32),
                      _buildDownloadAndShareButtons(),
                      const SizedBox(height: 24),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Analytics Report'),
      backgroundColor: Colors.indigo.shade700,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: AnalyticsTimeRange.values.map((range) {
            final isSelected = _timeRange == range;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onTimeRangeChanged(range),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    range.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.indigo.shade700
                          : Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(SummaryCards s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        // 4 rows x 2 columns layout
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Lost Reports',
                s.lostReports.toString(),
                Icons.search_off,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Found Reports',
                s.foundReports.toString(),
                Icons.inventory_2,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Claims Made',
                s.claimsMade.toString(),
                Icons.handshake,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Success Rate',
                '${(s.successRate * 100).toStringAsFixed(0)}%',
                Icons.percent,
                Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Points Earned',
                s.rewardPointsEarned.toString(),
                Icons.stars,
                Colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Vouchers Redeemed',
                s.voucherRedeemed.toString(),
                Icons.card_giftcard,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Feedbacks',
                s.feedbacks.toString(),
                Icons.feedback,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Active Reports',
                s.activeReports.toString(),
                Icons.pending_actions,
                Colors.deepOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart(List<ActivityDataPoint> points) {
    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No activity in this period',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    final maxY = points.fold<double>(
      1,
          (m, p) => (p.total > m ? p.total.toDouble() : m),
    );

    final barGroups = points.asMap().entries.map((e) {
      final p = e.value;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: p.lostCount.toDouble(),
            color: Colors.blue.shade400,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            fromY: p.lostCount.toDouble(),
            toY: (p.lostCount + p.foundCount).toDouble(),
            color: Colors.orange.shade400,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        showingTooltipIndicators: [],
      );
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports Over Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(Colors.blue, 'Lost'),
                const SizedBox(width: 16),
                _legendDot(Colors.orange, 'Found'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'X: Time period   ·   Y: Number of reports',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY + 1,
                  minY: 0,
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < points.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Transform.rotate(
                                angle: -0.6,
                                child: Text(
                                  points[i].bucket.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 44,
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsAccumulationChart(List<PointsDataPoint> points) {
    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No points data in this period',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }
    final spots = points.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.cumulativePoints.toDouble())).toList();
    final maxY = points.fold<double>(
      0,
          (m, p) => p.cumulativePoints > m ? p.cumulativePoints.toDouble() : m,
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Points Accumulation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'X: Time period   ·   Y: Cumulative points',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (points.length - 1).clamp(0, double.infinity).toDouble(),
                  minY: 0,
                  maxY: maxY + 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.indigo.shade600,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < points.length) {
                            return Transform.rotate(
                              angle: -0.6,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  points[i].bucket.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) =>
                            Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    getDrawingVerticalLine: (v) =>
                        FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieCharts() {
    if (_report == null) return const SizedBox.shrink();
    final r = _report!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCategoryPieCard(
                'Lost item categories',
                r.categoryLost,
                [Colors.blue, Colors.cyan, Colors.indigo, Colors.teal, Colors.green, Colors.orange],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCategoryPieCard(
                'Found item categories',
                r.categoryFound,
                [Colors.orange, Colors.amber, Colors.deepOrange, Colors.red, Colors.brown, Colors.purple],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryPieCard(
      String title,
      CategoryCounts categoryCounts,
      List<Color> colorPalette,
      ) {
    final total = categoryCounts.total;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'No data',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }
    final entries = categoryCounts.counts.entries.toList();
    final sections = entries.asMap().entries.map((e) {
      final count = e.value.value;
      final pct = total == 0 ? 0.0 : count / total;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '${(pct * 100).toStringAsFixed(0)}%',
        color: colorPalette[e.key % colorPalette.length],
        radius: 36,
      );
    }).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 1,
                  centerSpaceRadius: 20,
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...entries.asMap().entries.map((entry) {
              final e = entry.value;
              final idx = entry.key;
              final pct = total == 0 ? 0.0 : (e.value / total * 100);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorPalette[idx % colorPalette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.key,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${e.value} (${pct.toStringAsFixed(1)}%)',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMap() {
    if (_report == null) return const SizedBox.shrink();
    final lost = _report!.lostLocations;
    final found = _report!.foundLocations;
    if (lost.isEmpty && found.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No location data for reports in this period',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }
    const campusCenter = LatLng(3.2158, 101.7306);
    final allPoints = [
      ...lost.map((p) => LatLng(p.latitude, p.longitude)),
      ...found.map((p) => LatLng(p.latitude, p.longitude)),
    ];
    LatLng mapCenter = campusCenter;
    if (allPoints.isNotEmpty) {
      double sumLat = 0, sumLng = 0;
      for (final p in allPoints) {
        sumLat += p.latitude;
        sumLng += p.longitude;
      }
      mapCenter = LatLng(
        sumLat / allPoints.length,
        sumLng / allPoints.length,
      );
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location Patterns',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _legendDot(Colors.blue, 'Lost item locations'),
                      const SizedBox(width: 16),
                      _legendDot(Colors.orange, 'Found item locations'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 15.0,
                  minZoom: 12,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tarumt.lost_item_tracker',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      ...lost.map((p) => Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 24,
                        height: 24,
                        child: Icon(Icons.location_on, size: 24, color: Colors.blue.shade700),
                      )),
                      ...found.map((p) => Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 24,
                        height: 24,
                        child: Icon(Icons.location_on, size: 24, color: Colors.orange.shade700),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimOutcomesSection() {
    if (_report == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claim outcomes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildClaimOutcomesBar(_report!.claimOutcomes),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildClaimOutcomesBar(ClaimOutcomeCounts c) {
    final total = c.total;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No claims in this period',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _outcomeBar(
                    'Approved',
                    c.approved,
                    total,
                    Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _outcomeBar(
                    'Rejected',
                    c.rejected,
                    total,
                    Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _outcomeBar(
                    'Pending',
                    c.pending,
                    total,
                    Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _outcomeBar(String label, int value, int total, Color color) {
    final pct = total == 0 ? 0.0 : value / total;
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildDownloadAndShareButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: (_report == null || _isSavingImage) ? null : _downloadReportAsImage,
          icon: _isSavingImage
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Icon(Icons.download),
          label: Text(_isSavingImage ? 'Saving...' : 'Download Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _report == null ? null : _shareReport,
          icon: const Icon(Icons.share),
          label: const Text('Share Report'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.indigo.shade700,
            side: BorderSide(color: Colors.indigo.shade700),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  String _reportToText() {
    if (_report == null) return '';
    final r = _report!;
    final df = DateFormat('yyyy-MM-dd');
    final period = r.periodStart != null
        ? '${df.format(r.periodStart!)} to ${df.format(r.periodEnd!)}'
        : 'All time';

    final buffer = StringBuffer();
    buffer.writeln('Lost & Found Analytics Report');
    buffer.writeln('Period: $period (${r.timeRange.label})');
    buffer.writeln('');
    buffer.writeln('--- Summary ---');
    buffer.writeln('Lost reports: ${r.summary.lostReports}');
    buffer.writeln('Found reports: ${r.summary.foundReports}');
    buffer.writeln('Claims made: ${r.summary.claimsMade}');
    buffer.writeln('Success rate: ${(r.summary.successRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('Reward points earned: ${r.summary.rewardPointsEarned}');
    buffer.writeln('Vouchers redeemed: ${r.summary.voucherRedeemed}');
    buffer.writeln('Feedbacks: ${r.summary.feedbacks}');
    buffer.writeln('Active reports: ${r.summary.activeReports}');
    buffer.writeln('');
    buffer.writeln('--- Claim outcomes ---');
    buffer.writeln('Approved: ${r.claimOutcomes.approved}, Rejected: ${r.claimOutcomes.rejected}, Pending: ${r.claimOutcomes.pending}');
    buffer.writeln('');
    buffer.writeln('--- Activity over time ---');
    for (final p in r.activityOverTime) {
      buffer.writeln('${p.bucket.label}: Lost ${p.lostCount}, Found ${p.foundCount}');
    }
    return buffer.toString();
  }

  Future<Uint8List?> _generatePdfBytes() async {
    if (_report == null) return null;
    final r = _report!;
    final df = DateFormat('yyyy-MM-dd');
    final period = r.periodStart != null
        ? '${df.format(r.periodStart!)} to ${df.format(r.periodEnd!)}'
        : 'All time';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Lost & Found Analytics Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Paragraph(text: 'Period: $period (${r.timeRange.label})'),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, child: pw.Text('Summary')),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              _pdfRow('Lost reports', '${r.summary.lostReports}'),
              _pdfRow('Found reports', '${r.summary.foundReports}'),
              _pdfRow('Claims made', '${r.summary.claimsMade}'),
              _pdfRow('Success rate', '${(r.summary.successRate * 100).toStringAsFixed(1)}%'),
              _pdfRow('Reward points earned', '${r.summary.rewardPointsEarned}'),
              _pdfRow('Vouchers redeemed', '${r.summary.voucherRedeemed}'),
              _pdfRow('Feedbacks', '${r.summary.feedbacks}'),
              _pdfRow('Active reports', '${r.summary.activeReports}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, child: pw.Text('Claim outcomes')),
          pw.Paragraph(
            text: 'Approved: ${r.claimOutcomes.approved}, '
                'Rejected: ${r.claimOutcomes.rejected}, '
                'Pending: ${r.claimOutcomes.pending}',
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, child: pw.Text('Activity over time')),
          ...r.activityOverTime.map(
                (p) => pw.Paragraph(
              text: '${p.bucket.label}: Lost ${p.lostCount}, Found ${p.foundCount}',
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.TableRow _pdfRow(String label, String value) => pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(label),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(value),
      ),
    ],
  );

  /// Download report as a long image and save to gallery using Gal
  Future<void> _downloadReportAsImage() async {
    setState(() {
      _isSavingImage = true;
    });

    try {
      // Capture screenshot of entire report
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 2.0, // High quality
      );

      if (imageBytes == null) {
        throw Exception('Failed to capture report screenshot');
      }

      // Check and request permission
      final hasPermission = await Gal.hasAccess();
      if (!hasPermission) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('Gallery access permission denied');
        }
      }

      // Save to gallery using Gal
      await Gal.putImageBytes(imageBytes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Report saved to gallery')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save report: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingImage = false;
        });
      }
    }
  }

  Future<void> _shareReport() async {
    if (_report == null) return;
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share as text'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final text = _reportToText();
                try {
                  await Share.share(
                    text,
                    subject: 'Lost & Found Analytics Report',
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Share failed: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Share as image'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  // Capture screenshot
                  final imageBytes = await _screenshotController.capture(pixelRatio: 2.0);
                  if (imageBytes == null) {
                    throw Exception('Failed to capture screenshot');
                  }

                  // Save to temp directory
                  final tempDir = await getTemporaryDirectory();
                  final file = await File('${tempDir.path}/analytics_report_${DateTime.now().millisecondsSinceEpoch}.png')
                      .create();
                  await file.writeAsBytes(imageBytes);

                  // Share via system share sheet
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    subject: 'Lost & Found Analytics Report',
                  );

                  // Clean up temp file
                  try {
                    await file.delete();
                  } catch (_) {
                    // Ignore cleanup errors
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Share failed: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Print as PDF'),
              onTap: () async {
                Navigator.pop(context);
                final bytes = await _generatePdfBytes();
                if (bytes == null || !mounted) return;
                await Printing.layoutPdf(
                  onLayout: (_) => bytes,
                  name: 'analytics_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}