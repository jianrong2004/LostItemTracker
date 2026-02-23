import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

class VoucherQRCodePage extends StatefulWidget {
  final String voucherId;
  final String voucherName;
  final String voucherDescription;
  final DateTime? expiryDate;

  const VoucherQRCodePage({
    super.key,
    required this.voucherId,
    required this.voucherName,
    required this.voucherDescription,
    this.expiryDate,
  });

  @override
  State<VoucherQRCodePage> createState() => _VoucherQRCodePageState();
}

class _VoucherQRCodePageState extends State<VoucherQRCodePage> {
  bool _isCheckingStatus = false;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startStatusListener();
  }

  /// Listen for status changes in real-time
  void _startStatusListener() {
    FirebaseFirestore.instance
        .collection('user_vouchers')
        .doc(widget.voucherId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'active';

        if (status == 'used') {
          // Voucher has been used, show success and close
          _showUsedConfirmation();
        } else if (status == 'expired') {
          // Voucher has expired
          _showExpiredMessage();
        }
      }
    });
  }

  void _showUsedConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
            const SizedBox(width: 12),
            const Expanded(child: Text('Voucher Used!')),
          ],
        ),
        content: Text(
          'Your voucher "${widget.voucherName}" has been successfully used.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close QR code page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showExpiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This voucher has expired'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.of(context).pop();
  }

  /// Download QR code to gallery using Gal
  Future<void> _downloadQRCode() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Capture QR code as image
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes == null) {
        throw Exception('Failed to capture QR code');
      }

      // Check and request permission if needed
      final hasPermission = await Gal.hasAccess();
      if (!hasPermission) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('Gallery access permission denied');
        }
      }

      // Save to gallery using Gal
      await Gal.putImageBytes(imageBytes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('QR code saved to gallery')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save QR code: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Share QR code
  Future<void> _shareQRCode() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Capture QR code as image
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes == null) {
        throw Exception('Failed to capture QR code');
      }

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/voucher_qr_${DateTime.now().millisecondsSinceEpoch}.png')
          .create();
      await file.writeAsBytes(imageBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My ${widget.voucherName} Voucher\n'
            '${widget.voucherDescription.isNotEmpty ? '${widget.voucherDescription}\n' : ''}'
            '${widget.expiryDate != null ? 'Valid until ${_formatDate(widget.expiryDate!)}' : ''}',
      );

      if (!mounted) return;

      // Clean up temp file after sharing
      try {
        await file.delete();
      } catch (_) {
        // Ignore cleanup errors
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share QR code: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Check if expired
    final bool isExpired = widget.expiryDate != null &&
        DateTime.now().isAfter(widget.expiryDate!);

    if (isExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showExpiredMessage();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher QR Code'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isSaving ? null : _shareQRCode,
            tooltip: 'Share QR Code',
          ),
          // Download button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isSaving ? null : _downloadQRCode,
            tooltip: 'Download QR Code',
          ),
        ],
      ),
      body: _isCheckingStatus
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Voucher Info Card
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
                children: [
                  Icon(
                    Icons.card_giftcard,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.voucherName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.voucherDescription.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.voucherDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // QR Code with Screenshot wrapper
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Voucher name (for screenshot)
                    Text(
                      widget.voucherName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // QR Code
                    QrImageView(
                      data: widget.voucherId,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                    ),
                    const SizedBox(height: 16),
                    // QR Code ID
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.voucherId.substring(0, 12).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    // Expiry info (for screenshot)
                    if (widget.expiryDate != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Valid until ${_formatDate(widget.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons (Download & Share)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _downloadQRCode,
                    icon: _isSaving
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.indigo.shade700,
                        ),
                      ),
                    )
                        : const Icon(Icons.download),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo.shade700,
                      side: BorderSide(color: Colors.indigo.shade700, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _shareQRCode,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Expiry Information
            if (widget.expiryDate != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Valid Until',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(widget.expiryDate!)} at ${_formatTime(widget.expiryDate!)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How to Use',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInstruction(
                    '1',
                    'Show this QR code to the merchant',
                  ),
                  const SizedBox(height: 8),
                  _buildInstruction(
                    '2',
                    'Merchant will scan the code',
                  ),
                  const SizedBox(height: 8),
                  _buildInstruction(
                    '3',
                    'Confirm usage when prompted',
                  ),
                  const SizedBox(height: 8),
                  _buildInstruction(
                    '4',
                    'Voucher will be marked as used',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Once used, this voucher cannot be reused',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}