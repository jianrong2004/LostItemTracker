import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lost_item_reporting_page.dart';
import 'found_item_reporting_page.dart';
import 'draft_report_listing_page.dart';
import 'user_home_page.dart';
import 'search_and_filter_page.dart';
import 'user_notification_page.dart';
import 'user_profile_page.dart';
import 'qr_code_page.dart';
import 'help_and_feedback_page.dart';
import 'package:lost_item_tracker_client/role_selection_page.dart';
import 'user_reward_page.dart';
import 'user_analytical_report_page.dart';

class ReportTypeSelectionPage extends StatefulWidget {
  const ReportTypeSelectionPage({super.key});

  @override
  State<ReportTypeSelectionPage> createState() => _ReportTypeSelectionPageState();
}

class _ReportTypeSelectionPageState extends State<ReportTypeSelectionPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String? fullName;
  String? campusId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            fullName = userDoc.get('fullName') ?? 'User';
            campusId = userDoc.get('campusId') ?? 'N/A';
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
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
      appBar: AppBar(
        title: const Text('Report Item'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      endDrawer: _buildAccountDrawer(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Instruction text
              Text(
                'What would you like to report?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select one of the options below',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // I Lost an Item Card
              _buildReportCard(
                context: context,
                title: 'I Lost an Item',
                description: 'Report an item that you have lost on campus',
                icon: Icons.search_off,
                iconColor: Colors.blue.shade600,
                iconBackgroundColor: Colors.blue.shade50,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LostItemReportingPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // I Found an Item Card
              _buildReportCard(
                context: context,
                title: 'I Found an Item',
                description: 'Report an item that you have found on campus',
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.orange.shade600,
                iconBackgroundColor: Colors.orange.shade50,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FoundItemReportingPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Draft Report Card
              _buildReportCard(
                context: context,
                title: 'Draft Report',
                description: 'Continue working on your saved draft reports',
                icon: Icons.drafts_outlined,
                iconColor: Colors.purple.shade600,
                iconBackgroundColor: Colors.purple.shade50,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DraftReportListingPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAppBar(context),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon on the left
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 20),

            // Text in the middle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow icon on the right
            Icon(
              Icons.chevron_right,
              size: 28,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACCOUNT DRAWER ====================
  Widget _buildAccountDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // User Info Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade700,
                    Colors.indigo.shade500,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.indigo.shade700,
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
                    currentUser?.email ?? 'user@example.com',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${campusId ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerMenuItem(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 150));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfilePage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.qr_code,
                    title: 'QR Code',
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 150));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRCodePage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.card_giftcard,
                    title: 'Rewards',
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 150));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserRewardPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.analytics_outlined,
                    title: 'Analytics Report',
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 150));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserAnalyticalReportPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Feedback',
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 150));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpAndFeedbackPage(),
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
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
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
        color: Colors.indigo.shade700,
        size: 26,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildBottomAppBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, Icons.home, 'Home', false),
            _buildNavItem(context, Icons.search, 'Search', false),
            const SizedBox(width: 40), // Space for FAB
            _buildNavItem(context, Icons.notifications_outlined, 'Notification', false),
            _buildNavItem(context, Icons.person, 'Account', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected) {
    return InkWell(
      onTap: () {
        if (label == 'Home') {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const UserHomePage(),
              ),
            );
          }
        } else if (label == 'Search') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchAndFilterPage(),
            ),
          );
        } else if (label == 'Notification') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const UserNotificationPage(),
            ),
          );
        } else if (label == 'Account') {
          // Open account drawer instead of navigating
          _scaffoldKey.currentState?.openEndDrawer();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade500,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}