import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'lost_item_report.dart';
import 'found_item_report.dart';
import 'lost_item_claim.dart';

class _HistoryItem {
  final String reportId;
  final String itemName;
  final String category;
  final String itemReturnStatus;
  final DateTime? createdAt;
  final Uint8List? thumbnailBytes;

  _HistoryItem({
    required this.reportId,
    required this.itemName,
    required this.category,
    required this.itemReturnStatus,
    required this.createdAt,
    this.thumbnailBytes,
  });
}

class ReportHistoryPage extends StatefulWidget {
  const ReportHistoryPage({super.key});

  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  String _selectedTab = 'lost';

  // All data loaded at once for each tab
  List<_HistoryItem>? _lostReports;
  List<_HistoryItem>? _foundReports;
  List<_HistoryItem>? _claimReports;

  bool _isLoadingLost = false;
  bool _isLoadingFound = false;
  bool _isLoadingClaims = false;

  bool _lostError = false;
  bool _foundError = false;
  bool _claimsError = false;

  // Pagination - only for display
  int _lostCurrentPage = 1;
  int _foundCurrentPage = 1;
  int _claimsCurrentPage = 1;
  final int _itemsPerPage = 10;

  // Total pages calculation
  int get _lostTotalPages {
    if (_lostReports == null || _lostReports!.isEmpty) return 0;
    return ((_lostReports!.length - 1) ~/ _itemsPerPage) + 1;
  }

  int get _foundTotalPages {
    if (_foundReports == null || _foundReports!.isEmpty) return 0;
    return ((_foundReports!.length - 1) ~/ _itemsPerPage) + 1;
  }

  int get _claimsTotalPages {
    if (_claimReports == null || _claimReports!.isEmpty) return 0;
    return ((_claimReports!.length - 1) ~/ _itemsPerPage) + 1;
  }

  // Paginated results for display only
  List<_HistoryItem> get _lostPaginatedResults {
    if (_lostReports == null) return [];
    final startIndex = (_lostCurrentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _lostReports!.length);
    if (startIndex >= _lostReports!.length) return [];
    return _lostReports!.sublist(startIndex, endIndex);
  }

  List<_HistoryItem> get _foundPaginatedResults {
    if (_foundReports == null) return [];
    final startIndex = (_foundCurrentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _foundReports!.length);
    if (startIndex >= _foundReports!.length) return [];
    return _foundReports!.sublist(startIndex, endIndex);
  }

  List<_HistoryItem> get _claimsPaginatedResults {
    if (_claimReports == null) return [];
    final startIndex = (_claimsCurrentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _claimReports!.length);
    if (startIndex >= _claimReports!.length) return [];
    return _claimReports!.sublist(startIndex, endIndex);
  }

  @override
  void initState() {
    super.initState();
    _loadLostReports();
  }

  Future<void> _loadLostReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() { _isLoadingLost = true; _lostError = false; });

    try {
      // Load all lost reports at once
      final snapshot = await FirebaseFirestore.instance
          .collection('lost_item_reports')
          .where('userId', isEqualTo: user.uid)
          .where('reportStatus', isEqualTo: 'submitted')
          .orderBy('createdAt', descending: true)
          .get();

      final List<_HistoryItem> items = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        Uint8List? thumbnailBytes;
        final thumbnailBytesData = data['thumbnailBytes'];
        if (thumbnailBytesData != null) {
          if (thumbnailBytesData is Uint8List) {
            thumbnailBytes = thumbnailBytesData;
          } else if (thumbnailBytesData is Blob) {
            thumbnailBytes = thumbnailBytesData.bytes;
          } else if (thumbnailBytesData is List) {
            thumbnailBytes = Uint8List.fromList(List<int>.from(thumbnailBytesData));
          }
        }

        items.add(_HistoryItem(
          reportId: doc.id,
          itemName: data['itemName'] ?? 'Untitled',
          category: data['category'] ?? 'Uncategorized',
          itemReturnStatus: data['itemReturnStatus'] ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          thumbnailBytes: thumbnailBytes,
        ));
      }

      if (mounted) setState(() {
        _lostReports = items;
        _isLoadingLost = false;
        _lostCurrentPage = 1;
      });
    } catch (e) {
      if (mounted) setState(() {
        _lostError = true;
        _isLoadingLost = false;
      });
    }
  }

  Future<void> _loadFoundReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() { _isLoadingFound = true; _foundError = false; });

    try {
      // Load all found reports at once
      final snapshot = await FirebaseFirestore.instance
          .collection('found_item_reports')
          .where('userId', isEqualTo: user.uid)
          .where('reportStatus', isEqualTo: 'submitted')
          .orderBy('createdAt', descending: true)
          .get();

      final List<_HistoryItem> items = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        Uint8List? thumbnailBytes;
        final thumbnailBytesData = data['thumbnailBytes'];
        if (thumbnailBytesData != null) {
          if (thumbnailBytesData is Uint8List) {
            thumbnailBytes = thumbnailBytesData;
          } else if (thumbnailBytesData is Blob) {
            thumbnailBytes = thumbnailBytesData.bytes;
          } else if (thumbnailBytesData is List) {
            thumbnailBytes = Uint8List.fromList(List<int>.from(thumbnailBytesData));
          }
        }

        items.add(_HistoryItem(
          reportId: doc.id,
          itemName: data['itemName'] ?? 'Untitled',
          category: data['category'] ?? 'Uncategorized',
          itemReturnStatus: data['itemReturnStatus'] ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          thumbnailBytes: thumbnailBytes,
        ));
      }

      if (mounted) setState(() {
        _foundReports = items;
        _isLoadingFound = false;
        _foundCurrentPage = 1;
      });
    } catch (e) {
      if (mounted) setState(() {
        _foundError = true;
        _isLoadingFound = false;
      });
    }
  }

  Future<void> _loadClaimReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() { _isLoadingClaims = true; _claimsError = false; });

    try {
      // Load all claim reports at once
      final snapshot = await FirebaseFirestore.instance
          .collection('lost_item_claims')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final List<_HistoryItem> items = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // For claims, get thumbnail from the associated found report
        Uint8List? thumbnailBytes;
        String itemName = 'Claimed Item';
        String category = 'Unknown';

        try {
          final foundItemReportId = data['foundItemReportId'] as String?;
          if (foundItemReportId != null) {
            final foundDoc = await FirebaseFirestore.instance
                .collection('found_item_reports')
                .doc(foundItemReportId)
                .get();

            if (foundDoc.exists) {
              final foundData = foundDoc.data()!;
              itemName = foundData['itemName'] ?? itemName;
              category = foundData['category'] ?? category;

              final thumbnailBytesData = foundData['thumbnailBytes'];
              if (thumbnailBytesData != null) {
                if (thumbnailBytesData is Uint8List) {
                  thumbnailBytes = thumbnailBytesData;
                } else if (thumbnailBytesData is Blob) {
                  thumbnailBytes = thumbnailBytesData.bytes;
                } else if (thumbnailBytesData is List) {
                  thumbnailBytes = Uint8List.fromList(List<int>.from(thumbnailBytesData));
                }
              }
            }
          }
        } catch (e) {
          print('Error loading found item info: $e');
        }

        items.add(_HistoryItem(
          reportId: doc.id,
          itemName: itemName,
          category: category,
          itemReturnStatus: data['claimStatus'] ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          thumbnailBytes: thumbnailBytes,
        ));
      }

      if (mounted) setState(() {
        _claimReports = items;
        _isLoadingClaims = false;
        _claimsCurrentPage = 1;
      });
    } catch (e) {
      if (mounted) setState(() {
        _claimsError = true;
        _isLoadingClaims = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report History'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Lost Report',
                    isSelected: _selectedTab == 'lost',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'lost';
                      });
                      if (_lostReports == null) {
                        _loadLostReports();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Found Report',
                    isSelected: _selectedTab == 'found',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'found';
                      });
                      if (_foundReports == null) {
                        _loadFoundReports();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Claims',
                    isSelected: _selectedTab == 'claims',
                    onTap: () {
                      setState(() {
                        _selectedTab = 'claims';
                      });
                      if (_claimReports == null) {
                        _loadClaimReports();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTab == 'lost'
                ? _buildLostItemReportList()
                : _selectedTab == 'found'
                ? _buildFoundItemReportList()
                : _buildLostItemClaimList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildLostItemReportList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your report history'),
      );
    }

    if (_isLoadingLost) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lostError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading reports',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLostReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final allReports = _lostReports ?? [];
    final reports = _lostPaginatedResults;
    final totalReports = allReports.length;

    if (totalReports == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No submitted lost item reports',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (totalReports > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$totalReports report${totalReports == 1 ? '' : 's'} (Page $_lostCurrentPage of $_lostTotalPages)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadLostReports,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return _buildReportCard(
                  context: context,
                  item: reports[index],
                  reportType: 'lost',
                );
              },
            ),
          ),
        ),
        if (_lostTotalPages > 1) _buildPagination('lost'),
      ],
    );
  }

  Widget _buildFoundItemReportList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your report history'),
      );
    }

    if (_isLoadingFound) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_foundError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading reports',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFoundReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final allReports = _foundReports ?? [];
    final reports = _foundPaginatedResults;
    final totalReports = allReports.length;

    if (totalReports == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No submitted found item reports',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (totalReports > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$totalReports report${totalReports == 1 ? '' : 's'} (Page $_foundCurrentPage of $_foundTotalPages)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFoundReports,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return _buildReportCard(
                  context: context,
                  item: reports[index],
                  reportType: 'found',
                );
              },
            ),
          ),
        ),
        if (_foundTotalPages > 1) _buildPagination('found'),
      ],
    );
  }

  Widget _buildLostItemClaimList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your claims'),
      );
    }

    if (_isLoadingClaims) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_claimsError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading claims',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadClaimReports,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final allClaims = _claimReports ?? [];
    final claims = _claimsPaginatedResults;
    final totalClaims = allClaims.length;

    if (totalClaims == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No submitted claims',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (totalClaims > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$totalClaims claim${totalClaims == 1 ? '' : 's'} (Page $_claimsCurrentPage of $_claimsTotalPages)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadClaimReports,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: claims.length,
              itemBuilder: (context, index) {
                return _buildReportCard(
                  context: context,
                  item: claims[index],
                  reportType: 'claims',
                );
              },
            ),
          ),
        ),
        if (_claimsTotalPages > 1) _buildPagination('claims'),
      ],
    );
  }

  Widget _buildPagination(String type) {
    int currentPage, totalPages;
    void Function(int) onPageChange;

    if (type == 'lost') {
      currentPage = _lostCurrentPage;
      totalPages = _lostTotalPages;
      onPageChange = (page) => setState(() => _lostCurrentPage = page);
    } else if (type == 'found') {
      currentPage = _foundCurrentPage;
      totalPages = _foundTotalPages;
      onPageChange = (page) => setState(() => _foundCurrentPage = page);
    } else {
      currentPage = _claimsCurrentPage;
      totalPages = _claimsTotalPages;
      onPageChange = (page) => setState(() => _claimsCurrentPage = page);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
            color: Colors.indigo.shade700,
          ),
          const SizedBox(width: 8),
          ..._buildPageNumbers(currentPage, totalPages, onPageChange),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
            color: Colors.indigo.shade700,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int currentPage, int totalPages, void Function(int) onPageChange) {
    List<Widget> pageButtons = [];
    int start = (currentPage - 2).clamp(1, totalPages);
    int end = (currentPage + 2).clamp(1, totalPages);

    if (start > 1) {
      pageButtons.add(_buildPageButton(1, currentPage, onPageChange));
      if (start > 2) {
        pageButtons.add(Text('...', style: TextStyle(color: Colors.grey.shade600)));
      }
    }

    for (int i = start; i <= end; i++) {
      pageButtons.add(_buildPageButton(i, currentPage, onPageChange));
    }

    if (end < totalPages) {
      if (end < totalPages - 1) {
        pageButtons.add(Text('...', style: TextStyle(color: Colors.grey.shade600)));
      }
      pageButtons.add(_buildPageButton(totalPages, currentPage, onPageChange));
    }

    return pageButtons;
  }

  Widget _buildPageButton(int page, int currentPage, void Function(int) onPageChange) {
    final isCurrentPage = page == currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => onPageChange(page),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrentPage ? Colors.indigo.shade700 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrentPage ? Colors.indigo.shade700 : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              '$page',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrentPage ? FontWeight.w600 : FontWeight.normal,
                color: isCurrentPage ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required _HistoryItem item,
    required String reportType,
  }) {
    String formattedDate = 'Unknown date';
    if (item.createdAt != null) {
      formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(item.createdAt!);
    }

    Color statusColor;
    Color statusTextColor;
    String statusText;

    if (reportType == 'claims') {
      switch (item.itemReturnStatus) {
        case 'approved':
          statusColor = Colors.green;
          statusTextColor = Colors.green.shade700;
          statusText = 'Approved';
          break;
        case 'rejected':
          statusColor = Colors.red;
          statusTextColor = Colors.red.shade700;
          statusText = 'Rejected';
          break;
        case 'pending':
        default:
          statusColor = Colors.orange;
          statusTextColor = Colors.orange.shade700;
          statusText = 'Pending';
          break;
      }
    } else {
      switch (item.itemReturnStatus) {
        case 'returned':
          statusColor = Colors.green;
          statusTextColor = Colors.green.shade700;
          statusText = 'Returned';
          break;
        case 'claimed':
          statusColor = Colors.green;
          statusTextColor = Colors.green.shade700;
          statusText = 'Claimed';
          break;
        case 'pending':
        default:
          statusColor = Colors.orange;
          statusTextColor = Colors.orange.shade700;
          statusText = 'Pending';
          break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _openReportDetails(item.reportId, reportType);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.thumbnailBytes != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    item.thumbnailBytes!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Icon(
                  Icons.image_not_supported,
                  color: Colors.grey.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: reportType == 'lost'
                                ? Colors.blue.shade50
                                : reportType == 'found'
                                ? Colors.orange.shade50
                                : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: reportType == 'lost'
                                  ? Colors.blue.shade700
                                  : reportType == 'found'
                                  ? Colors.orange.shade700
                                  : Colors.purple.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (reportType != 'claims')
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () {
                    _confirmDeleteReport(item.reportId, reportType, item.itemName);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReportDetails(String reportId, String reportType) async {
    if (reportType == 'lost') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LostItemReportPage(reportId: reportId),
        ),
      );
    } else if (reportType == 'found') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoundItemReportPage(reportId: reportId),
        ),
      );
    } else if (reportType == 'claims') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LostItemClaimPage(claimId: reportId),
        ),
      );
    }
  }

  Future<void> _confirmDeleteReport(
      String reportId,
      String reportType,
      String itemName,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: Text(
            'Are you sure you want to delete the report for "$itemName"? This action cannot be undone.',
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

    if (confirmed == true) {
      await _deleteReport(reportId, reportType);
    }
  }

  Future<void> _deleteReport(String reportId, String reportType) async {
    try {
      final collection = reportType == 'lost'
          ? 'lost_item_reports'
          : 'found_item_reports';

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(reportId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Reload the appropriate list
        if (reportType == 'lost') {
          await _loadLostReports();
        } else {
          await _loadFoundReports();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting report: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}