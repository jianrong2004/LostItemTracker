import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'select_location_map.dart';
import 'lost_item_claiming_success_page.dart';

class LostItemClaimingPage extends StatefulWidget {
  final String foundItemReportId;
  final Map<String, dynamic> foundItemData;

  const LostItemClaimingPage({
    super.key,
    required this.foundItemReportId,
    required this.foundItemData,
  });

  @override
  State<LostItemClaimingPage> createState() => _LostItemClaimingPageState();
}

class _LostItemClaimingPageState extends State<LostItemClaimingPage> {
  final _formKey = GlobalKey<FormState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Form fields
  final TextEditingController _uniqueFeaturesController = TextEditingController();
  final TextEditingController _locationDescriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _campusIdController = TextEditingController();
  final TextEditingController _identityCardController = TextEditingController();

  DateTime? _lostDateTime;
  double? _latitude;
  double? _longitude;
  double _locationRadius = 50.0;
  String? _selectedAddress;
  Uint8List? _proofPhotoBytes;
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  bool _confirmationChecked = false;

  bool _isLoadingUserData = true;
  bool _isSubmitting = false;

  // Drop-off desk information
  Map<String, dynamic>? _dropOffDeskData;
  bool _isLoadingDesk = false;
  bool _isCompressingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDropOffDeskData();
  }

  @override
  void dispose() {
    _uniqueFeaturesController.dispose();
    _locationDescriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _campusIdController.dispose();
    _identityCardController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        setState(() {
          _phoneController.text = data['phoneNumber'] ?? '';
          _emailController.text = currentUser!.email ?? '';
          _fullNameController.text = data['fullName'] ?? '';
          _campusIdController.text = data['campusId'] ?? '';
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _loadDropOffDeskData() async {
    setState(() {
      _isLoadingDesk = true;
    });

    try {
      final dropOffDeskId = widget.foundItemData['dropOffDeskId'] as String?;
      if (dropOffDeskId != null) {
        final deskDoc = await FirebaseFirestore.instance
            .collection('dropOffDesks')
            .doc(dropOffDeskId)
            .get();

        if (deskDoc.exists && mounted) {
          setState(() {
            _dropOffDeskData = deskDoc.data() as Map<String, dynamic>;
            _isLoadingDesk = false;
          });
        } else {
          setState(() {
            _isLoadingDesk = false;
          });
        }
      } else {
        setState(() {
          _isLoadingDesk = false;
        });
      }
    } catch (e) {
      print('Error loading drop-off desk: $e');
      if (mounted) {
        setState(() {
          _isLoadingDesk = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Photo Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepPurple),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
              if (_proofPhotoBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _proofPhotoBytes = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isCompressingImage = true;
        });

        final bytes = await image.readAsBytes();

        if (mounted) {
          setState(() {
            _proofPhotoBytes = bytes;
            _isCompressingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompressingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectLostDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _lostDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _selectPickupDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      setState(() {
        _pickupDate = picked;
      });
    }
  }

  Future<void> _selectPickupTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _pickupTime = picked;
      });
    }
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationMapPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialRadius: _locationRadius,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        _locationRadius = (result['radius'] as double?) ?? 50.0;
        _selectedAddress = result['address'] as String?;
      });
    }
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_lostDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select when you lost the item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please mark the location where you lost the item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_confirmationChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm that the information is accurate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Claim Submission'),
          content: const Text(
            'Are you sure you want to submit this claim? Please ensure all information is accurate.',
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
                backgroundColor: Colors.deepPurple.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final claimData = {
        'foundItemReportId': widget.foundItemReportId,
        'userId': currentUser!.uid,
        'uniqueFeatures': _uniqueFeaturesController.text.trim(),
        'lostDateTime': Timestamp.fromDate(_lostDateTime!),
        'lostLatitude': _latitude,
        'lostLongitude': _longitude,
        'lostLocationRadius': _locationRadius,
        'lostAddress': _selectedAddress ?? '',
        'lostLocationDescription': _locationDescriptionController.text.trim(),
        'proofPhotoBytes': _proofPhotoBytes,
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'campusId': _campusIdController.text.trim(),
        'identityCardNumber': _identityCardController.text.trim(),
        'pickupDate': _pickupDate != null ? Timestamp.fromDate(_pickupDate!) : null,
        'pickupTime': _pickupTime != null
            ? '${_pickupTime!.hour.toString().padLeft(2, '0')}:${_pickupTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'claimStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('lost_item_claims')
          .add(claimData);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LostItemClaimingSuccessPage(
            claimId: docRef.id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting claim: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserData) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Lost Item'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildItemCard(),
                  const SizedBox(height: 24),
                  _buildUniqueFeaturesSection(),
                  const SizedBox(height: 24),
                  _buildLostDateTimeSection(),
                  const SizedBox(height: 24),
                  _buildLostLocationSection(),
                  const SizedBox(height: 24),
                  _buildProofPhotoSection(),
                  const SizedBox(height: 24),
                  _buildContactInformationSection(),
                  const SizedBox(height: 24),
                  _buildPersonalInformationSection(),
                  const SizedBox(height: 24),
                  _buildPickupDetailsSection(),
                  const SizedBox(height: 24),
                  _buildConfirmationCheckbox(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard() {
    Uint8List? photoBytes;
    final photoBytesData = widget.foundItemData['photoBytes'];
    if (photoBytesData != null) {
      if (photoBytesData is Uint8List) {
        photoBytes = photoBytesData;
      } else if (photoBytesData is Blob) {
        photoBytes = photoBytesData.bytes;
      } else if (photoBytesData is List) {
        photoBytes = Uint8List.fromList(List<int>.from(photoBytesData));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Item You Are Claiming',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
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
                      widget.foundItemData['itemName'] ?? 'Unknown Item',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.foundItemData['category'] ?? 'Unknown Category',
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

          // Drop-off Desk Information
          const SizedBox(height: 16),
          Divider(color: Colors.blue.shade200),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                Icons.store,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Drop-off Desk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoadingDesk)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading desk information...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else if (_dropOffDeskData != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dropOffDeskData!['name'] ?? 'Unknown Desk',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                if (_dropOffDeskData!['description'] != null)
                  Text(
                    _dropOffDeskData!['description'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
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
                        _dropOffDeskData!['operatingHours'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dropOffDeskData!['contact'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              'Drop-off desk information not available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUniqueFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Describe Unique Features'),
        const SizedBox(height: 8),
        Text(
          'Describe specific features that prove this item is yours (e.g., scratches, stickers, modifications)',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _uniqueFeaturesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter unique features...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please describe unique features';
            }
            if (value.trim().length < 10) {
              return 'Please provide more detail (at least 10 characters)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLostDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('When Did You Lose It?'),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectLostDateTime,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.deepPurple.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _lostDateTime == null
                        ? 'Select date and time'
                        : '${_lostDateTime!.day}/${_lostDateTime!.month}/${_lostDateTime!.year} ${_lostDateTime!.hour.toString().padLeft(2, '0')}:${_lostDateTime!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 15,
                      color: _lostDateTime == null
                          ? Colors.grey.shade500
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLostLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Where Did You Lose It?'),
        const SizedBox(height: 12),
        Center(
          child: FractionallySizedBox(
            widthFactor: 1.0,
            child: InkWell(
              onTap: _selectLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 120,
                  maxHeight: 180,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _latitude != null && _longitude != null
                        ? Colors.deepPurple.shade50
                        : Colors.deepPurple.shade50,
                    width: 2,
                  ),
                ),
                child: _latitude != null && _longitude != null
                    ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.deepPurple.shade700,
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            _selectedAddress ?? 'Location selected',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.deepPurple.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            'Lat: ${_latitude!.toStringAsFixed(5)}, '
                                'Lng: ${_longitude!.toStringAsFixed(5)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepPurple.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_locationRadius != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.radio_button_unchecked,
                                  size: 12,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Range: ${_formatRadius(_locationRadius!)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_location,
                      size: 48,
                      color: Colors.deepPurple.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to select location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Location Description'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _locationDescriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Provide additional location details...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please provide location description';
            }
            return null;
          },
        ),
      ],
    );
  }

  String _formatRadius(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  Widget _buildProofPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('Upload Proof of Ownership'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Optional',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Upload a photo showing proof of ownership (e.g., purchase receipt, previous photo with the item)',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FractionallySizedBox(
            widthFactor: 1.0,
            child: InkWell(
              onTap: _isCompressingImage ? null : _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight = MediaQuery.of(context).size.height * 0.4;

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: maxHeight,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepPurple.shade50,
                          width: 2,
                        ),
                      ),
                      child: _isCompressingImage
                          ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Processing image...'),
                          ],
                        ),
                      )
                          : _proofPhotoBytes != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _proofPhotoBytes!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 48,
                            color: Colors.deepPurple.shade700,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to upload photo',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(Optional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepPurple.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Contact Information'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: const Icon(Icons.phone),
            hintText: 'e.g. 0123456789',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter phone number';
            }
            final trimmed = value.trim();
            // Check if contains only digits
            if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
              return 'Phone number must contain digits only';
            }
            // Check length
            if (trimmed.length != 10 && trimmed.length != 11) {
              return 'Phone number must be 10 or 11 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            prefixIcon: const Icon(Icons.email),
            hintText: 'e.g. example@email.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter email address';
            }
            final trimmed = value.trim();
            // Email regex pattern
            final emailRegex = RegExp(
              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
            );
            if (!emailRegex.hasMatch(trimmed)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPersonalInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Personal Information'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person),
            hintText: 'e.g. John Doe',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            final trimmed = value.trim();
            if (trimmed.length < 3) {
              return 'Full name must be at least 3 characters';
            }
            if (trimmed.length > 50) {
              return 'Full name must not exceed 50 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _campusIdController,
          decoration: InputDecoration(
            labelText: 'Campus ID',
            prefixIcon: const Icon(Icons.badge),
            hintText: 'e.g. A12345',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your campus ID';
            }
            final trimmed = value.trim();
            // Check if alphanumeric only
            if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmed)) {
              return 'Campus ID must contain only letters and numbers';
            }
            // Check max length
            if (trimmed.length > 10) {
              return 'Campus ID must not exceed 10 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _identityCardController,
          decoration: InputDecoration(
            labelText: 'Identity Card Number',
            prefixIcon: const Icon(Icons.credit_card),
            hintText: 'e.g. 123456-12-1234',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your IC number';
            }
            final trimmed = value.trim();
            // Check IC format: XXXXXX-XX-XXXX
            if (!RegExp(r'^\d{6}-\d{2}-\d{4}$').hasMatch(trimmed)) {
              return 'IC format must be XXXXXX-XX-XXXX \n (e.g. 123456-12-1234)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPickupDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('Pickup Details'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Optional',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectPickupDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.deepPurple.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pickup Date',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pickupDate == null
                            ? 'Select date'
                            : '${_pickupDate!.day}/${_pickupDate!.month}/${_pickupDate!.year}',
                        style: TextStyle(
                          fontSize: 15,
                          color: _pickupDate == null
                              ? Colors.grey.shade500
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _selectPickupTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.deepPurple.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pickup Time',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pickupTime == null
                            ? 'Select time'
                            : '${_pickupTime!.hour.toString().padLeft(2, '0')}:${_pickupTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 15,
                          color: _pickupTime == null
                              ? Colors.grey.shade500
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmationCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _confirmationChecked,
          onChanged: (value) {
            setState(() {
              _confirmationChecked = value ?? false;
            });
          },
          activeColor: Colors.deepPurple.shade700,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _confirmationChecked = !_confirmationChecked;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'I confirm that this item belongs to me and the information provided is accurate. I understand that making a false claim may result in account suspension and that the school may take further disciplinary or legal action.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.deepOrange.shade700,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitClaim,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: const Text(
          'Submit Claim',
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
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }
}