import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _enableScreenRecording = false;
  bool _enableScreenshot = false;
  bool _enableDownload = false;
  bool _enableSharing = false;
  bool _enableWatermark = true;
  bool _enableDRM = false;
  String _selectedSecurityLevel = 'medium';

  final List<String> _securityLevels = ['low', 'medium', 'high'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Security Settings',
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSecurityLevelCard(),
            const SizedBox(height: 20),
            _buildContentProtectionCard(),
            const SizedBox(height: 20),
            _buildAccessControlCard(),
            const SizedBox(height: 20),
            _buildWatermarkCard(),
            const SizedBox(height: 20),
            _buildDRMCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityLevelCard() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.security, color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Security Level',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose the security level for your content',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ..._securityLevels.map((level) {
              final isSelected = _selectedSecurityLevel == level;
              return RadioListTile<String>(
                title: Text(
                  level.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  _getSecurityLevelDescription(level),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                value: level,
                groupValue: _selectedSecurityLevel,
                onChanged: (value) {
                  setState(() {
                    _selectedSecurityLevel = value ?? 'medium';
                  });
                },
                activeColor: const Color(0xFF4F46E5),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildContentProtectionCard() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFFE53935).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE53935).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock, color: Color(0xFFE53935), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Content Protection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Disable Screen Recording', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Prevent users from recording videos', style: TextStyle(color: Colors.white70)),
              value: _enableScreenRecording,
              onChanged: (value) {
                setState(() {
                  _enableScreenRecording = value;
                });
              },
              activeColor: const Color(0xFFE53935),
            ),
            SwitchListTile(
              title: const Text('Disable Screenshots', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Prevent users from taking screenshots', style: TextStyle(color: Colors.white70)),
              value: _enableScreenshot,
              onChanged: (value) {
                setState(() {
                  _enableScreenshot = value;
                });
              },
              activeColor: const Color(0xFFE53935),
            ),
            SwitchListTile(
              title: const Text('Disable Downloads', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Prevent users from downloading videos', style: TextStyle(color: Colors.white70)),
              value: _enableDownload,
              onChanged: (value) {
                setState(() {
                  _enableDownload = value;
                });
              },
              activeColor: const Color(0xFFE53935),
            ),
            SwitchListTile(
              title: const Text('Disable Sharing', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Prevent users from sharing video links', style: TextStyle(color: Colors.white70)),
              value: _enableSharing,
              onChanged: (value) {
                setState(() {
                  _enableSharing = value;
                });
              },
              activeColor: const Color(0xFFE53935),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessControlCard() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF10B981).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Access Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Control who can access your content',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildAccessControlItem('IP Address Restriction', 'Restrict access by IP address'),
                  const Divider(color: Colors.white24),
                  _buildAccessControlItem('Device Limit', 'Limit number of devices per user'),
                  const Divider(color: Colors.white24),
                  _buildAccessControlItem('Session Timeout', 'Auto-logout after inactivity'),
                  const Divider(color: Colors.white24),
                  _buildAccessControlItem('Geographic Restriction', 'Restrict access by location'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessControlItem(String title, String description) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: Switch(
        value: false, // Default to false
        onChanged: (value) {
          // Handle toggle
        },
        activeColor: const Color(0xFF10B981),
      ),
    );
  }

  Widget _buildWatermarkCard() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFFF59E0B).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFF59E0B).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.water_drop, color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Watermark Protection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Watermark', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Add watermark to all videos', style: TextStyle(color: Colors.white70)),
              value: _enableWatermark,
              onChanged: (value) {
                setState(() {
                  _enableWatermark = value;
                });
              },
              activeColor: const Color(0xFFF59E0B),
            ),
            if (_enableWatermark) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildWatermarkOption('User ID', 'Show user ID on video'),
                    const Divider(color: Colors.white24),
                    _buildWatermarkOption('Timestamp', 'Show current time on video'),
                    const Divider(color: Colors.white24),
                    _buildWatermarkOption('Logo', 'Show DanceRang logo on video'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWatermarkOption(String title, String description) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: Switch(
        value: true, // Default to true
        onChanged: (value) {
          // Handle toggle
        },
        activeColor: const Color(0xFFF59E0B),
      ),
    );
  }

  Widget _buildDRMCard() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF8B5CF6).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.verified_user, color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DRM Protection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Digital Rights Management for premium content',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable DRM', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Advanced encryption for premium videos', style: TextStyle(color: Colors.white70)),
              value: _enableDRM,
              onChanged: (value) {
                setState(() {
                  _enableDRM = value;
                });
              },
              activeColor: const Color(0xFF8B5CF6),
            ),
            if (_enableDRM) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildDRMOption('AES Encryption', '256-bit encryption'),
                    const Divider(color: Colors.white24),
                    _buildDRMOption('License Server', 'Centralized license management'),
                    const Divider(color: Colors.white24),
                    _buildDRMOption('Key Rotation', 'Regular key updates'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDRMOption(String title, String description) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: const Icon(Icons.check_circle, color: Color(0xFF8B5CF6)),
    );
  }

  String _getSecurityLevelDescription(String level) {
    switch (level) {
      case 'low':
        return 'Basic protection with minimal restrictions';
      case 'medium':
        return 'Balanced security with standard protections';
      case 'high':
        return 'Maximum security with all protections enabled';
      default:
        return '';
    }
  }

  Future<void> _saveSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('security')
          .set({
        'securityLevel': _selectedSecurityLevel,
        'enableScreenRecording': _enableScreenRecording,
        'enableScreenshot': _enableScreenshot,
        'enableDownload': _enableDownload,
        'enableSharing': _enableSharing,
        'enableWatermark': _enableWatermark,
        'enableDRM': _enableDRM,
        'updatedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security settings saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: ${e.toString()}'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }
}
