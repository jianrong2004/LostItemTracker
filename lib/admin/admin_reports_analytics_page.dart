import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'admin_report_export_page.dart';
import 'admin_theme.dart';

class AdminReportsAnalyticsPage extends StatefulWidget {
  const AdminReportsAnalyticsPage({super.key});

  @override
  State<AdminReportsAnalyticsPage> createState() => _AdminReportsAnalyticsPageState();
}

class _AdminReportsAnalyticsPageState extends State<AdminReportsAnalyticsPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _filterCategory;
  String? _filterLocation;
  bool _loading = true;
  int _lostCount = 0;
  int _foundCount = 0;
  int _claimsCount = 0;
  int _resolvedCount = 0;
  List<Map<String, dynamic>> _categoryBreakdown = [];
  List<Map<String, dynamic>> _tableData = [];
  Map<String, String> _deskNames = {};
  List<Map<String, dynamic>> _foundByDeskBreakdown = [];
  List<Map<String, dynamic>> _lostPlaceBreakdown = [];
  List<String> _trendDayKeys = [];
  List<FlSpot> _trendLostSpots = [];
  List<FlSpot> _trendFoundSpots = [];
  List<Map<String, dynamic>> _statusBreakdown = [];

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final start = _startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = (_endDate ?? DateTime.now()).add(const Duration(days: 1));
      final startTs = Timestamp.fromDate(start);
      final endTs = Timestamp.fromDate(end);

      final desksSnap = await FirebaseFirestore.instance.collection('dropOffDesks').get();
      final deskNames = <String, String>{};
      for (final d in desksSnap.docs) {
        final data = d.data();
        final name = (data['name'] as String?)?.trim();
        deskNames[d.id] = (name != null && name.isNotEmpty) ? name : d.id;
      }

      final lostSnap = await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();
      final foundSnap = await FirebaseFirestore.instance
          .collection('found_item_reports')
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();
      final claimsSnap = await FirebaseFirestore.instance
          .collection('lost_item_claims')
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();

      var lostCount = 0;
      var foundCount = 0;
      var claimsCount = claimsSnap.docs.length;
      var resolvedCount = 0;
      final categoryMap = <String, int>{};
      final tableData = <Map<String, dynamic>>[];
      final foundByDesk = <String, int>{};
      final lostByPlace = <String, int>{};
      final dailyLost = <String, int>{};
      final dailyFound = <String, int>{};
      final statusMap = <String, int>{};

      String dayKey(Timestamp? ts) {
        if (ts == null) return '';
        return DateFormat('yyyy-MM-dd').format(ts.toDate());
      }

      void bumpDay(Map<String, int> map, String key) {
        if (key.isEmpty) return;
        map[key] = (map[key] ?? 0) + 1;
      }

      for (var d in lostSnap.docs) {
        final data = d.data();
        if (_filterCategory != null && data['category'] != _filterCategory) continue;
        lostCount++;
        final cat = data['category'] as String? ?? 'Other';
        categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        if (data['reportStatus'] == 'resolved' || data['reportStatus'] == 'matched') resolvedCount++;
        final st = (data['reportStatus'] ?? 'unknown').toString();
        statusMap[st] = (statusMap[st] ?? 0) + 1;

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) bumpDay(dailyLost, dayKey(createdAt));

        final addr = (data['address'] as String?)?.trim();
        final locDesc = (data['locationDescription'] as String?)?.trim();
        String rawPlace;
        if (addr != null && addr.isNotEmpty) {
          rawPlace = addr.split(',').first.trim();
        } else if (locDesc != null && locDesc.isNotEmpty) {
          rawPlace = locDesc;
        } else {
          rawPlace = 'Unknown';
        }
        final shortPlace = rawPlace.length > 28 ? '${rawPlace.substring(0, 27)}…' : rawPlace;
        lostByPlace[shortPlace] = (lostByPlace[shortPlace] ?? 0) + 1;

        tableData.add({
          'type': 'Lost',
          'id': d.id,
          'name': data['itemName'],
          'category': cat,
          'status': data['reportStatus'],
          'createdAt': data['createdAt'],
        });
      }
      for (var d in foundSnap.docs) {
        final data = d.data();
        if (_filterCategory != null && data['category'] != _filterCategory) continue;
        if (_filterLocation != null && data['dropOffDeskId'] != _filterLocation) continue;
        foundCount++;
        final cat = data['category'] as String? ?? 'Other';
        categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        if (data['reportStatus'] == 'resolved' || data['reportStatus'] == 'matched') resolvedCount++;
        final st = (data['reportStatus'] ?? 'unknown').toString();
        statusMap[st] = (statusMap[st] ?? 0) + 1;

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) bumpDay(dailyFound, dayKey(createdAt));

        final deskId = data['dropOffDeskId'] as String?;
        if (deskId != null && deskId.isNotEmpty) {
          foundByDesk[deskId] = (foundByDesk[deskId] ?? 0) + 1;
        }

        tableData.add({
          'type': 'Found',
          'id': d.id,
          'name': data['itemName'],
          'category': cat,
          'status': data['reportStatus'],
          'createdAt': data['createdAt'],
        });
      }
      for (var d in claimsSnap.docs) {
        final data = d.data();
        if (data['claimStatus'] == 'approved') resolvedCount++;
      }

      final breakdown = categoryMap.entries.map((e) => {'category': e.key, 'count': e.value}).toList();
      breakdown.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final deskList = foundByDesk.entries
          .map((e) => {'id': e.key, 'name': deskNames[e.key] ?? e.key, 'count': e.value})
          .toList();
      deskList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final lostPlacesList = lostByPlace.entries.map((e) => {'label': e.key, 'count': e.value}).toList();
      lostPlacesList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final statusList = statusMap.entries.map((e) => {'status': e.key, 'count': e.value}).toList();
      statusList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final endDay = _endDate ?? DateTime.now();
      final startDay = _startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final trendDays = <String>[];
      for (var t = DateTime(startDay.year, startDay.month, startDay.day);
          !t.isAfter(DateTime(endDay.year, endDay.month, endDay.day));
          t = t.add(const Duration(days: 1))) {
        trendDays.add(DateFormat('yyyy-MM-dd').format(t));
      }

      final lostSpots = <FlSpot>[];
      final foundSpots = <FlSpot>[];
      for (var i = 0; i < trendDays.length; i++) {
        final k = trendDays[i];
        lostSpots.add(FlSpot(i.toDouble(), (dailyLost[k] ?? 0).toDouble()));
        foundSpots.add(FlSpot(i.toDouble(), (dailyFound[k] ?? 0).toDouble()));
      }

      if (mounted) {
        setState(() {
          _deskNames = deskNames;
          _lostCount = lostCount;
          _foundCount = foundCount;
          _claimsCount = claimsCount;
          _resolvedCount = resolvedCount;
          _categoryBreakdown = breakdown;
          _tableData = tableData;
          _foundByDeskBreakdown = deskList;
          _lostPlaceBreakdown = lostPlacesList;
          _trendDayKeys = trendDays;
          _trendLostSpots = lostSpots;
          _trendFoundSpots = foundSpots;
          _statusBreakdown = statusList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openExport() {
    if (_loading) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminReportExportPage(
          startDate: _startDate,
          endDate: _endDate,
          lostCount: _lostCount,
          foundCount: _foundCount,
          claimsCount: _claimsCount,
          resolvedCount: _resolvedCount,
          categoryBreakdown: _categoryBreakdown,
          tableData: _tableData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: AdminTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _loading ? 'Loading data...' : 'Export report',
            icon: Icon(
              Icons.download,
              color: _loading ? Colors.white.withValues(alpha: 0.35) : Colors.white,
            ),
            onPressed: _loading ? null : _openExport,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilters(),
                    const SizedBox(height: 20),
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    Text('Category', style: AdminTheme.sectionTitle()),
                    const SizedBox(height: 8),
                    SizedBox(height: 220, child: _buildCategoryChart()),
                    const SizedBox(height: 20),
                    Text('Lost vs found', style: AdminTheme.sectionTitle()),
                    const SizedBox(height: 8),
                    _buildLostFoundPie(),
                    const SizedBox(height: 20),
                    Text('Daily trend', style: AdminTheme.sectionTitle()),
                    const SizedBox(height: 8),
                    SizedBox(height: 240, child: _buildTrendLineChart()),
                    const SizedBox(height: 8),
                    _trendLegend(),
                    const SizedBox(height: 20),
                    _horizontalBarCard(
                      'Found items by drop-off desk',
                      _foundByDeskBreakdown,
                      labelKey: 'name',
                    ),
                    const SizedBox(height: 20),
                    _horizontalBarCard(
                      'Top lost-item locations',
                      _lostPlaceBreakdown,
                      labelKey: 'label',
                    ),
                    const SizedBox(height: 20),
                    _horizontalBarCard(
                      'Report status mix',
                      _statusBreakdown,
                      labelKey: 'status',
                    ),
                    const SizedBox(height: 20),
                    Text('Detailed data', style: AdminTheme.sectionTitle()),
                    const SizedBox(height: 8),
                    _buildDataTable(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _startDate = d);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat.yMd().format(_startDate ?? DateTime.now())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _endDate = d);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat.yMd().format(_endDate ?? DateTime.now())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final useColumn = c.maxWidth < 520;
                final categoryField = DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: _filterCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._categoryBreakdown.map(
                      (e) => DropdownMenuItem(
                        value: e['category'] as String,
                        child: Text(
                          e['category'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  selectedItemBuilder: (context) => [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('All', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    ..._categoryBreakdown.map(
                      (e) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          e['category'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filterCategory = v),
                );
                final locationField = DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: _filterLocation,
                  decoration: const InputDecoration(labelText: 'Location'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._deskNames.entries.map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  selectedItemBuilder: (context) => [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('All', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    ..._deskNames.entries.map(
                      (e) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          e.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filterLocation = v),
                );
                if (useColumn) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      categoryField,
                      const SizedBox(height: 12),
                      locationField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: categoryField),
                    const SizedBox(width: 8),
                    Expanded(child: locationField),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _summaryCard('Lost', _lostCount, AdminTheme.statLost)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Found', _foundCount, AdminTheme.statFound)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Claims', _claimsCount, AdminTheme.statClaims)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Resolved', _resolvedCount, AdminTheme.accent)),
      ],
    );
  }

  Widget _summaryCard(String label, int value, Color accent) {
    final tint = Color.lerp(AdminTheme.cardSurface, accent, 0.14)!;
    return Card(
      color: tint,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTheme.radiusM),
        side: const BorderSide(color: AdminTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    if (_categoryBreakdown.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final spots = _categoryBreakdown
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble()))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (spots.map((s) => s.y).reduce(math.max) * 1.2).clamp(1, double.infinity),
            barTouchData: BarTouchData(
              enabled: false,
              handleBuiltInTouches: false,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tooltipMargin: 8,
                getTooltipColor: (_) => AdminTheme.chartTooltipBg,
                tooltipBorder: const BorderSide(color: AdminTheme.border, width: 1),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    rod.toY.round().toString(),
                    const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i >= 0 && i < _categoryBreakdown.length) {
                      final cat = _categoryBreakdown[i]['category'] as String? ?? '';
                      final label = cat.length > 8 ? '${cat.substring(0, 7)}…' : cat;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 10, color: AdminTheme.textPrimary),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AdminTheme.chartGridLine.withValues(alpha: 0.85),
                strokeWidth: 1,
                dashArray: [6, 6],
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: spots.asMap().entries.map((e) {
              final barColor = AdminTheme.chartBarPalette[e.key % AdminTheme.chartBarPalette.length];
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.y,
                    color: barColor,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                showingTooltipIndicators: [0],
              );
            }).toList(),
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }

  Widget _buildLostFoundPie() {
    final total = _lostCount + _foundCount;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('No lost/found data in range', style: TextStyle(color: AdminTheme.textSecondary)),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 168,
              height: 168,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  centerSpaceColor: Colors.white,
                  sections: [
                    if (_lostCount > 0)
                      PieChartSectionData(
                        value: _lostCount.toDouble(),
                        color: AdminTheme.statLost,
                        radius: 56,
                        title: '${((100 * _lostCount) / total).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    if (_foundCount > 0)
                      PieChartSectionData(
                        value: _foundCount.toDouble(),
                        color: AdminTheme.statFound,
                        radius: 56,
                        title: '${((100 * _foundCount) / total).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pieLegendRow('Lost', _lostCount, AdminTheme.statLost),
                  const SizedBox(height: 12),
                  _pieLegendRow('Found', _foundCount, AdminTheme.statFound),
                  const SizedBox(height: 8),
                  Text(
                    'Shows share of reports in the selected period (after filters).',
                    style: TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pieLegendRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
        const Spacer(),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
      ],
    );
  }

  double _maxTrendY() {
    var m = 0.0;
    for (final s in _trendLostSpots) {
      if (s.y > m) m = s.y;
    }
    for (final s in _trendFoundSpots) {
      if (s.y > m) m = s.y;
    }
    return m;
  }

  Widget _buildTrendLineChart() {
    if (_trendDayKeys.isEmpty) {
      return const Center(child: Text('No date range'));
    }
    final maxY = _maxTrendY();
    final maxYAdj = maxY <= 0 ? 4.0 : maxY * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(0, _trendDayKeys.length - 1).toDouble(),
            minY: 0,
            maxY: maxYAdj,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AdminTheme.chartGridLine.withValues(alpha: 0.85),
                strokeWidth: 1,
                dashArray: [6, 6],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= _trendDayKeys.length) return const SizedBox();
                    final n = _trendDayKeys.length;
                    final step = math.max(1, (n / 5).ceil());
                    if (i != 0 && i != n - 1 && i % step != 0) return const SizedBox();
                    final parts = _trendDayKeys[i].split('-');
                    if (parts.length >= 3) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${parts[1]}/${parts[2]}',
                          style: const TextStyle(fontSize: 9, color: AdminTheme.textSecondary),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _trendLostSpots,
                color: AdminTheme.statLost,
                barWidth: 2.5,
                isCurved: true,
                curveSmoothness: 0.28,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AdminTheme.statLost.withValues(alpha: 0.12),
                ),
              ),
              LineChartBarData(
                spots: _trendFoundSpots,
                color: AdminTheme.statFound,
                barWidth: 2.5,
                isCurved: true,
                curveSmoothness: 0.28,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AdminTheme.statFound.withValues(alpha: 0.12),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipRoundedRadius: 8,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                getTooltipColor: (_) => AdminTheme.chartTooltipBg,
                tooltipBorder: const BorderSide(color: AdminTheme.border, width: 1),
                getTooltipItems: (touchedSpots) =>
                    touchedSpots.map((t) {
                      final idx = t.x.toInt();
                      final day = (idx >= 0 && idx < _trendDayKeys.length) ? _trendDayKeys[idx] : '';
                      final label = t.barIndex == 0 ? 'Lost' : 'Found';
                      return LineTooltipItem(
                        '$day\n$label: ${t.y.round()}',
                        const TextStyle(
                          color: AdminTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }

  Widget _trendLegend() {
    Widget chip(String text, Color c) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminTheme.textPrimary,
            ),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 8,
      children: [
        chip('Lost', AdminTheme.statLost),
        chip('Found', AdminTheme.statFound),
      ],
    );
  }

  Widget _horizontalBarCard(
    String title,
    List<Map<String, dynamic>> items, {
    required String labelKey,
    int maxItems = 10,
  }) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminTheme.sectionTitle()),
              const SizedBox(height: 8),
              Text('No data in range', style: TextStyle(color: AdminTheme.textSecondary)),
            ],
          ),
        ),
      );
    }
    final take = items.take(maxItems).toList();
    final maxC = take.map((e) => e['count'] as int).reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AdminTheme.sectionTitle()),
            const SizedBox(height: 12),
            ...take.asMap().entries.map((e) {
              final i = e.key;
              final row = e.value;
              final label = (row[labelKey] ?? '').toString();
              final count = row['count'] as int;
              final frac = maxC > 0 ? count / maxC : 0.0;
              final barColor = AdminTheme.chartBarPalette[i % AdminTheme.chartBarPalette.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AdminTheme.textPrimary),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor: AdminTheme.chartGridLine.withValues(alpha: 0.45),
                          color: barColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
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

  Widget _buildDataTable() {
    if (_tableData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No records')),
        ),
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Date')),
          ],
          rows: _tableData.take(50).map((r) {
            final createdAt = r['createdAt'];
            String dateStr = 'N/A';
            if (createdAt is Timestamp) dateStr = DateFormat.yMd().format(createdAt.toDate());
            return DataRow(
              cells: [
                DataCell(Text(r['type']?.toString() ?? '')),
                DataCell(Text((r['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(r['category']?.toString() ?? '')),
                DataCell(Text(r['status']?.toString() ?? '')),
                DataCell(Text(dateStr)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
