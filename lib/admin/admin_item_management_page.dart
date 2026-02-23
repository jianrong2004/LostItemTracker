import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_item_detail_page.dart';
import '../user/lost_item_reporting_page.dart';
import '../user/found_item_reporting_page.dart';

class AdminItemManagementPage extends StatefulWidget {
  const AdminItemManagementPage({super.key});

  @override
  State<AdminItemManagementPage> createState() => _AdminItemManagementPageState();
}

class _AdminItemManagementPageState extends State<AdminItemManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterCategory;
  String? _filterStatus;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final catSnap = await FirebaseFirestore.instance.collection('categories').get();
      if (catSnap.docs.isNotEmpty) {
        final list = catSnap.docs
            .map((d) => d.data()['name'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (mounted) {
          setState(() {
            _categories = list..sort();
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _categories = [
          'Electronics', 'Documents', 'Clothing', 'Accessories',
          'Keys', 'Bags', 'Cards', 'Others',
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Management'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: 'Lost Items'),
            Tab(text: 'Found Items'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ItemList(
                  type: 'lost',
                  searchQuery: _searchQuery,
                  filterCategory: _filterCategory,
                  filterStatus: _filterStatus,
                  categories: _categories,
                  onTap: (id, data) => _openDetail(context, 'lost', id, data),
                ),
                _ItemList(
                  type: 'found',
                  searchQuery: _searchQuery,
                  filterCategory: _filterCategory,
                  filterStatus: _filterStatus,
                  categories: _categories,
                  onTap: (id, data) => _openDetail(context, 'found', id, data),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: Colors.indigo.shade700,
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by item name or category...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => _filterCategory = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'matched', child: Text('Matched')),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, String type, String id, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminItemDetailPage(
          type: type,
          reportId: id,
          reportData: data,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search_off),
              title: const Text('Add Lost Item'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LostItemReportingPage(),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.find_in_page),
              title: const Text('Add Found Item'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FoundItemReportingPage(),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final String type;
  final String searchQuery;
  final String? filterCategory;
  final String? filterStatus;
  final List<String> categories;
  final void Function(String id, Map<String, dynamic> data) onTap;

  const _ItemList({
    required this.type,
    required this.searchQuery,
    required this.filterCategory,
    required this.filterStatus,
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final collection = type == 'lost' ? 'lost_item_reports' : 'found_item_reports';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;
        final list = <QueryDocumentSnapshot>[];
        for (var doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['itemName'] as String? ?? '').toLowerCase();
          final cat = (d['category'] as String? ?? '').toLowerCase();
          final status = d['reportStatus'] as String? ?? '';
          if (searchQuery.isNotEmpty && !name.contains(searchQuery) && !cat.contains(searchQuery)) continue;
          if (filterCategory != null && (d['category'] != filterCategory)) continue;
          if (filterStatus != null && status != filterStatus) continue;
          list.add(doc);
        }
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No items', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final doc = list[index];
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            Uint8List? thumb;
            final tb = data['thumbnailBytes'];
            if (tb != null) {
              if (tb is Uint8List) thumb = tb;
              else if (tb is List) thumb = Uint8List.fromList(List<int>.from(tb));
            }
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: thumb != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(thumb, width: 48, height: 48, fit: BoxFit.cover),
                      )
                    : CircleAvatar(
                        backgroundColor: type == 'lost' ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(
                          type == 'lost' ? Icons.search_off : Icons.find_in_page,
                          color: type == 'lost' ? Colors.red : Colors.green,
                        ),
                      ),
                title: Text(data['itemName'] as String? ?? 'Untitled'),
                subtitle: Text(
                  '${data['category'] ?? 'N/A'} • ${data['reportStatus'] ?? 'N/A'}${createdAt != null ? ' • ${DateFormat.yMd().format(createdAt)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTap(id, data),
              ),
            );
          },
        );
      },
    );
  }
}
