import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';


class ManageRoleKeysScreen extends StatefulWidget {
  const ManageRoleKeysScreen({super.key});

  @override
  State<ManageRoleKeysScreen> createState() => _ManageRoleKeysScreenState();
}

class _ManageRoleKeysScreenState extends State<ManageRoleKeysScreen> {
  final TextEditingController _adminKeyController = TextEditingController();
  final TextEditingController _facultyKeyController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _adminKeyVisible = false;
  bool _facultyKeyVisible = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void dispose() {
    _adminKeyController.dispose();
    _facultyKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await _firestore
          .collection('appSettings')
          .doc('roleKeys')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _adminKeyController.text = (data['adminKey']?.toString() ?? '').trim();
          _facultyKeyController.text = (data['facultyKey']?.toString() ?? '').trim();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load keys. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateRandomKey({int length = 12}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  void _generateAdminKey() {
    setState(() {
      _adminKeyController.text = _generateRandomKey();
    });
  }

  void _generateFacultyKey() {
    setState(() {
      _facultyKeyController.text = _generateRandomKey();
    });
  }

  void _generateBothKeys() {
    setState(() {
      _adminKeyController.text = _generateRandomKey();
      _facultyKeyController.text = _generateRandomKey();
    });
  }

  Future<void> _setDefaultKeys() async {
    setState(() {
      _adminKeyController.text = _generateRandomKey();
      _facultyKeyController.text = _generateRandomKey();
    });

    await _saveKeys();
  }

  Future<void> _saveKeys() async {
    final adminKey = _adminKeyController.text.trim();
    final facultyKey = _facultyKeyController.text.trim();
    
    // Validation
    if (adminKey.isEmpty || adminKey.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin key must be at least 8 characters long.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (facultyKey.isEmpty || facultyKey.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faculty key must be at least 8 characters long.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore
          .collection('appSettings')
          .doc('roleKeys')
          .set({
        'adminKey': adminKey,
        'facultyKey': facultyKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Keys saved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save keys. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        title: const Text(
          'Manage Role Keys',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2C2C2C),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE53935).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: const Color(0xFFE53935),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Role Keys Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'These keys are used to verify Admin and Faculty roles during registration. Keys are stored securely in Firestore and verified by Firebase Functions.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '⚠️ Keep these keys secure and do not share them publicly.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current Keys Status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current keys are active. Changes will take effect immediately after saving.',
                            style: TextStyle(
                              color: Colors.green.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Admin Key Section
                  _buildKeySection(
                    title: 'Admin Key',
                    controller: _adminKeyController,
                    isVisible: _adminKeyVisible,
                    onToggleVisibility: () {
                      setState(() {
                        _adminKeyVisible = !_adminKeyVisible;
                      });
                    },
                    onGenerate: _generateAdminKey,
                    icon: Icons.admin_panel_settings,
                    color: const Color(0xFFE53935),
                  ),
                  const SizedBox(height: 20),

                  // Faculty Key Section
                  _buildKeySection(
                    title: 'Faculty Key',
                    controller: _facultyKeyController,
                    isVisible: _facultyKeyVisible,
                    onToggleVisibility: () {
                      setState(() {
                        _facultyKeyVisible = !_facultyKeyVisible;
                      });
                    },
                    onGenerate: _generateFacultyKey,
                    icon: Icons.person_outline,
                    color: const Color(0xFF2196F3),
                  ),
                  const SizedBox(height: 24),

                  // Generate Both Button
                  ElevatedButton.icon(
                    onPressed: _generateBothKeys,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate Both Keys'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Set Default Keys Button
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _setDefaultKeys,
                    icon: const Icon(Icons.restore),
                    label: const Text('Generate & Save New Keys'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveKeys,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Keys',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKeySection({
    required String title,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required VoidCallback onGenerate,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: !isVisible,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'Enter $title',
              hintStyle: TextStyle(
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: const Color(0xFF1B1B1B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: color.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: color.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: color,
                  width: 2,
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: onToggleVisibility,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: color,
                    ),
                    onPressed: onGenerate,
                    tooltip: 'Generate Random Key',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

