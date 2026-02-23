import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_voucher_page.dart';

class UserRewardPage extends StatefulWidget {
  const UserRewardPage({super.key});

  @override
  State<UserRewardPage> createState() => _UserRewardPageState();
}

class _UserRewardPageState extends State<UserRewardPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isCalculatingPoints = false;

  @override
  void initState() {
    super.initState();
    _calculateAndAwardPoints();
  }

  /// Scan Firestore for unrewarded activities and award points automatically
  Future<void> _calculateAndAwardPoints() async {
    if (_currentUser == null) return;

    setState(() {
      _isCalculatingPoints = true;
    });

    try {
      final userId = _currentUser!.uid;

      // 1. Award points for submitted lost item reports
      await _awardPointsForLostItems(userId);

      // 2. Award points for submitted found item reports
      await _awardPointsForFoundItems(userId);

      // 3. Award points for claimed found items
      await _awardPointsForClaimedItems(userId);

      // 4. Award points for user feedback
      await _awardPointsForFeedback(userId);

    } catch (e) {
      print('Error calculating points: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingPoints = false;
        });
      }
    }
  }

  /// Award +5 points for each submitted lost item report
  Future<void> _awardPointsForLostItems(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('lost_item_reports')
        .where('userId', isEqualTo: userId)
        .where('reportStatus', isEqualTo: 'submitted')
        .where('pointsAwarded', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      try {
        await RewardService.addPointsForEvent(
          userId: userId,
          pointsDelta: 5,
          title: 'Lost item reported',
          description: 'You reported a lost item: ${doc.data()['itemName'] ?? 'Item'}',
          type: 'lost_item_reported',
          relatedId: doc.id,
        );

        // Mark as awarded to prevent double-counting
        await doc.reference.update({'pointsAwarded': true});
      } catch (e) {
        print('Error awarding points for lost item ${doc.id}: $e');
      }
    }
  }

  /// Award +10 points for each submitted found item report
  Future<void> _awardPointsForFoundItems(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('found_item_reports')
        .where('userId', isEqualTo: userId)
        .where('reportStatus', isEqualTo: 'submitted')
        .where('pointsAwarded', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      try {
        await RewardService.addPointsForEvent(
          userId: userId,
          pointsDelta: 10,
          title: 'Found item reported',
          description: 'You reported a found item: ${doc.data()['itemName'] ?? 'Item'}',
          type: 'found_item_reported',
          relatedId: doc.id,
        );

        // Mark as awarded to prevent double-counting
        await doc.reference.update({'pointsAwarded': true});
      } catch (e) {
        print('Error awarding points for found item ${doc.id}: $e');
      }
    }
  }

  /// Award +30 points for each claimed found item (successful return)
  Future<void> _awardPointsForClaimedItems(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('found_item_reports')
        .where('userId', isEqualTo: userId)
        .where('itemReturnStatus', isEqualTo: 'claimed')
        .where('claimPointsAwarded', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      try {
        await RewardService.addPointsForEvent(
          userId: userId,
          pointsDelta: 30,
          title: 'Item successfully returned',
          description: 'Your found item was claimed: ${doc.data()['itemName'] ?? 'Item'}',
          type: 'item_claimed_success',
          relatedId: doc.id,
        );

        // Mark as awarded to prevent double-counting
        await doc.reference.update({'claimPointsAwarded': true});
      } catch (e) {
        print('Error awarding points for claimed item ${doc.id}: $e');
      }
    }
  }

  /// Award +3 points for each user feedback submission
  Future<void> _awardPointsForFeedback(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('user_feedback')
        .where('userId', isEqualTo: userId)
        .where('pointsAwarded', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      try {
        await RewardService.addPointsForEvent(
          userId: userId,
          pointsDelta: 3,
          title: 'Feedback submitted',
          description: 'Thank you for your feedback: ${doc.data()['category'] ?? 'Feedback'}',
          type: 'feedback_submitted',
          relatedId: doc.id,
        );

        // Mark as awarded to prevent double-counting
        await doc.reference.update({'pointsAwarded': true});
      } catch (e) {
        print('Error awarding points for feedback ${doc.id}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rewards'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to view your rewards'),
        ),
      );
    }

    final String userId = _currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_isCalculatingPoints)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _calculateAndAwardPoints();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Points calculation info banner
              if (_isCalculatingPoints)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Calculating your points from activities...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildPointsSection(userId),
              const SizedBox(height: 20),

              // Points earning guide
              _buildPointsGuideSection(),
              const SizedBox(height: 20),

              _buildRecentActivitySection(userId),
              const SizedBox(height: 20),
              _buildBadgesSection(userId),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserVoucherPage(),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.card_giftcard,
                    color: Colors.indigo.shade700,
                  ),
                  label: Text(
                    'My Vouchers & Store',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.indigo.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== POINTS EARNING GUIDE ====================
  Widget _buildPointsGuideSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 10),
              Text(
                'How to Earn Points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPointGuideRow(Icons.search_off, 'Report a lost item', '+5 pts'),
          const SizedBox(height: 8),
          _buildPointGuideRow(Icons.inventory_2, 'Report a found item', '+10 pts'),
          const SizedBox(height: 8),
          _buildPointGuideRow(Icons.check_circle, 'Item successfully returned', '+30 pts'),
          const SizedBox(height: 8),
          _buildPointGuideRow(Icons.feedback, 'Submit feedback', '+3 pts'),
        ],
      ),
    );
  }

  Widget _buildPointGuideRow(IconData icon, String text, String points) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          points,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
      ],
    );
  }

  // ==================== YOUR POINTS ====================
  Widget _buildPointsSection(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_rewards')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        int totalPoints = 0;
        int lifetimePoints = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
          lifetimePoints = (data['lifetimePoints'] as num?)?.toInt() ?? totalPoints;
        }

        return Container(
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
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.shade100,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.stars,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Your Points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$totalPoints',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      'pts',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Lifetime points: $lifetimePoints',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _buildNextBadgeHint(lifetimePoints),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildNextBadgeHint(int lifetimePoints) {
    const badgeThresholds = [
      50,
      100,
      300,
      600,
    ];
    for (final threshold in badgeThresholds) {
      if (lifetimePoints < threshold) {
        final diff = threshold - lifetimePoints;
        return 'Earn $diff more pts to unlock next badge.';
      }
    }
    return 'You have unlocked all available badges. Great job!';
  }

  // ==================== RECENT ACTIVITY ====================
  Widget _buildRecentActivitySection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: Colors.grey.shade800),
            const SizedBox(width: 8),
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'See how you earned or spent your points.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user_reward_activities')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildSmallErrorCard('Failed to load recent activity');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No reward activities yet. Start by reporting lost or found items!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final String title = data['title'] as String? ?? 'Activity';
                  final String description =
                      data['description'] as String? ?? '';
                  final int delta =
                      (data['pointsDelta'] as num?)?.toInt() ?? 0;
                  final Timestamp? ts = data['createdAt'] as Timestamp?;
                  final DateTime? createdAt = ts?.toDate();

                  final bool isPositive = delta >= 0;
                  final Color deltaColor =
                  isPositive ? Colors.green.shade700 : Colors.red.shade700;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                      isPositive ? Colors.green.shade50 : Colors.red.shade50,
                      child: Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        color: deltaColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (createdAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              _formatShortDateTime(createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Text(
                      '${isPositive ? '+' : ''}$delta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: deltaColor,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatShortDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} d ago';
    } else {
      return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)}';
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  // ==================== BADGES ====================
  Widget _buildBadgesSection(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_rewards')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        int lifetimePoints = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          lifetimePoints =
              (data['lifetimePoints'] as num?)?.toInt() ?? lifetimePoints;
        }

        final badges = _buildBadgeDefinitions();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.grey.shade800),
                const SizedBox(width: 8),
                Text(
                  'Badges Earned',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock badges by earning more lifetime points.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            badges.isEmpty
                ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No badges defined yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            )
                : SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: badges.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  final bool isUnlocked =
                      lifetimePoints >= badge.requiredPoints;
                  return _buildBadgeCard(badge, isUnlocked);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<_BadgeDefinition> _buildBadgeDefinitions() {
    return const [
      _BadgeDefinition(
        id: 'starter',
        name: 'Starter',
        description: 'Earn your first 50 points.',
        requiredPoints: 50,
        icon: Icons.emoji_events,
      ),
      _BadgeDefinition(
        id: 'helper',
        name: 'Helpful Finder',
        description: 'Reach 100 lifetime points.',
        requiredPoints: 100,
        icon: Icons.volunteer_activism,
      ),
      _BadgeDefinition(
        id: 'guardian',
        name: 'Campus Guardian',
        description: 'Reach 300 lifetime points.',
        requiredPoints: 300,
        icon: Icons.shield,
      ),
      _BadgeDefinition(
        id: 'legend',
        name: 'Legend',
        description: 'Reach 600 lifetime points.',
        requiredPoints: 600,
        icon: Icons.workspace_premium,
      ),
    ];
  }

  Widget _buildBadgeCard(_BadgeDefinition badge, bool isUnlocked) {
    final Color activeColor =
    isUnlocked ? Colors.indigo.shade700 : Colors.grey.shade400;
    final Color bgColor =
    isUnlocked ? Colors.indigo.shade50 : Colors.grey.shade100;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? Colors.indigo.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 32,
            color: activeColor,
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: activeColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            isUnlocked ? 'Unlocked' : 'Need ${badge.requiredPoints} pts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? Colors.green.shade700 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum RewardServiceErrorCode {
  notEnoughPoints,
  invalidVoucher,
  unknown,
}

class RewardServiceException implements Exception {
  final RewardServiceErrorCode code;
  final String message;

  RewardServiceException(this.code, this.message);

  @override
  String toString() => message;
}

/// Centralised Firestore helper for reward-related updates.
///
/// Collections used:
/// - user_rewards (doc: userId)        -> totalPoints, lifetimePoints, createdAt, updatedAt
/// - user_reward_activities (docs)     -> userId, title, description, pointsDelta, type, relatedId, createdAt
/// - user_vouchers (docs)             -> userId, voucherId, voucherName, voucherDescription, requiredPoints, status, redeemedAt
/// - vouchers (docs, catalog)         -> name, description, requiredPoints, isActive, ... (defined elsewhere)
class RewardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Redeem a voucher for the given user:
  /// - Decrease user_rewards.totalPoints
  /// - Insert a user_vouchers document
  /// - Insert a user_reward_activities document (negative pointsDelta)
  static Future<void> redeemVoucher({
    required String userId,
    required DocumentSnapshot voucherDoc,
  }) async {
    final Map<String, dynamic> voucherData =
        voucherDoc.data() as Map<String, dynamic>? ?? {};

    final int requiredPoints =
        (voucherData['requiredPoints'] as num?)?.toInt() ?? 0;
    if (requiredPoints <= 0) {
      throw RewardServiceException(
        RewardServiceErrorCode.invalidVoucher,
        'Invalid voucher configuration.',
      );
    }

    final String name = voucherData['name'] as String? ?? 'Voucher';
    final String description =
        voucherData['description'] as String? ?? '';

    final DocumentReference userRewardsRef =
    _firestore.collection('user_rewards').doc(userId);
    final DocumentReference userVoucherRef =
    _firestore.collection('user_vouchers').doc();
    final DocumentReference activityRef =
    _firestore.collection('user_reward_activities').doc();

    await _firestore.runTransaction((transaction) async {
      final userRewardsSnap = await transaction.get(userRewardsRef);

      int currentPoints = 0;
      int lifetimePoints = 0;

      if (userRewardsSnap.exists) {
        final data =
            userRewardsSnap.data() as Map<String, dynamic>? ?? {};
        currentPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
        lifetimePoints =
            (data['lifetimePoints'] as num?)?.toInt() ?? currentPoints;
      }

      if (currentPoints < requiredPoints) {
        throw RewardServiceException(
          RewardServiceErrorCode.notEnoughPoints,
          'Not enough points.',
        );
      }

      final int newTotalPoints = currentPoints - requiredPoints;

      // Update/create user_rewards
      final Object? existingData = userRewardsSnap.data();
      final Object? existingCreatedAt = existingData is Map<String, dynamic>
          ? existingData['createdAt']
          : null;

      transaction.set(
        userRewardsRef,
        {
          'totalPoints': newTotalPoints,
          'lifetimePoints': lifetimePoints,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt':
          userRewardsSnap.exists && existingCreatedAt != null
              ? existingCreatedAt
              : FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Add user_vouchers record
      transaction.set(userVoucherRef, {
        'userId': userId,
        'voucherId': voucherDoc.id,
        'voucherName': name,
        'voucherDescription': description,
        'requiredPoints': requiredPoints,
        'status': 'active',
        'redeemedAt': FieldValue.serverTimestamp(),
      });

      // Add negative activity record
      transaction.set(activityRef, {
        'userId': userId,
        'title': 'Voucher redeemed',
        'description': 'Redeemed "$name" for $requiredPoints points.',
        'pointsDelta': -requiredPoints,
        'type': 'voucher_redeemed',
        'relatedId': voucherDoc.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Generic helper to add (or subtract) points for any event, and log activity.
  ///
  /// Example usage (elsewhere in the app, e.g. when a found item is claimed):
  /// ```dart
  /// await RewardService.addPointsForEvent(
  ///   userId: userIdOfFinder,
  ///   pointsDelta: 20,
  ///   title: 'Found item claimed',
  ///   description: 'Your found item report was successfully claimed.',
  ///   type: 'found_item_claimed',
  ///   relatedId: foundItemReportId,
  /// );
  /// ```
  static Future<void> addPointsForEvent({
    required String userId,
    required int pointsDelta,
    required String title,
    required String description,
    required String type,
    String? relatedId,
  }) async {
    final DocumentReference userRewardsRef =
    _firestore.collection('user_rewards').doc(userId);
    final DocumentReference activityRef =
    _firestore.collection('user_reward_activities').doc();

    await _firestore.runTransaction((transaction) async {
      final userRewardsSnap = await transaction.get(userRewardsRef);

      int currentPoints = 0;
      int lifetimePoints = 0;

      if (userRewardsSnap.exists) {
        final data =
            userRewardsSnap.data() as Map<String, dynamic>? ?? {};
        currentPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
        lifetimePoints =
            (data['lifetimePoints'] as num?)?.toInt() ?? currentPoints;
      }

      final int newTotalPoints = currentPoints + pointsDelta;
      final int newLifetimePoints =
          lifetimePoints + (pointsDelta > 0 ? pointsDelta : 0);

      final Object? existingData = userRewardsSnap.data();
      final Object? existingCreatedAt = existingData is Map<String, dynamic>
          ? existingData['createdAt']
          : null;

      transaction.set(
        userRewardsRef,
        {
          'totalPoints': newTotalPoints.clamp(0, 1 << 31),
          'lifetimePoints': newLifetimePoints.clamp(0, 1 << 31),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt':
          userRewardsSnap.exists && existingCreatedAt != null
              ? existingCreatedAt
              : FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(activityRef, {
        'userId': userId,
        'title': title,
        'description': description,
        'pointsDelta': pointsDelta,
        'type': type,
        'relatedId': relatedId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class _BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final int requiredPoints;
  final IconData icon;

  const _BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.requiredPoints,
    required this.icon,
  });
}