import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'admin_report_export_page.dart';

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

      for (var d in lostSnap.docs) {
        final data = d.data();
        if (_filterCategory != null && data['category'] != _filterCategory) continue;
        lostCount++;
        final cat = data['category'] as String? ?? 'Other';
        categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        if (data['reportStatus'] == 'resolved' || data['reportStatus'] == 'matched') resolvedCount++;
        tableData.add({'type': 'Lost', 'id': d.id, 'name': data['itemName'], 'category': cat, 'status': data['reportStatus'], 'createdAt': data['createdAt']});
      }
      for (var d in foundSnap.docs) {
        final data = d.data();
        if (_filterCategory != null && data['category'] != _filterCategory) continue;
        if (_filterLocation != null && data['dropOffDeskId'] != _filterLocation) continue;
        foundCount++;
        final cat = data['category'] as String? ?? 'Other';
        categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        if (data['reportStatus'] == 'resolved' || data['reportStatus'] == 'matched') resolvedCount++;
        tableData.add({'type': 'Found', 'id': d.id, 'name': data['itemName'], 'category': cat, 'status': data['reportStatus'], 'createdAt': data['createdAt']});
      }
      for (var d in claimsSnap.docs) {
        final data = d.data();
        if (data['claimStatus'] == 'approved') resolvedCount++;
      }

      final breakdown = categoryMap.entries.map((e) => {'category': e.key, 'count': e.value}).toList();
      breakdown.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      if (mounted) {
        setState(() {
          _lostCount = lostCount;
          _foundCount = foundCount;
          _claimsCount = claimsCount;
          _resolvedCount = resolvedCount;
          _categoryBreakdown = breakdown;
          _tableData = tableData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => Navigator.push(
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
            ),
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
                    const SizedBox(height: 20),
                    const Text('By category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(height: 220, child: _buildCategoryChart()),
                    const SizedBox(height: 20),
                    const Text('Detailed data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _filterCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ..._categoryBreakdown.map((e) => DropdownMenuItem(value: e['category'] as String, child: Text(e['category'] as String))),
                    ],
                    onChanged: (v) => setState(() => _filterCategory = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _filterLocation,
                    decoration: const InputDecoration(labelText: 'Location'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                    ],
                    onChanged: (v) => setState(() => _filterLocation = v),
                  ),
                ),
              ],
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
        Expanded(child: _summaryCard('Lost', _lostCount, Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Found', _foundCount, Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Claims', _claimsCount, Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Resolved', _resolvedCount, Colors.teal)),
      ],
    );
  }

  Widget _summaryCard(String label, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    if (_categoryBreakdown.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final spots = _categoryBreakdown.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble())).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2).clamp(1, double.infinity),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, meta) => Text(v.toInt().toString()))),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i >= 0 && i < _categoryBreakdown.length) {
                      final cat = _categoryBreakdown[i]['category'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(cat.length > 6 ? '${cat.substring(0, 6)}.' : cat, style: const TextStyle(fontSize: 10)),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            barGroups: spots.asMap().entries.map((e) => BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(toY: e.value.y, color: Colors.purple, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
              showingTooltipIndicators: [0],
            )).toList(),
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_tableData.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No records'))));
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
