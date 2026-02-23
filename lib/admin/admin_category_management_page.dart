import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCategoryManagementPage extends StatefulWidget {
  const AdminCategoryManagementPage({super.key});

  @override
  State<AdminCategoryManagementPage> createState() => _AdminCategoryManagementPageState();
}

class _AdminCategoryManagementPageState extends State<AdminCategoryManagementPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _nameController.clear();
    _descController.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty) {
      await _saveCategory(null, _nameController.text.trim(), _descController.text.trim());
    }
  }

  Future<void> _showEditDialog(String id, String name, String desc, bool isActive) async {
    _nameController.text = name;
    _descController.text = desc;
    var active = isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setDialogState(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty) {
      await _saveCategory(id, _nameController.text.trim(), _descController.text.trim(), isActive: active);
    }
  }

  Future<void> _saveCategory(String? id, String name, String desc, {bool? isActive}) async {
    try {
      if (id == null) {
        await FirebaseFirestore.instance.collection('categories').add({
          'name': name,
          'description': desc,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category added'), behavior: SnackBarBehavior.floating),
        );
      } else {
        final update = <String, dynamic>{
          'name': name,
          'description': desc,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (isActive != null) update['isActive'] = isActive;
        await FirebaseFirestore.instance.collection('categories').doc(id).update(update);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category updated'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await FirebaseFirestore.instance.collection('categories').doc(id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(current ? 'Category disabled' : 'Category enabled'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Categories are used when users report lost or found items. They appear in search filters and analytics. Add or edit categories to keep options consistent across the app.',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
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
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No categories. Add one.', style: TextStyle(color: Colors.grey.shade600)),
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
              final isActive = d['isActive'] as bool? ?? true;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.teal.shade100 : Colors.grey.shade300,
                    child: Icon(Icons.category, color: isActive ? Colors.teal : Colors.grey),
                  ),
                  title: Text(d['name'] ?? 'N/A'),
                  subtitle: Text(d['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.teal.shade700),
                        onPressed: () => _showEditDialog(
                          doc.id,
                          d['name'] ?? '',
                          d['description'] ?? '',
                          isActive,
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (_) => _toggleActive(doc.id, isActive),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
}
