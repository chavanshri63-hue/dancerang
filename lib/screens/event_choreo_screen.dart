// lib/screens/event_choreo_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../widgets/section_scaffold.dart';

class EventChoreoScreen extends StatelessWidget {
  const EventChoreoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DRSectionScaffold(
      sectionTitle: 'Event Choreography',
      actions: [
        // Settings should be here (not on Dashboard)
        ValueListenableBuilder<UserRole>(
          valueListenable: AppState.currentRole,
          builder: (_, role, __) => (role == UserRole.admin)
              ? IconButton(
                  tooltip: 'Edit pricing',
                  onPressed: () => _openEditDialog(context),
                  icon: const Icon(Icons.settings_rounded),
                )
              : const SizedBox.shrink(),
        ),
      ],
      child: ValueListenableBuilder<AppSettings>(
        valueListenable: AppState.settings,
        builder: (_, s, __) {
          final e = s.eventChoreo;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PriceCard(
                title: 'School Function',
                base: e.schoolBase,
                bulk: e.schoolBulk,
                note: 'per dance · Solo/Group (5+ dances: ₹${e.schoolBulk})',
              ),
              const SizedBox(height: 10),
              _PriceCard(
                title: 'Sangeet Dance',
                base: e.sangeetBase,
                bulk: e.sangeetBulk,
                note: 'per dance · Solo/Group (5+ dances: ₹${e.sangeetBulk})',
              ),
              const SizedBox(height: 10),
              _PriceCard(
                title: 'Corporate Performance',
                base: e.corporateBase,
                bulk: e.corporateBulk,
                note: 'per dance · Solo/Group (5+ dances: ₹${e.corporateBulk})',
              ),
              const SizedBox(height: 16),
              Text('What’s included', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(e.included),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _callNow(),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call now'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _whatsapp(),
                    icon: const Icon(Icons.whatsapp_rounded),
                    label: const Text('WhatsApp'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final copy = AppState.settings.value.eventChoreo.copy();
    final sb = TextEditingController(text: copy.schoolBase.toString());
    final sk = TextEditingController(text: copy.schoolBulk.toString());
    final sg = TextEditingController(text: copy.sangeetBase.toString());
    final sgk = TextEditingController(text: copy.sangeetBulk.toString());
    final cb = TextEditingController(text: copy.corporateBase.toString());
    final ck = TextEditingController(text: copy.corporateBulk.toString());
    final inc = TextEditingController(text: copy.included);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit pricing & details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _num(sb, 'School per dance (₹)'),
              _num(sk, 'School 5+ (₹)'),
              _num(sg, 'Sangeet per dance (₹)'),
              _num(sgk, 'Sangeet 5+ (₹)'),
              _num(cb, 'Corporate per dance (₹)'),
              _num(ck, 'Corporate 5+ (₹)'),
              const SizedBox(height: 8),
              TextField(
                controller: inc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'What’s included'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok == true) {
      final e = AppState.settings.value.eventChoreo;
      e.schoolBase = int.tryParse(sb.text.trim()) ?? e.schoolBase;
      e.schoolBulk = int.tryParse(sk.text.trim()) ?? e.schoolBulk;
      e.sangeetBase = int.tryParse(sg.text.trim()) ?? e.sangeetBase;
      e.sangeetBulk = int.tryParse(sgk.text.trim()) ?? e.sangeetBulk;
      e.corporateBase = int.tryParse(cb.text.trim()) ?? e.corporateBase;
      e.corporateBulk = int.tryParse(ck.text.trim()) ?? e.corporateBulk;
      e.included = inc.text.trim().isEmpty ? e.included : inc.text.trim();

      // push into settings and persist
      AppState.settings.value = AppState.settings.value.copy();
      await AppState.saveSettings();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated')),
        );
      }
    }
  }

  Widget _num(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _callNow() async {
    final phone = AppState.settings.value.adminPhone?.trim();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final raw = (AppState.settings.value.whatsapp ?? AppState.settings.value.adminPhone ?? '').trim();
    if (raw.isEmpty) return;
    final number = raw.replaceAll(RegExp(r'[^0-9]'), ''); // sanitize
    // open chat
    final uri = Uri.parse('https://wa.me/$number');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.title, required this.base, required this.bulk, required this.note});
  final String title;
  final int base;
  final int bulk;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.celebration_rounded),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(note),
        trailing: Text('₹$base'),
      ),
    );
  }
}