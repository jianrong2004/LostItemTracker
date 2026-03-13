import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../user/lost_item_claim.dart';

class AdminItemDetailPage extends StatefulWidget {
  final String type;
  final String reportId;
  final Map<String, dynamic> reportData;

  const AdminItemDetailPage({
    super.key,
    required this.type,
    required this.reportId,
    required this.reportData,
  });

  @override
  State<AdminItemDetailPage> createState() => _AdminItemDetailPageState();
}

class _AdminItemDetailPageState extends State<AdminItemDetailPage> {
  late Map<String, dynamic> _data;
  bool _loading = false;
  List<Map<String, dynamic>> _relatedClaims = [];
  bool _claimsLoaded = false;
  List<Map<String, dynamic>> _possibleDuplicates = [];
  bool _duplicatesLoaded = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.reportData);
    if (widget.type == 'found') _loadRelatedClaims();
    _loadPossibleDuplicates();
  }

  Future<void> _loadPossibleDuplicates() async {
    final category = _data['category'] as String?;
    final name = (_data['itemName'] as String? ?? '').toLowerCase();
    if (category == null || category.isEmpty) {
      setState(() => _duplicatesLoaded = true);
      return;
    }
    try {
      final col = widget.type == 'lost' ? 'lost_item_reports' : 'found_item_reports';
      final snap = await FirebaseFirestore.instance
          .collection(col)
          .where('category', isEqualTo: category)
          .get();
      final others = snap.docs
          .where((d) => d.id != widget.reportId)
          .map((d) => {'id': d.id, ...d.data()})
          .where((m) {
        final n = (m['itemName'] as String? ?? '').toLowerCase();
        return n.isNotEmpty && (name.isEmpty || n.contains(name) || name.contains(n));
      })
          .take(5)
          .toList();
      if (mounted) {
        setState(() {
          _possibleDuplicates = others;
          _duplicatesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _duplicatesLoaded = true);
      }
    }
  }

  Future<void> _loadRelatedClaims() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lost_item_claims')
          .where('foundItemReportId', isEqualTo: widget.reportId)
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        setState(() {
          _relatedClaims = snap.docs.map((d) => {'id': d.id, ...?d.data()}).toList();
          _claimsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _claimsLoaded = true);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      final col = widget.type == 'lost' ? 'lost_item_reports' : 'found_item_reports';
      await FirebaseFirestore.instance.collection(col).doc(widget.reportId).update({
        'reportStatus': newStatus,
        'itemReturnStatus': newStatus == 'resolved' || newStatus == 'matched' ? 'returned' : (_data['itemReturnStatus'] ?? 'pending'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _data['reportStatus'] = newStatus;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDateTime(dynamic t) {
    if (t == null) return 'N/A';
    if (t is Timestamp) return DateFormat.yMd().add_Hm().format(t.toDate());
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? photoBytes;
    final pb = _data['photoBytes'] ?? _data['thumbnailBytes'];
    if (pb != null) {
      if (pb is Uint8List) photoBytes = pb;
      else if (pb is List) photoBytes = Uint8List.fromList(List<int>.from(pb));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type == 'lost' ? 'Lost' : 'Found'} Item Detail'),
        backgroundColor: widget.type == 'lost' ? Colors.red.shade700 : Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _updateStatus(v),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'submitted', child: Text('Submitted')),
              const PopupMenuItem(value: 'resolved', child: Text('Resolved')),
              const PopupMenuItem(value: 'matched', child: Text('Matched')),
              const PopupMenuItem(value: 'draft', child: Text('Draft')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoBytes != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(photoBytes, height: 200, fit: BoxFit.contain),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _section('Basic Info', [
                    _row('Item name', _data['itemName'] ?? 'N/A'),
                    _row('Category', _data['category'] ?? 'N/A'),
                    _row('Description', _data['itemDescription'] ?? 'N/A'),
                    _row('Status', _data['reportStatus'] ?? 'N/A'),
                  ]),
                  if (widget.type == 'lost') ...[
                    _section('Lost details', [
                      _row('Lost date/time', _formatDateTime(_data['lostDateTime'])),
                      _row('Address', _data['address'] ?? 'N/A'),
                      _row('Location description', _data['locationDescription'] ?? 'N/A'),
                    ]),
                  ] else ...[
                    _section('Found details', [
                      _row('Found date/time', _formatDateTime(_data['foundDateTime'])),
                      _row('Address', _data['address'] ?? 'N/A'),
                      _row('Drop-off desk ID', _data['dropOffDeskId'] ?? 'N/A'),
                    ]),
                  ],
                  _section('Meta', [
                    _row('Report ID', widget.reportId),
                    _row('Created', _formatDateTime(_data['createdAt'])),
                    _row('Updated', _formatDateTime(_data['updatedAt'])),
                  ]),
                  if (_duplicatesLoaded && _possibleDuplicates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Duplicate hint: similar items (same category)', style: TextStyle(fontSize: 14, color: Colors.orange.shade700)),
                    const SizedBox(height: 4),
                    ..._possibleDuplicates.map((m) => ListTile(
                      dense: true,
                      title: Text(m['itemName']?.toString() ?? 'Untitled'),
                      subtitle: Text('ID: ${m['id']}'),
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminItemDetailPage(type: widget.type, reportId: m['id'] as String, reportData: m))),
                    )),
                  ],
                  if (widget.type == 'found') ...[
                    const SizedBox(height: 16),
                    Text('Related Claims (${_relatedClaims.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (!_claimsLoaded)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                    else if (_relatedClaims.isEmpty)
                      Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('No claims', style: TextStyle(color: Colors.grey.shade600))))
                    else
                      ..._relatedClaims.map((c) {
                      final cid = c['id'] as String? ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('Claim ${cid.length > 8 ? cid.substring(0, 8) : cid}'),
                          subtitle: Text('Status: ${c['claimStatus'] ?? 'N/A'} • ${_formatDateTime(c['createdAt'])}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LostItemClaimPage(claimId: cid),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
