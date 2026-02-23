import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'voucher_qr_code_page.dart';

class UserVoucherPage extends StatefulWidget {
  const UserVoucherPage({super.key});

  @override
  State<UserVoucherPage> createState() => _UserVoucherPageState();
}

class _UserVoucherPageState extends State<UserVoucherPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String _selectedTab = 'my'; // 'my' or 'store'

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vouchers'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to view your vouchers'),
        ),
      );
    }

    final String userId = _currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vouchers'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: 'My Vouchers',
                      value: 'my',
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Voucher Store',
                      value: 'store',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedTab == 'my'
                ? _MyVouchersTab(userId: userId)
                : _VoucherStoreTab(userId: userId),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required String value}) {
    final bool isSelected = _selectedTab == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ==================== TAB: MY VOUCHERS ====================

class _MyVouchersTab extends StatelessWidget {
  final String userId;

  const _MyVouchersTab({required this.userId});

  /// Check if voucher is expired and update status automatically
  Future<void> _checkAndUpdateExpiredVoucher(
      String voucherId,
      DateTime expiryDate,
      String currentStatus,
      ) async {
    if (currentStatus != 'active') return;

    final now = DateTime.now();
    if (now.isAfter(expiryDate)) {
      try {
        await FirebaseFirestore.instance
            .collection('user_vouchers')
            .doc(voucherId)
            .update({'status': 'expired'});
      } catch (e) {
        print('Error updating expired voucher: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_vouchers')
          .where('userId', isEqualTo: userId)
          .orderBy('redeemedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSmallErrorCard(
              'Failed to load your vouchers: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard, color: Colors.grey.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'My Vouchers',
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
                'You have not redeemed any vouchers yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Earn points by using the app and redeem vouchers from the store.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.grey.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'My Vouchers',
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
                    'View vouchers you have redeemed. Tap to show QR code.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }

            final doc = docs[index - 1];
            final data = doc.data() as Map<String, dynamic>;
            final String voucherId = doc.id;
            final String name = data['voucherName'] as String? ?? 'Voucher';
            final String description =
                data['voucherDescription'] as String? ?? '';
            final String status = data['status'] as String? ?? 'active';
            final Timestamp? redeemedTs = data['redeemedAt'] as Timestamp?;
            final DateTime? redeemedAt = redeemedTs?.toDate();
            final Timestamp? expiryTs = data['expiryDate'] as Timestamp?;
            final DateTime? expiryDate = expiryTs?.toDate();

            // Auto-check and update expired status
            if (expiryDate != null) {
              _checkAndUpdateExpiredVoucher(voucherId, expiryDate, status);
            }

            Color statusColor;
            String statusLabel;
            IconData statusIcon;

            if (status == 'used') {
              statusColor = Colors.grey.shade600;
              statusLabel = 'Used';
              statusIcon = Icons.check_circle;
            } else if (status == 'expired') {
              statusColor = Colors.red.shade600;
              statusLabel = 'Expired';
              statusIcon = Icons.cancel;
            } else {
              statusColor = Colors.green.shade700;
              statusLabel = 'Active';
              statusIcon = Icons.check_circle_outline;
            }

            // Check if expired (real-time check)
            final bool isExpired = expiryDate != null &&
                DateTime.now().isAfter(expiryDate);

            return InkWell(
              onTap: status == 'active' && !isExpired
                  ? () {
                // Navigate to QR code page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VoucherQRCodePage(
                      voucherId: voucherId,
                      voucherName: name,
                      voucherDescription: description,
                      expiryDate: expiryDate,
                    ),
                  ),
                );
              }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: status == 'active' && !isExpired
                        ? Colors.indigo.shade200
                        : Colors.grey.shade200,
                    width: status == 'active' && !isExpired ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: status == 'active' && !isExpired
                            ? Colors.indigo.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_offer,
                        color: status == 'active' && !isExpired
                            ? Colors.indigo.shade700
                            : Colors.grey.shade400,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Expiry Date
                          if (expiryDate != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: isExpired
                                      ? Colors.red.shade600
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isExpired
                                      ? 'Expired on ${_formatDate(expiryDate)}'
                                      : 'Valid until ${_formatDate(expiryDate)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isExpired
                                        ? Colors.red.shade600
                                        : Colors.grey.shade500,
                                    fontWeight: isExpired
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          // Redeemed Date
                          if (redeemedAt != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Redeemed ${_formatShortDateTime(redeemedAt)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Tap to show QR hint
                          if (status == 'active' && !isExpired) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  size: 14,
                                  color: Colors.indigo.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap to show QR code',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.indigo.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (status == 'active' && !isExpired)
                      Icon(
                        Icons.chevron_right,
                        color: Colors.indigo.shade700,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ==================== TAB: VOUCHER STORE ====================

class _VoucherStoreTab extends StatelessWidget {
  final String userId;

  const _VoucherStoreTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vouchers')
          .where('isActive', isEqualTo: true)
          .orderBy('requiredPoints')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSmallErrorCard(
              'Failed to load vouchers: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(Icons.storefront, color: Colors.grey.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Voucher Store',
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
                'Redeem your points for campus vouchers.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'No vouchers available at the moment. Please check again later.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront, color: Colors.grey.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Voucher Store',
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
                    'Redeem your points for campus vouchers.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }

            final doc = docs[index - 1];
            final data = doc.data() as Map<String, dynamic>;
            final String name = data['name'] as String? ?? 'Voucher';
            final String description =
                data['description'] as String? ?? '';
            final int requiredPoints =
                (data['requiredPoints'] as num?)?.toInt() ?? 0;
            final int validityDays =
                (data['validityDays'] as num?)?.toInt() ?? 30;

            return _VoucherCard(
              userId: userId,
              voucherDoc: doc,
              name: name,
              description: description,
              requiredPoints: requiredPoints,
              validityDays: validityDays,
            );
          },
        );
      },
    );
  }
}

// ==================== VOUCHER CARD & SERVICE ====================

class _VoucherCard extends StatelessWidget {
  final String userId;
  final DocumentSnapshot voucherDoc;
  final String name;
  final String description;
  final int requiredPoints;
  final int validityDays;

  const _VoucherCard({
    required this.userId,
    required this.voucherDoc,
    required this.name,
    required this.description,
    required this.requiredPoints,
    required this.validityDays,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('user_rewards')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        int currentPoints = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          currentPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
        }

        final bool canRedeem = currentPoints >= requiredPoints;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_offer,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.stars,
                                size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '$requiredPoints pts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(You have $currentPoints pts)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Validity period
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Valid for $validityDays days',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canRedeem
                      ? () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Redeem Voucher'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Redeem "$name" for $requiredPoints points?'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Valid for $validityDays days from redemption',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Redeem'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;

                    try {
                      await RewardService.redeemVoucher(
                        userId: userId,
                        voucherDoc: voucherDoc,
                        validityDays: validityDays,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Voucher "$name" redeemed!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      final message = e is RewardServiceException &&
                          e.code ==
                              RewardServiceErrorCode.notEnoughPoints
                          ? 'Not enough points to redeem this voucher.'
                          : 'Failed to redeem voucher: ${e.toString()}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Redeem',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

/// Centralised Firestore helper for voucher-related updates.
class RewardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> redeemVoucher({
    required String userId,
    required DocumentSnapshot voucherDoc,
    required int validityDays,
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

    // Calculate expiry date
    final now = DateTime.now();
    final expiryDate = now.add(Duration(days: validityDays));

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

      transaction.set(userVoucherRef, {
        'userId': userId,
        'voucherId': voucherDoc.id,
        'voucherName': name,
        'voucherDescription': description,
        'requiredPoints': requiredPoints,
        'status': 'active',
        'redeemedAt': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiryDate), // Add expiry date
      });

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
}

// ==================== SHARED HELPERS ====================

Widget _buildSmallErrorCard(String message) {
  return Container(
    margin: const EdgeInsets.all(20),
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
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }
}