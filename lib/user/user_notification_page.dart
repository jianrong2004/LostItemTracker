import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'lost_item_report.dart';
import 'found_item_report.dart';
import 'user_home_page.dart';
import 'search_and_filter_page.dart';
import 'user_profile_page.dart';
import 'qr_code_page.dart';
import 'help_and_feedback_page.dart';
import 'package:lost_item_tracker_client/role_selection_page.dart';
import 'user_reward_page.dart';
import 'user_analytical_report_page.dart';

class UserNotificationPage extends StatefulWidget {
  const UserNotificationPage({super.key});

  @override
  State<UserNotificationPage> createState() => _UserNotificationPageState();
}

class _UserNotificationPageState extends State<UserNotificationPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isMarkingAllAsRead = false;
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

  Future<void> _markAllAsRead() async {
    if (currentUser == null) return;

    setState(() {
      _isMarkingAllAsRead = true;
    });

    try {
      // Get all unread notifications for current user
      final QuerySnapshot unreadNotifications = await FirebaseFirestore.instance
          .collection('user_notifications')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      // Create a batch write
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // Update all unread notifications
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Commit the batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${unreadNotifications.docs.length} notifications marked as read'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking notifications as read: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAllAsRead = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (currentUser != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_notifications')
                  .where('userId', isEqualTo: currentUser!.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                return IconButton(
                  icon: _isMarkingAllAsRead
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(
                    Icons.done_all,
                    color: hasUnread ? Colors.white : Colors.white54,
                  ),
                  tooltip: 'Mark all as read',
                  onPressed: hasUnread && !_isMarkingAllAsRead
                      ? _markAllAsRead
                      : null,
                );
              },
            ),
        ],
      ),
      endDrawer: _buildAccountDrawer(),
      body: currentUser == null
          ? const Center(
        child: Text('Please log in to view notifications'),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_notifications')
            .where('userId', isEqualTo: currentUser!.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When we find matches for your items,\nthey will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // The stream will automatically refresh
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notificationDoc = notifications[index];
                final notification =
                notificationDoc.data() as Map<String, dynamic>;

                return _buildNotificationCard(
                  context,
                  notificationDoc.id,
                  notification,
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomAppBar(context),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context,
      String notificationId,
      Map<String, dynamic> notification,
      ) {
    final matchScore = (notification['matchScore'] ?? 0.0).toDouble();
    final matchType = notification['matchType'] ?? 'lost';
    final itemId = notification['itemId'] ?? '';
    final matchedItemId = notification['matchedItemId'] ?? '';
    final dropOffDeskId = notification['dropOffDeskId'];
    final isRead = notification['isRead'] ?? false;
    final createdAt = notification['createdAt'] as Timestamp?;
    final scoreBreakdown = notification['scoreBreakdown'] as Map<String, dynamic>?;

    // Determine colors based on match score
    Color scoreColor;
    Color backgroundColor;
    String matchQuality;

    if (matchScore >= 90) {
      scoreColor = Colors.green.shade700;
      backgroundColor = Colors.green.shade50;
      matchQuality = 'Excellent Match';
    } else if (matchScore >= 80) {
      scoreColor = Colors.blue.shade700;
      backgroundColor = Colors.blue.shade50;
      matchQuality = 'High Match';
    } else if (matchScore >= 70) {
      scoreColor = Colors.orange.shade700;
      backgroundColor = Colors.orange.shade50;
      matchQuality = 'Good Match';
    } else {
      scoreColor = Colors.grey.shade700;
      backgroundColor = Colors.grey.shade50;
      matchQuality = 'Potential Match';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey.shade200 : scoreColor.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(
          context,
          notificationId,
          notification,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Match Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scoreColor.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: scoreColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${matchScore.toStringAsFixed(1)}% Match',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Unread indicator
                  if (!isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade700,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Match Quality
              Text(
                matchQuality,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                matchType == 'lost'
                    ? 'We found a potential match for your lost item!'
                    : 'We found someone who may have lost the item you found!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 12),

              // Item IDs (for debugging/reference)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.inventory,
                      'Your Item',
                      _truncateId(itemId),
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      Icons.search,
                      'Matched Item',
                      _truncateId(matchedItemId),
                    ),
                    if (dropOffDeskId != null) ...[
                      const SizedBox(height: 6),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('dropOffDesks')
                            .doc(dropOffDeskId)
                            .get(),
                        builder: (context, deskSnapshot) {
                          if (deskSnapshot.hasData &&
                              deskSnapshot.data!.exists) {
                            final deskData = deskSnapshot.data!.data()
                            as Map<String, dynamic>;
                            return _buildInfoRow(
                              Icons.location_on,
                              'Drop-off Desk',
                              deskData['name'] ?? 'Unknown',
                            );
                          }
                          return _buildInfoRow(
                            Icons.location_on,
                            'Drop-off Desk',
                            'Loading...',
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              if (scoreBreakdown != null) ...[
                const SizedBox(height: 12),
                _buildScoreBreakdown(scoreBreakdown),
              ],

              const SizedBox(height: 12),

              // Timestamp
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    createdAt != null
                        ? _formatTimestamp(createdAt)
                        : 'Just now',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleNotificationTap(
                    context,
                    notificationId,
                    notification,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scoreColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBreakdown(Map<String, dynamic> breakdown) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      title: Text(
        'Match Score Breakdown',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
      children: [
        ...breakdown.entries.map((entry) {
          final score = (entry.value ?? 0.0).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatBreakdownKey(entry.key),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: LinearProgressIndicator(
                    value: score / 25, // Normalize to max possible score
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.indigo.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    score.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatBreakdownKey(String key) {
    // Convert camelCase to Title Case
    final result = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
    );
    return result[0].toUpperCase() + result.substring(1);
  }

  String _truncateId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Future<void> _handleNotificationTap(
      BuildContext context,
      String notificationId,
      Map<String, dynamic> notification,
      ) async {
    // Mark as read
    if (!(notification['isRead'] ?? false)) {
      await FirebaseFirestore.instance
          .collection('user_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    }

    // Navigate to item details
    final matchType = notification['matchType'] ?? 'lost';
    final itemId = notification['itemId'] ?? '';
    final matchedItemId = notification['matchedItemId'] ?? '';

    // Show dialog with details
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Match Details'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match Score: ${notification['matchScore'].toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                matchType == 'lost'
                    ? 'A found item matches your lost item report!'
                    : 'A lost item report matches your found item!',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Item ID: $itemId',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Matched Item ID: $matchedItemId',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (notification['dropOffDeskId'] != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Drop-off Desk Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('dropOffDesks')
                      .doc(notification['dropOffDeskId'])
                      .get(),
                  builder: (context, deskSnapshot) {
                    if (deskSnapshot.hasData && deskSnapshot.data!.exists) {
                      final deskData =
                      deskSnapshot.data!.data() as Map<String, dynamic>;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: ${deskData['name'] ?? 'N/A'}'),
                          Text('Hours: ${deskData['operatingHours'] ?? 'N/A'}'),
                          Text('Contact: ${deskData['contact'] ?? 'N/A'}'),
                        ],
                      );
                    }
                    return const Text('Loading desk information...');
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              // Navigate to the appropriate report page
              // For matchType 'lost': user lost item, matched with found item
              // Show the matched found item report
              // For matchType 'found': user found item, matched with lost item
              // Show the matched lost item report

              if (matchType == 'lost') {
                // User's lost item matched with a found item
                // Navigate to found item report (the matched item)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FoundItemReportPage(
                      reportId: matchedItemId,
                    ),
                  ),
                );
              } else {
                // User's found item matched with a lost item
                // Navigate to lost item report (the matched item)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LostItemReportPage(
                      reportId: matchedItemId,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Item'),
          ),
        ],
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

  // ==================== BOTTOM NAVIGATION ====================
  Widget _buildBottomAppBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, Icons.home, 'Home'),
            _buildNavItem(context, Icons.search, 'Search'),
            const SizedBox(width: 40), // Space for FAB on home page
            _buildNavItem(context, Icons.notifications_outlined, 'Notification'),
            _buildNavItem(context, Icons.person, 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label) {
    final bool isSelected = label == 'Notification';
    return InkWell(
      onTap: () {
        if (label == 'Home') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const UserHomePage(),
            ),
          );
        } else if (label == 'Search') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchAndFilterPage(),
            ),
          );
        } else if (label == 'Notification') {
          // Already on notification page, do nothing
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