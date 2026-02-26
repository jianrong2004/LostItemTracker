import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:downloadsfolder/downloadsfolder.dart' as downloads;
import 'dart:io';

class AdminReportExportPage extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final int lostCount;
  final int foundCount;
  final int claimsCount;
  final int resolvedCount;
  final List<Map<String, dynamic>> categoryBreakdown;
  final List<Map<String, dynamic>> tableData;

  const AdminReportExportPage({
    super.key,
    this.startDate,
    this.endDate,
    this.lostCount = 0,
    this.foundCount = 0,
    this.claimsCount = 0,
    this.resolvedCount = 0,
    this.categoryBreakdown = const [],
    this.tableData = const [],
  });

  @override
  State<AdminReportExportPage> createState() => _AdminReportExportPageState();
}

class _AdminReportExportPageState extends State<AdminReportExportPage> {
  String _analysisText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateAnalysis();
  }

  void _generateAnalysis() {
    final start = widget.startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = widget.endDate ?? DateTime.now();
    final total = widget.lostCount + widget.foundCount;
    final resolveRate = total > 0 ? (widget.resolvedCount / total * 100).toStringAsFixed(1) : '0';
    final topCategory = widget.categoryBreakdown.isNotEmpty
        ? widget.categoryBreakdown.first['category'] as String? ?? 'N/A'
        : 'N/A';
    setState(() {
      _analysisText = '''
Monthly Statistics Report
Period: ${DateFormat.yMd().format(start)} - ${DateFormat.yMd().format(end)}

Summary:
- Lost item reports: ${widget.lostCount}
- Found item reports: ${widget.foundCount}
- Claims submitted: ${widget.claimsCount}
- Resolved/Matched: ${widget.resolvedCount}
- Resolution rate: $resolveRate%

Analysis:
${total == 0 ? 'No activity in this period.' : 'Total reports in period: $total. Top category: $topCategory. ${widget.resolvedCount > 0 ? 'Resolution rate indicates effective matching and claim verification.' : 'Consider promoting claim process to improve resolution.'}'}
''';
      _loading = false;
    });
  }

  Future<String> _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('Type,Name,Category,Status,CreatedAt');
    for (final r in widget.tableData) {
      final createdAt = r['createdAt'];
      String dateStr = 'N/A';
      if (createdAt is Timestamp) dateStr = DateFormat.yMd().format(createdAt.toDate());
      buffer.writeln('${r['type']},"${r['name'] ?? ''}",${r['category']},${r['status']},$dateStr');
    }
    return buffer.toString();
  }

  Future<void> _downloadCsv() async {
    try {
      final csv = await _exportCsv();
      final dir = await getTemporaryDirectory();
      final name = 'report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      final tempFile = File('${dir.path}/$name');
      await tempFile.writeAsString(csv);

      final success = await downloads.copyFileIntoDownloadFolder(tempFile.path, name);
      if (mounted) {
        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV saved to Downloads: $name'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to save CSV to Downloads'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final pdf = pw.Document();
      final start = widget.startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = widget.endDate ?? DateTime.now();
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, child: pw.Text('Lost & Found Report', style: pw.TextStyle(fontSize: 24))),
            pw.Paragraph(text: 'Period: ${DateFormat.yMd().format(start)} - ${DateFormat.yMd().format(end)}'),
            pw.Paragraph(text: _analysisText),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: ['Type', 'Name', 'Category', 'Status', 'Date'].map((e) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e))).toList(),
                ),
                ...widget.tableData.take(30).map((r) {
                  final createdAt = r['createdAt'];
                  String dateStr = 'N/A';
                  if (createdAt is Timestamp) dateStr = DateFormat.yMd().format(createdAt.toDate());
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['type']?.toString() ?? '')),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text((r['name'] ?? '').toString())),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['category']?.toString() ?? '')),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['status']?.toString() ?? '')),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(dateStr)),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final name = 'report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final tempFile = File('${dir.path}/$name');
      await tempFile.writeAsBytes(bytes);

      final success = await downloads.copyFileIntoDownloadFolder(tempFile.path, name);
      if (mounted) {
        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to Downloads: $name'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to save PDF to Downloads'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Report'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Monthly Statistics / Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(_analysisText, style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.grey.shade800)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Export', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _downloadPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Download PDF'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _downloadCsv,
                          icon: const Icon(Icons.table_chart),
                          label: const Text('Download CSV'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
