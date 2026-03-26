import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'admin_theme.dart';

// TARUMT campus (Setapak) - same as user maps
const LatLng _tarumtCampusCenter = LatLng(3.2158, 101.7306);
const double _tarumtMinLat = 3.2130;
const double _tarumtMaxLat = 3.2190;
const double _tarumtMinLng = 101.7245;
const double _tarumtMaxLng = 101.7365;

// Campus boundary polygon (used to render the “campus-shaped” area on admin maps).
// Source: user-side campus selection map boundary.
const List<LatLng> _campusBoundary = [
  LatLng(3.2149188, 101.7284679),
  LatLng(3.2150248, 101.7286868),
  LatLng(3.2151547, 101.7291401),
  LatLng(3.215156, 101.7294902),
  LatLng(3.2150489, 101.7298281),
  LatLng(3.21484, 101.7301674),
  LatLng(3.2146646, 101.7303136),
  LatLng(3.214283, 101.7306784),
  LatLng(3.2139295, 101.7312376),
  LatLng(3.2138706, 101.7314737),
  LatLng(3.2141824, 101.7317509),
  LatLng(3.2149014, 101.7326749),
  LatLng(3.2152576, 101.7331738),
  LatLng(3.2154517, 101.7335667),
  LatLng(3.2155816, 101.7342279),
  LatLng(3.2157155, 101.7347496),
  LatLng(3.2158253, 101.7359002),
  LatLng(3.2159244, 101.7360089),
  LatLng(3.2163943, 101.7362114),
  LatLng(3.2167466, 101.7363885),
  LatLng(3.2173075, 101.7363469),
  LatLng(3.2177896, 101.7362516),
  LatLng(3.2179603, 101.7361832),
  LatLng(3.2181257, 101.7360987),
  LatLng(3.2183165, 101.7360015),
  LatLng(3.2186251, 101.7358935),
  LatLng(3.2186653, 101.7336231),
  LatLng(3.2185836, 101.7324288),
  LatLng(3.2186787, 101.7312668),
  LatLng(3.2186834, 101.7306079),
  LatLng(3.2186077, 101.7300028),
  LatLng(3.2185749, 101.7293654),
  LatLng(3.2184886, 101.7288139),
  LatLng(3.2185033, 101.7276089),
  LatLng(3.2185606, 101.7273425),
  LatLng(3.2185214, 101.7271083),
  LatLng(3.2184394, 101.726799),
  LatLng(3.2184645, 101.7264146),
  LatLng(3.2170933, 101.7247624),
  LatLng(3.2168443, 101.7246873),
  LatLng(3.2144716, 101.7256556),
  LatLng(3.2130938, 101.7259734),
  LatLng(3.2133348, 101.7265997),
  LatLng(3.2135932, 101.7270315),
  LatLng(3.2143604, 101.7276914),
  LatLng(3.214659, 101.7280374),
  LatLng(3.2149188, 101.7284679),
];

LatLng _clampToTarumtCampus(double lat, double lng) {
  return LatLng(
    lat.clamp(_tarumtMinLat, _tarumtMaxLat),
    lng.clamp(_tarumtMinLng, _tarumtMaxLng),
  );
}

bool _isLatLngInsidePolygon(LatLng point, List<LatLng> polygon) {
  // Ray casting algorithm with “on-edge” detection to better match taps.
  final x = point.longitude;
  final y = point.latitude;
  var inside = false;

  const eps = 1e-9;
  bool onSegment(LatLng a, LatLng b) {
    final x1 = a.longitude;
    final y1 = a.latitude;
    final x2 = b.longitude;
    final y2 = b.latitude;

    // Check collinearity via cross product.
    final cross = (x - x1) * (y2 - y1) - (y - y1) * (x2 - x1);
    if (cross.abs() > eps) return false;

    // Check within bounding box.
    final minX = (x1 < x2) ? x1 : x2;
    final maxX = (x1 > x2) ? x1 : x2;
    final minY = (y1 < y2) ? y1 : y2;
    final maxY = (y1 > y2) ? y1 : y2;

    return x + eps >= minX && x - eps <= maxX && y + eps >= minY && y - eps <= maxY;
  }

  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    if (onSegment(a, b)) return true;
  }

  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;

    final intersect = ((yi > y) != (yj > y)) &&
        (x < (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

bool _isInsideTarumtCampus(LatLng p) => _isLatLngInsidePolygon(p, _campusBoundary);

class DropOffDeskModel {
  final String id;
  final String name;
  final String description;
  final String operatingHours;
  final String contact;
  final String email;
  final double latitude;
  final double longitude;
  final String colorHex;
  final bool isActive;

  DropOffDeskModel({
    required this.id,
    required this.name,
    required this.description,
    required this.operatingHours,
    required this.contact,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.colorHex,
    required this.isActive,
  });

  factory DropOffDeskModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DropOffDeskModel(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      operatingHours: d['operatingHours'] ?? '',
      contact: d['contact'] ?? '',
      email: d['email'] ?? '',
      latitude: (d['latitude'] ?? 0.0).toDouble(),
      longitude: (d['longitude'] ?? 0.0).toDouble(),
      colorHex: d['colorHex'] ?? '#3F51B5',
      isActive: d['isActive'] ?? true,
    );
  }
}

class AdminLocationManagementPage extends StatefulWidget {
  const AdminLocationManagementPage({super.key});

  @override
  State<AdminLocationManagementPage> createState() => _AdminLocationManagementPageState();
}

class _AdminLocationManagementPageState extends State<AdminLocationManagementPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _hoursController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _colorController = TextEditingController(text: '#3F51B5');
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _hoursController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _nameController.clear();
    _descController.clear();
    _hoursController.clear();
    _contactController.clear();
    _emailController.clear();
    _colorController.text = '#3F51B5';
    _lat = _tarumtCampusCenter.latitude;
    _lng = _tarumtCampusCenter.longitude;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeskFormDialog(
        nameController: _nameController,
        descController: _descController,
        hoursController: _hoursController,
        contactController: _contactController,
        emailController: _emailController,
        colorController: _colorController,
        lat: _lat,
        lng: _lng,
        onPickLocation: (lat, lng) {
          _lat = lat;
          _lng = lng;
        },
        title: 'Add Lost & Found Station',
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty && _lat != null && _lng != null) {
      await _saveDesk(null);
    }
  }

  Future<void> _showEditDialog(DropOffDeskModel desk) async {
    _nameController.text = desk.name;
    _descController.text = desk.description;
    _hoursController.text = desk.operatingHours;
    _emailController.text = desk.email;
    // Parse phone parts from `contact` which might be stored as:
    // - Tel: +603-<prefix>-<suffix> Email: <email>
    // - Tel: +603-<prefix> - <suffix> Email: <email>
    // - legacy formats like <prefix>-<suffix> or digits
    final contactRaw = desk.contact.trim();

    final telMatchWith603 = RegExp(r'Tel:\s*\+603-([0-9]{1,3})\s*-\s*([0-9]{1,10})').firstMatch(contactRaw);
    final telMatchWith603NoSpaces = RegExp(r'Tel:\s*\+603-([0-9]{1,3})-([0-9]{1,10})').firstMatch(contactRaw);
    final telMatchNo603 = RegExp(r'Tel:\s*([0-9]{1,3})\s*-\s*([0-9]{1,10})').firstMatch(contactRaw);

    final match = telMatchWith603 ?? telMatchWith603NoSpaces ?? telMatchNo603;
    if (match != null) {
      _contactController.text = '${match.group(1)}-${match.group(2)}';
    } else {
      // Fallback: extract digits and '-' then take first two parts.
      final digitsAndDash = contactRaw.replaceAll(RegExp(r'[^0-9-]'), '');
      final parts = digitsAndDash.split('-').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        _contactController.text = '${parts.first}-${parts[1]}';
      } else {
        _contactController.text = contactRaw;
      }
    }

    // Backward-compat: if email field is empty, try extracting from contact text.
    if (_emailController.text.trim().isEmpty && contactRaw.contains('@')) {
      final emailMatch = RegExp(r'([^\s@]+@[^\s@]+\.[^\s@]+)').firstMatch(contactRaw);
      _emailController.text = emailMatch?.group(1) ?? '';
    }
    _colorController.text = desk.colorHex;
    final clamped = _clampToTarumtCampus(desk.latitude, desk.longitude);
    _lat = clamped.latitude;
    _lng = clamped.longitude;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeskFormDialog(
        nameController: _nameController,
        descController: _descController,
        hoursController: _hoursController,
        contactController: _contactController,
        emailController: _emailController,
        colorController: _colorController,
        lat: _lat,
        lng: _lng,
        onPickLocation: (lat, lng) {
          _lat = lat;
          _lng = lng;
        },
        title: 'Edit Station',
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty && _lat != null && _lng != null) {
      await _saveDesk(desk.id);
    }
  }

  Future<void> _saveDesk(String? id) async {
    try {
      final email = _emailController.text.trim();
      final phone = _contactController.text.trim();
      final phoneParts = phone.split('-').where((p) => p.isNotEmpty).toList();
      final prefix = phoneParts.isNotEmpty ? phoneParts.first : '';
      final suffix = phoneParts.length >= 2 ? phoneParts[1] : '';

      final telFormatted = (prefix.isNotEmpty && suffix.isNotEmpty)
          ? '+603-$prefix - $suffix'
          : '+603-$phone';

      // User app renders `desk.contact` as plain text.
      // Put email on next line so it doesn't wrap awkwardly.
      final contactFormatted = email.isNotEmpty
          ? 'Tel: $telFormatted\nEmail: $email'
          : 'Tel: $telFormatted';
      final data = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'operatingHours': _hoursController.text.trim(),
        'contact': contactFormatted,
        'email': email,
        'colorHex': _colorController.text.trim().isEmpty ? '#3F51B5' : _colorController.text.trim(),
        'latitude': _lat!,
        'longitude': _lng!,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (id == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('dropOffDesks').add(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station added'), behavior: SnackBarBehavior.floating),
        );
      } else {
        await FirebaseFirestore.instance.collection('dropOffDesks').doc(id).update(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station updated'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await FirebaseFirestore.instance.collection('dropOffDesks').doc(id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Station status updated'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteDesk(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text('Delete \"$name\"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('dropOffDesks').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station deleted'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Location Management'),
        backgroundColor: AdminTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('dropOffDesks').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final desks = snapshot.data!.docs.map((d) => DropOffDeskModel.fromFirestore(d)).toList();
          if (desks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No stations. Add one.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: desks.length,
            itemBuilder: (context, index) {
              final desk = desks[index];
              Color color;
              try {
                color = Color(int.parse(desk.colorHex.replaceFirst('#', '0xFF')));
              } catch (_) {
                color = Colors.green;
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(Icons.store, color: color),
                  ),
                  title: Text(desk.name),
                  subtitle: Text(
                    '${desk.operatingHours} • ${desk.contact}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.green.shade700),
                        onPressed: () => _showEditDialog(desk),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                        onPressed: () => _deleteDesk(desk.id, desk.name),
                        tooltip: 'Delete',
                      ),
                      Switch(
                        value: desk.isActive,
                        onChanged: (_) => _toggleActive(desk.id, desk.isActive),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DeskFormDialog extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController hoursController;
  final TextEditingController contactController;
  final TextEditingController emailController;
  final TextEditingController colorController;
  final double? lat;
  final double? lng;
  final void Function(double lat, double lng) onPickLocation;
  final String title;

  const _DeskFormDialog({
    required this.nameController,
    required this.descController,
    required this.hoursController,
    required this.contactController,
    required this.emailController,
    required this.colorController,
    required this.lat,
    required this.lng,
    required this.onPickLocation,
    required this.title,
  });

  @override
  State<_DeskFormDialog> createState() => _DeskFormDialogState();
}

class _DeskFormDialogState extends State<_DeskFormDialog> {
  late double _lat;
  late double _lng;
  final _formKey = GlobalKey<FormState>();
  final _telPrefixController = TextEditingController();
  final _telSuffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initLat = widget.lat ?? _tarumtCampusCenter.latitude;
    final initLng = widget.lng ?? _tarumtCampusCenter.longitude;
    _lat = initLat.clamp(_tarumtMinLat, _tarumtMaxLat);
    _lng = initLng.clamp(_tarumtMinLng, _tarumtMaxLng);
    widget.onPickLocation(_lat, _lng);

    // Prefill phone parts from stored `contact` (may be in old formats).
    final raw = widget.contactController.text.trim().replaceAll(' ', '');
    String prefix = '';
    String suffix = '';
    if (raw.contains('-')) {
      final parts = raw.split('-');
      prefix = parts.isNotEmpty ? parts[0].replaceAll(RegExp(r'[^0-9]'), '') : '';
      suffix = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '';
    } else {
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        if (digits.length > 10) {
          suffix = digits.substring(digits.length - 10);
          prefix = digits.substring(0, digits.length - 10);
        } else {
          // Heuristic fallback: take up to first 3 digits as prefix.
          final prefixLen = digits.length <= 1 ? 1 : (digits.length - 1 < 3 ? digits.length - 1 : 3);
          prefix = digits.substring(0, prefixLen);
          suffix = digits.substring(prefixLen);
        }
      }
    }
    if (prefix.length > 3) prefix = prefix.substring(0, 3);
    if (suffix.length > 10) suffix = suffix.substring(0, 10);
    _telPrefixController.text = prefix;
    _telSuffixController.text = suffix;

    void syncContact() {
      final p = _telPrefixController.text.trim();
      final s = _telSuffixController.text.trim();
      widget.contactController.text = (p.isEmpty || s.isEmpty) ? '' : '$p-$s';
    }

    syncContact();
    _telPrefixController.addListener(syncContact);
    _telSuffixController.addListener(syncContact);
  }

  @override
  void dispose() {
    _telPrefixController.dispose();
    _telSuffixController.dispose();
    super.dispose();
  }

  Future<void> _openFullScreenMap() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullScreenMapPicker(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        widget.onPickLocation(_lat, _lng);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? validateRequired(String? v, String message) =>
        (v ?? '').trim().isEmpty ? message : null;

    String? validateTelPrefix(String? v) {
      final raw = (v ?? '').trim();
      if (raw.isEmpty) return 'Tel prefix is required';
      if (raw.length > 3) return 'Tel prefix max is 3 digits';
      return null;
    }

    String? validateTelSuffix(String? v) {
      final raw = (v ?? '').trim();
      if (raw.isEmpty) return 'Phone number is required';
      if (raw.length > 10) return 'Phone number max is 10 digits';
      return null;
    }

    String? validateEmail(String? v) {
      final raw = (v ?? '').trim();
      if (raw.isEmpty) return null; // optional
      // Simple email check (good enough for client-side validation)
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(raw)) {
        return 'Email format is invalid';
      }
      return null;
    }

    String? validateColorHex(String? v) {
      final raw = (v ?? '').trim();
      if (raw.isEmpty) return 'Color hex is required';
      if (!RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(raw)) {
        return 'Color hex must be a 6-digit hex value like #3F51B5';
      }
      return null;
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: widget.nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => validateRequired(v, 'Name is required'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.hoursController,
                  decoration: const InputDecoration(
                    labelText: 'Operating hours',
                    hintText: 'e.g. Mon-Fri: 8:00 AM - 6:00 PM\\nSat-Sun: 8:00 AM - 2:00 PM',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Tel:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _telPrefixController,
                        decoration: const InputDecoration(
                          hintText: '111',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: validateTelPrefix,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(' - ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _telSuffixController,
                        decoration: const InputDecoration(
                          hintText: '11111111',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: validateTelSuffix,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    hintText: 'e.g. admin@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: widget.colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color hex (e.g. #3F51B5)',
                    helperText: 'Used as the station marker color on the map (#RRGGBB).',
                  ),
                  validator: validateColorHex,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Coordinates (tap map to set) — TARUMT campus only',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_lat, _lng),
                          initialZoom: 16,
                          minZoom: 15,
                          maxZoom: 18,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                          onTap: (_, p) {
                            final clamped = _clampToTarumtCampus(p.latitude, p.longitude);
                          if (!_isInsideTarumtCampus(clamped)) return;
                            setState(() {
                              _lat = clamped.latitude;
                              _lng = clamped.longitude;
                              widget.onPickLocation(_lat, _lng);
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.tarumt.lost_item_tracker',
                            maxZoom: 19,
                          ),
                          PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _campusBoundary,
                            color: Colors.indigoAccent.withValues(alpha: 0.12),
                            borderColor: Colors.indigo.shade700,
                            borderStrokeWidth: 2.5,
                            isFilled: true,
                          ),
                        ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_lat, _lng),
                                width: 30,
                                height: 30,
                                child: const Icon(Icons.place, color: Colors.red, size: 30),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _openFullScreenMap,
                            child: Tooltip(
                              message: 'Open full screen map',
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(Icons.open_in_full, size: 24, color: Colors.green.shade700),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Lat: ${_lat.toStringAsFixed(5)}, Lng: ${_lng.toStringAsFixed(5)} (TARUMT campus)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final ok = _formKey.currentState?.validate() ?? false;
            if (!ok) return;
            Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _FullScreenMapPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const _FullScreenMapPicker({
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<_FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<_FullScreenMapPicker> {
  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat.clamp(_tarumtMinLat, _tarumtMaxLat);
    _lng = widget.initialLng.clamp(_tarumtMinLng, _tarumtMaxLng);
  }

  void _confirm() {
    Navigator.of(context).pop(LatLng(_lat, _lng));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select location (TARUMT campus)'),
        backgroundColor: AdminTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(_lat, _lng),
              initialZoom: 17,
              minZoom: 15,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (_, p) {
                final clamped = _clampToTarumtCampus(p.latitude, p.longitude);
                if (!_isInsideTarumtCampus(clamped)) return;
                setState(() {
                  _lat = clamped.latitude;
                  _lng = clamped.longitude;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tarumt.lost_item_tracker',
                maxZoom: 19,
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _campusBoundary,
                    color: Colors.indigoAccent.withValues(alpha: 0.12),
                    borderColor: Colors.indigo,
                    borderStrokeWidth: 3.0,
                    isFilled: true,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_lat, _lng),
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.place, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Lat: ${_lat.toStringAsFixed(5)}, Lng: ${_lng.toStringAsFixed(5)}\nTap map to move pin, then Confirm.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
