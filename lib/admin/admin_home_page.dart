import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../role_selection_page.dart';
import 'admin_item_management_page.dart';
import 'admin_item_detail_page.dart';
import 'admin_claim_verification_page.dart';
import 'admin_location_management_page.dart';
import 'admin_reports_analytics_page.dart';
import 'admin_profile_page.dart';
import 'admin_reward_management_page.dart';
import 'admin_access_management_page.dart';
import 'admin_theme.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminRecentItem {
  final String reportId;
  final String itemName;
  final String category;
  final Uint8List? thumbnailBytes;

  _AdminRecentItem({
    required this.reportId,
    required this.itemName,
    required this.category,
    this.thumbnailBytes,
  });
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String? fullName;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  // Statistics
  int _totalLostItems = 0;
  int _totalFoundItems = 0;
  int _totalUsers = 0;
  int _resolvedItems = 0;

  // Recent Activity (recent lost items)
  List<_AdminRecentItem> _recentLostItems = [];
  bool _isLoadingRecent = false;
  bool _recentError = false;
  bool _isSuperAdmin = false;

  Uint8List? _convertPhotoBytes(dynamic data) {
    if (data == null) return null;
    if (data is Uint8List) return data;
    if (data is Blob) return data.bytes;
    if (data is List) return Uint8List.fromList(List<int>.from(data));
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminData();
    _loadStatistics();
    _loadRecentLostItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            fullName = userDoc.get('fullName') ?? 'Admin';
            final userData = userDoc.data() as Map<String, dynamic>;
            final email =
                (userData['email'] ?? currentUser?.email ?? '').toString().toLowerCase();
            final name = (userData['fullName'] ?? '').toString().toLowerCase();
            final role = (userData['role'] ?? '').toString().toLowerCase();
            _isSuperAdmin = role == 'super_admin' ||
                email == 'myphone' ||
                email.startsWith('myphone@') ||
                name == 'myphone';
          });
        }
      } catch (e) {
        print('Error loading admin data: $e');
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Get total lost items
      QuerySnapshot lostItems = await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .get();
      
      // Get total found items
      QuerySnapshot foundItems = await FirebaseFirestore.instance
          .collection('found_item_reports')
          .get();
      
      // Get total users
      QuerySnapshot users = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();

      // Count resolved items (reportStatus 'resolved' or 'matched')
      int resolved = 0;
      for (var doc in lostItems.docs) {
        final status = doc.get('reportStatus') ?? doc.get('status');
        if (status == 'resolved' || status == 'matched') {
          resolved++;
        }
      }
      for (var doc in foundItems.docs) {
        final status = doc.get('reportStatus') ?? doc.get('status');
        if (status == 'resolved' || status == 'matched') {
          resolved++;
        }
      }

      setState(() {
        _totalLostItems = lostItems.docs.length;
        _totalFoundItems = foundItems.docs.length;
        _totalUsers = users.docs.length;
        _resolvedItems = resolved;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _loadRecentLostItems() async {
    if (mounted) setState(() { _isLoadingRecent = true; _recentError = false; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      final items = <_AdminRecentItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawPhoto = _convertPhotoBytes(
          data['thumbnailBytes'] ?? data['photoBytes'],
        );
        items.add(_AdminRecentItem(
          reportId: doc.id,
          itemName: data['itemName'] as String? ?? 'Untitled',
          category: data['category'] as String? ?? '',
          thumbnailBytes: rawPhoto,
        ));
      }

      if (mounted) {
        setState(() {
          _recentLostItems = items;
          _isLoadingRecent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecent = false;
          _recentError = true;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context); // Close drawer first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();

              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionPage(),
                ),
                (route) => false,
              );
            },
            child: Text(
              'Logout',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminTheme.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.95),
                boxShadow: AdminTheme.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Text(
                'Admin Console',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AdminTheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.65),
          indicatorColor: AdminTheme.accent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 22), text: 'Overview'),
            Tab(icon: Icon(Icons.grid_view_rounded, size: 22), text: 'Management'),
          ],
        ),
      ),
      drawer: _buildAccountDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildManagementTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SizedBox(
        width: double.infinity,
        child: RefreshIndicator(
        onRefresh: () async {
          await _loadAdminData();
          await _loadStatistics();
          await _loadRecentLostItems();
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshed'),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 1,
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: AdminTheme.headerGradient,
                    borderRadius: BorderRadius.circular(AdminTheme.radiusL),
                    boxShadow: AdminTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Signed in',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullName ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentUser?.email ?? 'admin@example.com',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
),

                const SizedBox(height: 28),

                Text('Overview', style: AdminTheme.sectionTitle()),
                const SizedBox(height: 4),
                Text(
                  'Key metrics at a glance',
                  style: TextStyle(fontSize: 13, color: AdminTheme.textSecondary),
                ),

                const SizedBox(height: 16),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Lost Items',
                        value: _totalLostItems.toString(),
                        icon: Icons.search_off_rounded,
                        accent: AdminTheme.statLost,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Found Items',
                        value: _totalFoundItems.toString(),
                        icon: Icons.inventory_2_outlined,
                        accent: AdminTheme.statFound,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total Users',
                        value: _totalUsers.toString(),
                        icon: Icons.people_outline_rounded,
                        accent: AdminTheme.statUsers,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Resolved',
                        value: _resolvedItems.toString(),
                        icon: Icons.check_circle_outline_rounded,
                        accent: AdminTheme.statResolved,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Recent Activity (Latest Lost Items)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.history_rounded, size: 20, color: AdminTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent lost items', style: AdminTheme.sectionTitle()),
                          Text(
                            'Latest submissions from users',
                            style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRecentActivityFeed(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityFeed() {
    if (_isLoadingRecent) {
      return SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AdminTheme.primary),
        ),
      );
    }
    if (_recentError) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
              const SizedBox(height: 8),
              Text(
                'Failed to load recent items',
                style: TextStyle(fontSize: 14, color: Colors.red.shade600),
              ),
            ],
          ),
        ),
      );
    }
    if (_recentLostItems.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                'No lost item reports yet',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentLostItems.length,
        itemBuilder: (context, index) {
          return _buildRecentItemCard(_recentLostItems[index]);
        },
      ),
    );
  }

  Widget _buildRecentItemCard(_AdminRecentItem item) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () async {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('lost_item_reports')
                .doc(item.reportId)
                .get();
            if (doc.exists && mounted) {
              final data = Map<String, dynamic>.from(doc.data()!);
              data['id'] = doc.id;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminItemDetailPage(
                    type: 'lost',
                    reportId: doc.id,
                    reportData: data,
                  ),
                ),
              ).then((_) => setState(() {}));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          decoration: AdminTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 160,
                  height: 120,
                  child: item.thumbnailBytes != null
                      ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade100,
                          child: Center(
                            child: Icon(
                              Icons.search_off,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Lost',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.category.isNotEmpty)
                      Text(
                        item.category,
                        style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStatistics();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refreshed'), behavior: SnackBarBehavior.floating),
          );
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tools', style: AdminTheme.sectionTitle()),
              const SizedBox(height: 4),
              Text(
                'Operations, data & exports',
                style: TextStyle(fontSize: 13, color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              Text('OPERATIONS', style: AdminTheme.sectionGroupLabel()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Items',
                      subtitle: 'Lost & found',
                      color: AdminTheme.primary,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminItemManagementPage())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.verified_user_outlined,
                      title: 'Claims',
                      subtitle: 'Verification',
                      color: AdminTheme.accent,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminClaimVerificationPage())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.place_outlined,
                      title: 'Locations',
                      subtitle: 'Drop-off desks',
                      color: const Color(0xFF0F766E),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminLocationManagementPage())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.card_giftcard,
                      title: 'Rewards',
                      subtitle: 'Vouchers',
                      color: const Color(0xFFB45309),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminRewardManagementPage())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('INSIGHTS', style: AdminTheme.sectionGroupLabel()),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.analytics_outlined,
                title: 'Analytics',
                subtitle: 'Reports, charts & export',
                color: const Color(0xFF6D28D9),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsAnalyticsPage()),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDrawer() {
    return Drawer(
      child: Container(
        color: AdminTheme.cardSurface,
        child: Column(
          children: [
            // Admin Info Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: AdminTheme.headerGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 44,
                      color: AdminTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.email ?? 'admin@example.com',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Administrator',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text('ACCOUNT', style: AdminTheme.sectionGroupLabel()),
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfilePage()));
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                  ),
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Text('MODULES', style: AdminTheme.sectionGroupLabel()),
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Item Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminItemManagementPage()));
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.verified_user_outlined,
                    title: 'Claim Verification',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminClaimVerificationPage()));
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.place_outlined,
                    title: 'Location Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLocationManagementPage()));
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.card_giftcard,
                    title: 'Reward Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRewardManagementPage()));
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.analytics_outlined,
                    title: 'Reports & Analytics',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsAnalyticsPage()));
                    },
                  ),
                  if (_isSuperAdmin)
                    _buildDrawerMenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin Access',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminAccessManagementPage(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // Logout Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminTheme.scaffoldBackground,
                border: Border(
                  top: BorderSide(color: AdminTheme.border),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AdminTheme.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminTheme.radiusM),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.cardSurface,
                  border: const Border(
                    top: BorderSide(color: AdminTheme.border),
                    right: BorderSide(color: AdminTheme.border),
                    bottom: BorderSide(color: AdminTheme.border),
                  ),
                  boxShadow: AdminTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 22, color: accent),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AdminTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminTheme.radiusM),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AdminTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
