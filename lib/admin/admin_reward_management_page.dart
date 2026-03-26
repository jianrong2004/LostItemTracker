import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_theme.dart';

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
    if (points < 0 || points > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Required points must be between 0 and 100'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (validityDays < 1 || validityDays > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid days must be between 1 and 30'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'requiredPoints': points,
        'validityDays': validityDays.clamp(1, 30),
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
      backgroundColor: AdminTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Reward Management'),
        backgroundColor: AdminTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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

class _RewardFormDialog extends StatefulWidget {
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
  State<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<_RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _validateName(String? v) {
    final name = (v ?? '').trim();
    if (name.isEmpty) return 'Name is required';
    return null;
  }

  String? _validatePoints(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Required points is required';
    final n = int.tryParse(raw);
    if (n == null) return 'Required points must be a number';
    if (n < 0 || n > 100) return 'Required points must be between 0 and 100';
    return null;
  }

  String? _validateDays(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Valid days is required';
    final n = int.tryParse(raw);
    if (n == null) return 'Valid days must be a number';
    if (n < 1 || n > 30) return 'Valid days must be between 1 and 30';
    return null;
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: widget.nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: _validateName,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.pointsController,
                  decoration: const InputDecoration(
                    labelText: 'Required points (0-100)',
                    hintText: 'e.g. 50',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePoints,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.validityDaysController,
                  decoration: const InputDecoration(
                    labelText: 'Valid for (days) (1-30)',
                    hintText: 'e.g. 30',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validateDays,
                ),
                if (widget.isActive != null && widget.onActiveChanged != null) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Visible in store (users can claim)'),
                    value: widget.isActive!,
                    onChanged: widget.onActiveChanged,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
