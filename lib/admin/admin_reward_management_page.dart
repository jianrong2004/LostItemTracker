import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin page to manage claimable rewards (vouchers).
/// Uses Firestore collection [vouchers] with: name, description, requiredPoints, validityDays, isActive.
class AdminRewardManagementPage extends StatefulWidget {
  const AdminRewardManagementPage({super.key});

  @override
  State<AdminRewardManagementPage> createState() => _AdminRewardManagementPageState();
}

class _AdminRewardManagementPageState extends State<AdminRewardManagementPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController();
  final _validityDaysController = TextEditingController(text: '30');

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    _validityDaysController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _nameController.clear();
    _descController.clear();
    _pointsController.clear();
    _validityDaysController.text = '30';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RewardFormDialog(
        nameController: _nameController,
        descController: _descController,
        pointsController: _pointsController,
        validityDaysController: _validityDaysController,
        title: 'Add reward (voucher)',
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty) {
      await _saveVoucher(null);
    }
  }

  Future<void> _showEditDialog(String id, String name, String desc, int requiredPoints, int validityDays, bool isActive) async {
    _nameController.text = name;
    _descController.text = desc;
    _pointsController.text = requiredPoints.toString();
    _validityDaysController.text = validityDays.toString();
    var active = isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _RewardFormDialog(
          nameController: _nameController,
          descController: _descController,
          pointsController: _pointsController,
          validityDaysController: _validityDaysController,
          title: 'Edit reward',
          isActive: active,
          onActiveChanged: (v) => setDialogState(() => active = v),
        ),
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty) {
      await _saveVoucher(id, isActive: active);
    }
  }

  Future<void> _saveVoucher(String? id, {bool? isActive}) async {
    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    final validityDays = int.tryParse(_validityDaysController.text.trim()) ?? 30;
    if (points < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Required points must be ≥ 0'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'requiredPoints': points,
        'validityDays': validityDays.clamp(1, 365),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isActive != null) {
        data['isActive'] = isActive;
      }
      if (id == null) {
        data['isActive'] = true;
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('vouchers').add(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reward added'), behavior: SnackBarBehavior.floating),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('vouchers').doc(id).update(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reward updated'), behavior: SnackBarBehavior.floating),
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

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await FirebaseFirestore.instance.collection('vouchers').doc(id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(current ? 'Reward hidden from store' : 'Reward visible in store'),
            behavior: SnackBarBehavior.floating,
          ),
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

  Future<void> _deleteReward(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reward'),
        content: Text('Delete "$name"? Users who already redeemed it will keep their voucher.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('vouchers').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reward deleted'), behavior: SnackBarBehavior.floating),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reward Management'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vouchers')
            .orderBy('requiredPoints')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No rewards. Add one to show in the voucher store.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data() as Map<String, dynamic>;
              final name = d['name'] as String? ?? 'Voucher';
              final description = d['description'] as String? ?? '';
              final requiredPoints = (d['requiredPoints'] as num?)?.toInt() ?? 0;
              final validityDays = (d['validityDays'] as num?)?.toInt() ?? 30;
              final isActive = d['isActive'] as bool? ?? true;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.amber.shade100 : Colors.grey.shade300,
                    child: Icon(Icons.local_offer, color: isActive ? Colors.amber.shade700 : Colors.grey),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    '$requiredPoints pts • ${validityDays}d valid${description.isEmpty ? '' : ' • $description'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.amber.shade800),
                        onPressed: () => _showEditDialog(doc.id, name, description, requiredPoints, validityDays, isActive),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                        onPressed: () => _deleteReward(doc.id, name),
                        tooltip: 'Delete',
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (_) => _toggleActive(doc.id, isActive),
                        activeColor: Colors.amber.shade700,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.amber.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RewardFormDialog extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController pointsController;
  final TextEditingController validityDaysController;
  final String title;
  final bool? isActive;
  final ValueChanged<bool>? onActiveChanged;

  const _RewardFormDialog({
    required this.nameController,
    required this.descController,
    required this.pointsController,
    required this.validityDaysController,
    required this.title,
    this.isActive,
    this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(
                  labelText: 'Required points',
                  hintText: 'e.g. 50',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: validityDaysController,
                decoration: const InputDecoration(
                  labelText: 'Valid for (days)',
                  hintText: 'e.g. 30',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (isActive != null && onActiveChanged != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Visible in store (users can claim)'),
                  value: isActive!,
                  onChanged: onActiveChanged,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final name = nameController.text.trim();
            final points = pointsController.text.trim();
            final days = validityDaysController.text.trim();

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name is required')),
              );
              return;
            }
            if (!RegExp(r'^[A-Za-z0-9\\s]+$').hasMatch(name)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name must contain letters, numbers and spaces only')),
              );
              return;
            }
            if (points.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(points)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Required points must be digits only')),
              );
              return;
            }
            if (days.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(days)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Valid days must be digits only')),
              );
              return;
            }
            Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
