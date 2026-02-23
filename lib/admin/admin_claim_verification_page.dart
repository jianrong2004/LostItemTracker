import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../user/lost_item_claim.dart';

class AdminClaimVerificationPage extends StatefulWidget {
  const AdminClaimVerificationPage({super.key});

  @override
  State<AdminClaimVerificationPage> createState() => _AdminClaimVerificationPageState();
}

class _AdminClaimVerificationPageState extends State<AdminClaimVerificationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Verification'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lost_item_claims')
            .where('claimStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Sort by createdAt descending in memory (avoids composite index)
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aT = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aT == null && bT == null) return 0;
              if (aT == null) return 1;
              if (bT == null) return -1;
              return bT.compareTo(aT);
            });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No pending claims', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _ClaimCard(
                claimId: doc.id,
                data: data,
                onApprove: () => _approveClaim(doc.id, data),
                onReject: () => _rejectClaim(doc.id),
                onTap: () => _openDetail(doc.id),
              );
            },
          );
        },
      ),
    );
  }

  void _openDetail(String claimId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LostItemClaimPage(claimId: claimId),
      ),
    );
  }

  Future<void> _approveClaim(String claimId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Claim'),
        content: const Text('Approve this claim? The user will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('lost_item_claims').doc(claimId).update({
        'claimStatus': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': 'admin',
      });
      final foundId = data['foundItemReportId'] as String?;
      if (foundId != null) {
        await FirebaseFirestore.instance.collection('found_item_reports').doc(foundId).update({
          'reportStatus': 'resolved',
          'itemReturnStatus': 'claimed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim approved'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectClaim(String claimId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Claim'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Reject')),
          ],
        );
      },
    );
    if (reason == null && mounted == false) return;
    try {
      await FirebaseFirestore.instance.collection('lost_item_claims').doc(claimId).update({
        'claimStatus': 'rejected',
        'rejectionReason': reason ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': 'admin',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim rejected'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ClaimCard extends StatelessWidget {
  final String claimId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const _ClaimCard({
    required this.claimId,
    required this.data,
    required this.onApprove,
    required this.onReject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? proofBytes;
    final pb = data['proofPhotoBytes'];
    if (pb != null) {
      if (pb is Uint8List) proofBytes = pb;
      else if (pb is List) proofBytes = Uint8List.fromList(List<int>.from(pb));
    }
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (proofBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(proofBytes, width: 64, height: 64, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.image_not_supported, color: Colors.grey.shade400),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Claim ${claimId.substring(0, claimId.length > 8 ? 8 : claimId.length)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(data['fullName'] ?? 'N/A', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        if (createdAt != null) Text(DateFormat.yMd().add_Hm().format(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Checklist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip('ID verified', Icons.badge),
                  _chip('Proof photo', proofBytes != null ? Icons.check : Icons.warning),
                  _chip('Contact info', (data['phoneNumber'] != null && data['email'] != null) ? Icons.check : Icons.warning),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16, color: icon == Icons.check ? Colors.green : Colors.orange),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
