import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class LostItemClaimPage extends StatefulWidget {
  final String claimId;

  const LostItemClaimPage({super.key, required this.claimId});

  @override
  State<LostItemClaimPage> createState() => _LostItemClaimPageState();
}

class _LostItemClaimPageState extends State<LostItemClaimPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _claimData;
  Map<String, dynamic>? _foundItemData;
  Map<String, dynamic>? _dropOffDeskData;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadClaimData();
  }

  Future<void> _loadClaimData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lost_item_claims')
          .doc(widget.claimId)
          .get();

      if (!doc.exists || !mounted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final currentUser = FirebaseAuth.instance.currentUser;

      // Load found item data
      Map<String, dynamic>? foundItemData;
      Map<String, dynamic>? dropOffDeskData;
      final foundItemReportId = data['foundItemReportId'] as String?;
      if (foundItemReportId != null) {
        try {
          final foundItemDoc = await FirebaseFirestore.instance
              .collection('found_item_reports')
              .doc(foundItemReportId)
              .get();

          if (foundItemDoc.exists) {
            foundItemData = foundItemDoc.data() as Map<String, dynamic>;

            // Load drop-off desk data
            final dropOffDeskId = foundItemData['dropOffDeskId'] as String?;
            if (dropOffDeskId != null) {
              try {
                final deskDoc = await FirebaseFirestore.instance
                    .collection('dropOffDesks')
                    .doc(dropOffDeskId)
                    .get();

                if (deskDoc.exists) {
                  dropOffDeskData = deskDoc.data() as Map<String, dynamic>;
                }
              } catch (e) {
                print('Error loading drop-off desk: $e');
              }
            }
          }
        } catch (e) {
          print('Error loading found item: $e');
        }
      }

      setState(() {
        _claimData = data;
        _foundItemData = foundItemData;
        _dropOffDeskData = dropOffDeskData;
        _isOwner = currentUser?.uid == data['userId'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading claim: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatRadius(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Details'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading claim details...'),
          ],
        ),
      )
          : _claimData == null
          ? const Center(
        child: Text('Claim not found'),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Claim Status Banner
              _buildStatusBanner(),

              const SizedBox(height: 24),

              // Claimed Item Card
              if (_foundItemData != null) _buildClaimedItemCard(),

              const SizedBox(height: 24),

              // Drop-off Desk Information
              _buildSectionTitle('Drop-off Desk'),
              const SizedBox(height: 12),
              _buildDropOffDeskSection(),

              const SizedBox(height: 24),

              // Unique Features
              _buildSectionTitle('Unique Features'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(
                  'Description',
                  _claimData!['uniqueFeatures'] ?? 'N/A',
                  isMultiline: true,
                ),
              ]),

              const SizedBox(height: 24),

              // Lost Information
              _buildSectionTitle('When & Where You Lost It'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(
                  'Lost Date & Time',
                  _formatDateTime(_claimData!['lostDateTime']),
                ),
                _buildInfoRow(
                  'Lost Location',
                  _claimData!['lostAddress'] ?? 'N/A',
                ),
                if (_claimData!['lostLatitude'] != null &&
                    _claimData!['lostLongitude'] != null)
                  _buildInfoRow(
                    'Coordinates',
                    'Lat: ${(_claimData!['lostLatitude'] as num).toStringAsFixed(5)}, Lng: ${(_claimData!['lostLongitude'] as num).toStringAsFixed(5)}',
                  ),
                if (_claimData!['lostLocationRadius'] != null)
                  _buildInfoRow(
                    'Search Radius',
                    _formatRadius(
                        (_claimData!['lostLocationRadius'] as num)
                            .toDouble()),
                  ),
                _buildInfoRow(
                  'Location Description',
                  _claimData!['lostLocationDescription'] ?? 'N/A',
                  isMultiline: true,
                ),
              ]),

              const SizedBox(height: 24),

              // Proof Photo
              _buildSectionTitle('Proof of Ownership'),
              const SizedBox(height: 12),
              _buildProofPhotoSection(),

              const SizedBox(height: 24),

              // Contact Information
              _buildSectionTitle('Contact Information'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(
                  'Phone Number',
                  _claimData!['phoneNumber'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Email',
                  _claimData!['email'] ?? 'N/A',
                ),
              ]),

              const SizedBox(height: 24),

              // Personal Information
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(
                  'Full Name',
                  _claimData!['fullName'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Campus ID',
                  _claimData!['campusId'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Identity Card Number',
                  _claimData!['identityCardNumber'] ?? 'N/A',
                ),
              ]),

              const SizedBox(height: 24),

              // Pickup Details
              _buildSectionTitle('Pickup Details'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(
                  'Pickup Date',
                  _formatDate(_claimData!['pickupDate']),
                ),
                _buildInfoRow(
                  'Pickup Time',
                  _claimData!['pickupTime'] ?? 'N/A',
                ),
              ]),

              const SizedBox(height: 24),

              // Submission Details
              _buildSectionTitle('Submission Details'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(
                  'Claim ID',
                  widget.claimId,
                ),
                _buildInfoRow(
                  'Submitted On',
                  _formatDateTime(_claimData!['createdAt']),
                ),
              ]),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final status = _claimData!['claimStatus'] as String? ?? 'pending';

    Color statusColor;
    Color statusTextColor;
    String statusText;
    IconData statusIcon;
    String statusMessage;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusTextColor = Colors.green.shade700;
        statusText = 'Claim Approved';
        statusIcon = Icons.check_circle;
        statusMessage =
        'Your claim has been approved. Please pick up your item at the scheduled time.';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusTextColor = Colors.red.shade700;
        statusText = 'Claim Rejected';
        statusIcon = Icons.cancel;
        statusMessage =
        'Your claim has been rejected. Please contact support for more information.';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusTextColor = Colors.orange.shade700;
        statusText = 'Pending Verification';
        statusIcon = Icons.pending;
        statusMessage =
        'Your claim is being reviewed. We will notify you once the verification is complete.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: statusTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimedItemCard() {
    Uint8List? photoBytes;
    final photoBytesData = _foundItemData!['photoBytes'];
    if (photoBytesData != null) {
      if (photoBytesData is Uint8List) {
        photoBytes = photoBytesData;
      } else if (photoBytesData is Blob) {
        photoBytes = photoBytesData.bytes;
      } else if (photoBytesData is List) {
        photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Claimed Item'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.shade200,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (photoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photoBytes,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey.shade400,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _foundItemData!['itemName'] ?? 'Unknown Item',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _foundItemData!['category'] ?? 'Unknown Category',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProofPhotoSection() {
    Uint8List? photoBytes;
    final photoBytesData = _claimData!['proofPhotoBytes'];
    if (photoBytesData != null) {
      if (photoBytesData is Uint8List) {
        photoBytes = photoBytesData;
      } else if (photoBytesData is Blob) {
        photoBytes = photoBytesData.bytes;
      } else if (photoBytesData is List) {
        photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
      }
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: photoBytes != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            photoBytes,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        )
            : Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No proof photo provided',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDropOffDeskColor() {
    if (_dropOffDeskData == null) return Colors.deepPurple.shade700;

    try {
      final colorHex = _dropOffDeskData!['colorHex'] as String? ?? '#3F51B5';
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.deepPurple.shade700;
    }
  }

  Widget _buildDropOffDeskSection() {
    if (_dropOffDeskData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Drop-off desk information not available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final deskColor = _getDropOffDeskColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: deskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: deskColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: deskColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.store,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dropOffDeskData!['name'] ?? 'Unknown Desk',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dropOffDeskData!['description'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _dropOffDeskData!['operatingHours'] ?? 'N/A',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.phone,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                _dropOffDeskData!['contact'] ?? 'N/A',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMMM dd, yyyy HH:mm').format(timestamp.toDate());
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMMM dd, yyyy').format(timestamp.toDate());
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }
}