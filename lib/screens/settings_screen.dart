import 'package:flutter/material.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'invoice_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: const GlassmorphismAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('App'),
          // Theme option removed as per requirement
          const SizedBox(height: 16),
          _sectionHeader('Payments'),
          _navTile(
            icon: Icons.receipt_long,
            title: 'Invoice history',
            subtitle: 'View and download invoices',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InvoiceHistoryScreen()),
            ),
          ),
        ],
      ),
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

  Widget _navTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.12))),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFFE53935), size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      ),
    );
  }

}


