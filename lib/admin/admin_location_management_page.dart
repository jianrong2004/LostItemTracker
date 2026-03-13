import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// TARUMT campus (Setapak) - same as user maps
const LatLng _tarumtCampusCenter = LatLng(3.2158, 101.7306);
const double _tarumtMinLat = 3.2130;
const double _tarumtMaxLat = 3.2190;
const double _tarumtMinLng = 101.7245;
const double _tarumtMaxLng = 101.7365;

LatLng _clampToTarumtCampus(double lat, double lng) {
  return LatLng(
    lat.clamp(_tarumtMinLat, _tarumtMaxLat),
    lng.clamp(_tarumtMinLng, _tarumtMaxLng),
  );
}

class DropOffDeskModel {
  final String id;
  final String name;
  final String description;
  final String operatingHours;
  final String contact;
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
  final _colorController = TextEditingController(text: '#3F51B5');
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _hoursController.dispose();
    _contactController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _nameController.clear();
    _descController.clear();
    _hoursController.clear();
    _contactController.clear();
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
    _contactController.text = desk.contact;
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
      final data = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'operatingHours': _hoursController.text.trim(),
        'contact': _contactController.text.trim(),
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
      appBar: AppBar(
        title: const Text('Location Management'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
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

  @override
  void initState() {
    super.initState();
    final initLat = widget.lat ?? _tarumtCampusCenter.latitude;
    final initLng = widget.lng ?? _tarumtCampusCenter.longitude;
    _lat = initLat.clamp(_tarumtMinLat, _tarumtMaxLat);
    _lng = initLng.clamp(_tarumtMinLng, _tarumtMaxLng);
    widget.onPickLocation(_lat, _lng);
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
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: widget.nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.hoursController,
                decoration: const InputDecoration(labelText: 'Operating hours'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.contactController,
                decoration: const InputDecoration(labelText: 'Contact'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.colorController,
                decoration: const InputDecoration(labelText: 'Color hex (e.g. #3F51B5)'),
              ),
              const SizedBox(height: 12),
              const Text('Coordinates (tap map to set) — TARUMT campus only', style: TextStyle(fontSize: 12)),
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
                          setState(() {
                            _lat = clamped.latitude;
                            _lng = clamped.longitude;
                            widget.onPickLocation(_lat, _lng);
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.lostitemtracker.lost_item_tracker_client',
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
              Text('Lat: ${_lat.toStringAsFixed(5)}, Lng: ${_lng.toStringAsFixed(5)} (TARUMT campus)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final name = widget.nameController.text.trim();
            final contact = widget.contactController.text.trim();
            final colorHex = widget.colorController.text.trim();

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name is required')),
              );
              return;
            }
            if (!RegExp(r'^[A-Za-z0-9\\s]+$').hasMatch(name)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name must contain letters, numbers and spaces only')),
              );
              return;
            }
            if (contact.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact is required')),
              );
              return;
            }
            if (!RegExp(r'^[0-9]+$').hasMatch(contact)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact must contain digits only')),
              );
              return;
            }
            if (colorHex.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Color hex is required')),
              );
              return;
            }
            if (!RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(colorHex)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Color hex must be a 6-digit hex value like #3F51B5')),
              );
              return;
            }

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
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
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
                setState(() {
                  _lat = clamped.latitude;
                  _lng = clamped.longitude;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lostitemtracker.lost_item_tracker_client',
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
