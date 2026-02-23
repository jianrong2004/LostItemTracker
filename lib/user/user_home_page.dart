import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_type_selection_page.dart';
import 'campus_map_page.dart';
import 'user_profile_page.dart';
import 'user_notification_page.dart';
import 'report_history_page.dart';
import 'lost_item_report.dart';
import 'found_item_report.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'search_and_filter_page.dart';
import 'qr_code_page.dart';
import 'help_and_feedback_page.dart';
import 'package:lost_item_tracker_client/role_selection_page.dart';
import 'user_reward_page.dart';
import 'user_analytical_report_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String? fullName;
  String? campusId;
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _unreadNotificationCount = 0;

  // Lightweight feed data (avoids holding full Firestore docs in memory)
  List<_FeedItem>? _lostFeedItems;
  List<_FeedItem>? _foundFeedItems;
  bool _isLoadingLostFeed = true;
  bool _isLoadingFoundFeed = true;
  bool _lostFeedError = false;
  bool _foundFeedError = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToNotifications();
    _loadLostFeed();
    _loadFoundFeed();
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

  void _listenToNotifications() {
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('user_notifications')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = snapshot.docs.length;
        });
      }
    });
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

  Uint8List? _convertPhotoBytes(dynamic photoBytesData) {
    if (photoBytesData == null) return null;
    if (photoBytesData is Uint8List) return photoBytesData;
    if (photoBytesData is Blob) return photoBytesData.bytes;
    if (photoBytesData is List) {
      return Uint8List.fromList(List<int>.from(photoBytesData));
    }
    return null;
  }

  // Compress image bytes down to a small thumbnail to avoid holding large blobs in memory
  Future<Uint8List?> _createThumbnail(Uint8List? photoBytes) async {
    if (photoBytes == null) return null;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        photoBytes,
        targetWidth: 160,
        targetHeight: 160,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      const double targetSize = 160.0;
      final double scale = targetSize /
          (image.width > image.height ? image.width.toDouble() : image.height.toDouble());
      final int newWidth = (image.width * scale).toInt();
      final int newHeight = (image.height * scale).toInt();

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        Paint(),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image thumbnailImage = await picture.toImage(newWidth, newHeight);
      final ByteData? byteData =
      await thumbnailImage.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();
      thumbnailImage.dispose();
      codec.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadLostFeed() async {
    if (mounted) setState(() { _isLoadingLostFeed = true; _lostFeedError = false; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .where('reportStatus', isEqualTo: 'submitted')
          .where('itemReturnStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      final items = <_FeedItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawPhoto = _convertPhotoBytes(data['photoBytes']);
        final thumbnail = await _createThumbnail(rawPhoto);
        // rawPhoto goes out of scope here and becomes eligible for GC
        items.add(_FeedItem(
          reportId: doc.id,
          itemName: data['itemName'] as String? ?? 'Untitled',
          category: data['category'] as String? ?? '',
          thumbnailBytes: thumbnail,
        ));
      }
      // snapshot goes out of scope → full document data eligible for GC

      if (mounted) {
        setState(() {
          _lostFeedItems = items;
          _isLoadingLostFeed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLostFeed = false;
          _lostFeedError = true;
        });
      }
    }
  }

  Future<void> _loadFoundFeed() async {
    if (mounted) setState(() { _isLoadingFoundFeed = true; _foundFeedError = false; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('found_item_reports')
          .where('reportStatus', isEqualTo: 'submitted')
          .where('itemReturnStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      final items = <_FeedItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawPhoto = _convertPhotoBytes(data['photoBytes']);
        final thumbnail = await _createThumbnail(rawPhoto);
        items.add(_FeedItem(
          reportId: doc.id,
          itemName: data['itemName'] as String? ?? 'Untitled',
          category: data['category'] as String? ?? '',
          thumbnailBytes: thumbnail,
        ));
      }

      if (mounted) {
        setState(() {
          _foundFeedItems = items;
          _isLoadingFoundFeed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFoundFeed = false;
          _foundFeedError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
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
                'TARUMT Lost Item Tracker',
                style: TextStyle(fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle,
              color: Colors.indigo.shade700,),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: _buildAccountDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          _loadLostFeed();
          _loadFoundFeed();
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.indigo.shade700,
                        Colors.indigo.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fullName ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser?.email ?? 'User',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${campusId ?? 'Loading...'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),

                const SizedBox(height: 16),

                // Action Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.add_circle_outline,
                        title: 'Report Item',
                        color: Colors.red.shade400,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportTypeSelectionPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.search,
                        title: 'Find Item',
                        color: Colors.green.shade400,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchAndFilterPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.map_outlined,
                        title: 'Campus Map',
                        color: Colors.blue.shade400,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CampusMapPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.history,
                        title: 'My Reports',
                        color: Colors.orange.shade400,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportHistoryPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ==================== LATEST LOST ITEM FEED ====================
                _buildFeedSectionTitle(
                  title: 'Latest Lost Item',
                  icon: Icons.search_off,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(height: 12),
                _buildLostItemFeed(),

                const SizedBox(height: 28),

                // ==================== LATEST FOUND ITEM FEED ====================
                _buildFeedSectionTitle(
                  title: 'Latest Found Item',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(height: 12),
                _buildFoundItemFeed(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReportTypeSelectionPage(),
            ),
          );
        },
        backgroundColor: Colors.indigo.shade700,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ==================== FEED SECTION TITLE ====================
  Widget _buildFeedSectionTitle({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  // ==================== LOST ITEM FEED ====================
  Widget _buildLostItemFeed() {
    if (_isLoadingLostFeed) {
      return _buildFeedLoadingPlaceholder();
    }
    if (_lostFeedError) {
      return _buildFeedErrorPlaceholder();
    }
    final items = _lostFeedItems ?? [];
    if (items.isEmpty) {
      return _buildFeedEmptyPlaceholder(
        icon: Icons.search_off,
        message: 'No lost item reports yet',
        color: Colors.blue,
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildFeedThumbnailCard(
            feedItem: items[index],
            reportType: 'lost',
          );
        },
      ),
    );
  }

  // ==================== FOUND ITEM FEED ====================
  Widget _buildFoundItemFeed() {
    if (_isLoadingFoundFeed) {
      return _buildFeedLoadingPlaceholder();
    }
    if (_foundFeedError) {
      return _buildFeedErrorPlaceholder();
    }
    final items = _foundFeedItems ?? [];
    if (items.isEmpty) {
      return _buildFeedEmptyPlaceholder(
        icon: Icons.inventory_2_outlined,
        message: 'No found item reports yet',
        color: Colors.orange,
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildFeedThumbnailCard(
            feedItem: items[index],
            reportType: 'found',
          );
        },
      ),
    );
  }

  // ==================== FEED THUMBNAIL CARD ====================
  Widget _buildFeedThumbnailCard({
    required _FeedItem feedItem,
    required String reportType, // 'lost' or 'found'
  }) {
    final isLost = reportType == 'lost';
    final Color accentColor = isLost ? Colors.blue.shade600 : Colors.orange.shade600;
    final Color bgColor = isLost ? Colors.blue.shade50 : Colors.orange.shade50;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          if (isLost) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LostItemReportPage(reportId: feedItem.reportId),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoundItemReportPage(reportId: feedItem.reportId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thumbnail image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 160,
                  height: 120,
                  child: feedItem.thumbnailBytes != null
                      ? Image.memory(
                    feedItem.thumbnailBytes!,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Icon(
                        isLost ? Icons.search_off : Icons.inventory_2_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),

              // Info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isLost ? 'Lost' : 'Found',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Item name
                    Text(
                      feedItem.itemName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Category
                    if (feedItem.category.isNotEmpty)
                      Text(
                        feedItem.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
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

  // ==================== FEED PLACEHOLDER WIDGETS ====================
  Widget _buildFeedLoadingPlaceholder() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Container(
                      width: 160,
                      height: 120,
                      color: Colors.grey.shade200,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 14,
                          color: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 100,
                          height: 14,
                          color: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 70,
                          height: 12,
                          color: Colors.grey.shade200,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedErrorPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
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
              'Failed to load items',
              style: TextStyle(fontSize: 14, color: Colors.red.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedEmptyPlaceholder({
    required IconData icon,
    required String message,
    required MaterialColor color,
  }) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color.shade300),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: color.shade600),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                          const UserAnalyticalReportPage(),
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
  Widget _buildCustomBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0),
            _buildNavItem(Icons.search, 'Search', 1),
            const SizedBox(width: 40), // Space for FAB
            _buildNavItemWithBadge(
              Icons.notifications_outlined,
              'Notification',
              3,
              _unreadNotificationCount,
            ),
            _buildNavItem(Icons.person, 'Account', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });

        if (index == 4) {
          // Open account drawer
          _scaffoldKey.currentState?.openEndDrawer();
        } else if (index == 1) {
          // Navigate to Search & Filter page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchAndFilterPage(),
            ),
          );
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

  Widget _buildNavItemWithBadge(
      IconData icon,
      String label,
      int index,
      int badgeCount,
      ) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });

        // Navigate to notification page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserNotificationPage(),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
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
          if (badgeCount > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== ACTION CARDS ====================
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Lightweight data holder for feed thumbnails — avoids keeping full Firestore documents in memory
class _FeedItem {
  final String reportId;
  final String itemName;
  final String category;
  final Uint8List? thumbnailBytes; // Small compressed thumbnail only

  _FeedItem({
    required this.reportId,
    required this.itemName,
    required this.category,
    this.thumbnailBytes,
  });
}