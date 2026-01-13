import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/app_config_service.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: const GlassmorphismAppBar(title: 'Help & Support'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appSettings')
            .doc('helpSupport')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildDefaultHelpSupport(context);
          }

          final data = snapshot.data!.data()!;
          return _buildDynamicHelpSupport(context, data);
        },
      ),
    );
  }

  Widget _buildDefaultHelpSupport(BuildContext context) {
    final config = AppConfigService();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Contact'),
        _contactTile(
          context,
          icon: Icons.chat,
          color: const Color(0xFF25D366),
          title: 'WhatsApp',
          subtitle: 'Chat with studio support',
          onTap: () => _openWhatsApp(context, config.studioWhatsAppNumber),
        ),
        _contactTile(
          context,
          icon: Icons.call,
          color: const Color(0xFF10B981),
          title: 'Call',
          subtitle: 'Talk to studio team',
          onTap: () => _call('tel:${config.studioWhatsAppNumber}'),
        ),
        _contactTile(
          context,
          icon: Icons.email_outlined,
          color: const Color(0xFF4F46E5),
          title: 'Email',
          subtitle: 'Send us an email',
          onTap: () => _email('support@dancerang.com'),
        ),
        const SizedBox(height: 16),
        _sectionHeader('Links'),
        _linkTile(
          context,
          icon: Icons.location_on,
          title: 'Studio Location',
          subtitle: 'Open in Maps',
          url: 'https://maps.google.com?q=DanceRang%20Studio',
        ),
        _linkTile(
          context,
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'Read our policy',
          url: 'https://dancerang.com/privacy',
        ),
        _linkTile(
          context,
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          subtitle: 'Review terms',
          url: 'https://dancerang.com/terms',
        ),
        _linkTile(
          context,
          icon: Icons.language,
          title: 'Website',
          subtitle: 'Visit dancerang.com',
          url: 'https://dancerang.com',
        ),
      ],
    );
  }

  Widget _buildDynamicHelpSupport(BuildContext context, Map<String, dynamic> data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Contact'),
        if (data['whatsapp']?.isNotEmpty == true)
          _contactTile(
            context,
            icon: Icons.chat,
            color: const Color(0xFF25D366),
            title: 'WhatsApp',
            subtitle: 'Chat with studio support',
            onTap: () => _openWhatsApp(context, data['whatsapp']),
          ),
        if (data['phone']?.isNotEmpty == true)
          _contactTile(
            context,
            icon: Icons.call,
            color: const Color(0xFF10B981),
            title: 'Call',
            subtitle: 'Talk to studio team',
            onTap: () => _call('tel:${data['phone']}'),
          ),
        if (data['email']?.isNotEmpty == true)
          _contactTile(
            context,
            icon: Icons.email_outlined,
            color: const Color(0xFF4F46E5),
            title: 'Email',
            subtitle: 'Send us an email',
            onTap: () => _email(data['email']),
          ),
        const SizedBox(height: 16),
        _sectionHeader('Links'),
        if (data['studioLocation']?.isNotEmpty == true)
          _linkTile(
            context,
            icon: Icons.location_on,
            title: 'Studio Location',
            subtitle: 'Open in Maps',
            url: data['studioLocation'],
          ),
        if (data['privacyPolicy']?.isNotEmpty == true)
          _linkTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read our policy',
            url: data['privacyPolicy'],
          ),
        if (data['termsOfService']?.isNotEmpty == true)
          _linkTile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Review terms',
            url: data['termsOfService'],
          ),
        if (data['website']?.isNotEmpty == true)
          _linkTile(
            context,
            icon: Icons.language,
            title: 'Website',
            subtitle: 'Visit our website',
            url: data['website'],
          ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFFE53935), fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _contactTile(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.12))),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      ),
    );
  }

  Widget _linkTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required String url}) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.12))),
      child: ListTile(
        onTap: () => _launch(url),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFFE53935), size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.open_in_new, color: Colors.white54, size: 16),
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context, String number) async {
    try {
      final uri = Uri.parse('https://wa.me/$number');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        final uri = Uri.parse('whatsapp://send?phone=$number');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp not available: $e2'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _call(String telUrl) async {
    final uri = Uri.parse(telUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _email(String email) async {
    final uri = Uri.parse('mailto:$email');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}


