import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'found_item_reporting_page.dart';

class LostItemReportPage extends StatefulWidget {
  final String reportId;

  const LostItemReportPage({super.key, required this.reportId});

  @override
  State<LostItemReportPage> createState() => _LostItemReportPageState();
}

class _LostItemReportPageState extends State<LostItemReportPage> {
  bool _isLoading = true;
  bool _isDeleting = false;
  Map<String, dynamic>? _reportData;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .doc(widget.reportId)
          .get();

      if (!doc.exists || !mounted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final currentUser = FirebaseAuth.instance.currentUser;

      setState(() {
        _reportData = data;
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
            content: Text('Error loading report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: const Text(
            'Are you sure you want to delete this report? This action cannot be undone.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .doc(widget.reportId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(); // Go back to previous page
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting report: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleFoundThisItem() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FoundItemReportingPage(),
      ),
    );
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
        title: const Text('Lost Item Report'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading report...'),
          ],
        ),
      )
          : _reportData == null
          ? const Center(
        child: Text('Report not found'),
      )
          : Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  _buildPhotoSection(),

                  const SizedBox(height: 24),

                  // Item Information
                  _buildSectionTitle('Item Information'),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow('Category', _reportData!['category'] ?? 'N/A'),
                    _buildInfoRow('Item Name', _reportData!['itemName'] ?? 'N/A'),
                    _buildInfoRow(
                      'Description',
                      _reportData!['itemDescription'] ?? 'N/A',
                      isMultiline: true,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Location Information
                  _buildSectionTitle('Location Information'),
                  const SizedBox(height: 12),
                  _buildLocationSection(),

                  const SizedBox(height: 24),

                  // Date & Time
                  _buildSectionTitle('Date & Time'),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow('Lost On', _formatDateTime(_reportData!['lostDateTime'])),
                  ]),

                  const SizedBox(height: 24),

                  // Status
                  _buildSectionTitle('Status'),
                  const SizedBox(height: 12),
                  _buildStatusSection(),

                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),

          // Bottom action button
          if (!_isDeleting)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: _isOwner
                    ? _buildDeleteButton()
                    : _buildFoundThisItemButton(),
              ),
            ),

          // Deleting overlay
          if (_isDeleting)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    // Convert photoBytes from List<dynamic> to Uint8List
    Uint8List? photoBytes;
    final photoBytesData = _reportData!['photoBytes'];
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
                  'No photo available',
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

  Widget _buildLocationSection() {
    final latitude = (_reportData!['latitude'] as num?)?.toDouble();
    final longitude = (_reportData!['longitude'] as num?)?.toDouble();
    final radius = (_reportData!['locationRadius'] as num?)?.toDouble();
    final address = _reportData!['address'] as String?;
    final locationDescription = _reportData!['locationDescription'] as String?;

    return _buildInfoCard([
      if (address != null) _buildInfoRow('Address', address),
      if (latitude != null && longitude != null)
        _buildInfoRow(
          'Coordinates',
          'Lat: ${latitude.toStringAsFixed(5)}, Lng: ${longitude.toStringAsFixed(5)}',
        ),
      if (radius != null) _buildInfoRow('Search Radius', _formatRadius(radius)),
      if (locationDescription != null)
        _buildInfoRow('Description', locationDescription, isMultiline: true),
    ]);
  }

  Widget _buildStatusSection() {
    final itemReturnStatus = _reportData!['itemReturnStatus'] as String? ?? 'pending';
    final reportStatus = _reportData!['reportStatus'] as String? ?? 'submitted';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (itemReturnStatus) {
      case 'returned':
        statusColor = Colors.green;
        statusText = 'Item Returned';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Row(
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
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  itemReturnStatus == 'returned'
                      ? 'This item has been returned to the owner'
                      : 'Waiting for someone to find this item',
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
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _deleteReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Delete Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFoundThisItemButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _handleFoundThisItem,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Found This Item',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
}