import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_theme.dart';

class AdminAccessManagementPage extends StatefulWidget {
  const AdminAccessManagementPage({super.key});

  @override
  State<AdminAccessManagementPage> createState() =>
      _AdminAccessManagementPageState();
}

class _AdminAccessManagementPageState extends State<AdminAccessManagementPage> {
  final _emailController = TextEditingController();
  bool _checking = false;
  bool _isAuthorized = false;
  Map<String, dynamic>? _targetUser;
  String? _targetUid;

  @override
  void initState() {
    super.initState();
    _verifySuperAdmin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _matchSuperAdmin({
    required String email,
    required String fullName,
    required String role,
  }) {
    final e = email.trim().toLowerCase();
    final n = fullName.trim().toLowerCase();
    final r = role.trim().toLowerCase();
    return r == 'super_admin' ||
        e == 'myphone' ||
        e.startsWith('myphone@') ||
        n == 'myphone';
  }

  Future<void> _verifySuperAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      final email =
          (data['email'] ?? user.email ?? '').toString();
      final fullName = (data['fullName'] ?? '').toString();
      final role = (data['role'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _isAuthorized = _matchSuperAdmin(
          email: email,
          fullName: fullName,
          role: role,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAuthorized = false);
    }
  }

  Future<void> _findUser() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter user email')),
      );
      return;
    }
    setState(() {
      _checking = true;
      _targetUser = null;
      _targetUid = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        setState(() => _checking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }
      final doc = snap.docs.first;
      setState(() {
        _targetUid = doc.id;
        _targetUser = doc.data();
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _setRole(String role) async {
    if (_targetUid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUid!)
          .set({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _targetUser = {
          ...?_targetUser,
          'role': role,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to $role')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Admin Access Management'),
        backgroundColor: AdminTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !_isAuthorized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Access denied. Only super admin can manage admin roles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'User Email',
                      hintText: 'user@example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _checking ? null : _findUser,
                    icon: const Icon(Icons.search),
                    label: Text(_checking ? 'Searching...' : 'Find User'),
                  ),
                  const SizedBox(height: 16),
                  if (_targetUser != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_targetUser!['fullName'] ?? 'N/A').toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (_targetUser!['email'] ?? '').toString(),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Current role: ${(_targetUser!['role'] ?? 'user')}',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _setRole('admin'),
                                    child: const Text('Promote to Admin'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _setRole('user'),
                                    child: const Text('Demote to User'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
