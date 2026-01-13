import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_config_service.dart';

class ContactStudioDialog extends StatefulWidget {
  @override
  _ContactStudioDialogState createState() => _ContactStudioDialogState();
}

class _ContactStudioDialogState extends State<ContactStudioDialog> {
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContactInfo();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadContactInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('contact_info')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _phoneController.text = data['phone'] ?? '';
        _whatsappController.text = data['whatsapp'] ?? '';
        _emailController.text = data['email'] ?? '';
        _locationController.text = data['location'] ?? '';
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Edit Contact Studio', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      hint: '+91 98765 43210',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _whatsappController,
                      label: 'WhatsApp Number',
                      icon: Icons.message,
                      hint: '919999999999',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email,
                      hint: 'info@dancerang.com',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Studio Location',
                      icon: Icons.location_on,
                      hint: 'Mumbai, India',
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _saveContactInfo,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF262626)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
      ),
    );
  }

  Future<void> _saveContactInfo() async {
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('contact_info')
          .set({
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'location': _locationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update the AppConfigService
      final config = AppConfigService();
      await config.updateContactInfo(
        phone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        email: _emailController.text.trim(),
        location: _locationController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact information updated successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update contact information. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
