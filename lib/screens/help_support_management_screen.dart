import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';

class HelpSupportManagementScreen extends StatefulWidget {
  const HelpSupportManagementScreen({super.key});

  @override
  State<HelpSupportManagementScreen> createState() => _HelpSupportManagementScreenState();
}

class _HelpSupportManagementScreenState extends State<HelpSupportManagementScreen> {
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _studioLocationController = TextEditingController();
  final TextEditingController _privacyPolicyController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHelpSupportData();
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _studioLocationController.dispose();
    _privacyPolicyController.dispose();
    _termsController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadHelpSupportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('helpSupport')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _whatsappController.text = data['whatsapp'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          _studioLocationController.text = data['studioLocation'] ?? '';
          _privacyPolicyController.text = data['privacyPolicy'] ?? '';
          _termsController.text = data['termsOfService'] ?? '';
          _websiteController.text = data['website'] ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading help & support data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveHelpSupportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('helpSupport')
          .set({
        'whatsapp': _whatsappController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'studioLocation': _studioLocationController.text.trim(),
        'privacyPolicy': _privacyPolicyController.text.trim(),
        'termsOfService': _termsController.text.trim(),
        'website': _websiteController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Help & Support data saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving data: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save data. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSaveData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('helpSupport')
          .set({
        'whatsapp': '919999999999',
        'phone': '+91 99999 99999',
        'email': 'support@dancerang.com',
        'studioLocation': 'https://maps.google.com?q=DanceRang%20Studio',
        'privacyPolicy': 'https://dancerang.com/privacy',
        'termsOfService': 'https://dancerang.com/terms',
        'website': 'https://dancerang.com',
        'lastUpdated': FieldValue.serverTimestamp(),
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test data saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving test data: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed. Please check your settings.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: const GlassmorphismAppBar(title: 'Help & Support Management'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    'Contact Information',
                    'Support contact details',
                    Icons.contact_support,
                    const Color(0xFF4CAF50),
                    [
                      _buildTextField('WhatsApp Number', _whatsappController, Icons.chat, hintText: 'e.g., 919999999999'),
                      const SizedBox(height: 12),
                      _buildTextField('Phone Number', _phoneController, Icons.phone, hintText: 'e.g., +91 99999 99999'),
                      const SizedBox(height: 12),
                      _buildTextField('Email Address', _emailController, Icons.email, hintText: 'e.g., support@dancerang.com'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildSectionCard(
                    'Links & Information',
                    'External links and policies',
                    Icons.link,
                    const Color(0xFF17A2B8),
                    [
                      _buildTextField('Studio Location', _studioLocationController, Icons.location_on, hintText: 'e.g., https://maps.google.com?q=DanceRang%20Studio'),
                      const SizedBox(height: 12),
                      _buildTextField('Privacy Policy URL', _privacyPolicyController, Icons.privacy_tip_outlined, hintText: 'e.g., https://dancerang.com/privacy'),
                      const SizedBox(height: 12),
                      _buildTextField('Terms of Service URL', _termsController, Icons.description_outlined, hintText: 'e.g., https://dancerang.com/terms'),
                      const SizedBox(height: 12),
                      _buildTextField('Website URL', _websiteController, Icons.language, hintText: 'e.g., https://dancerang.com'),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveHelpSupportData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF17A2B8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save Data',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _testSaveData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Test Save',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.2),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter $label',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: Icon(icon, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF17A2B8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
          ),
        ),
      ],
    );
  }
}
