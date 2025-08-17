import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';

class EventChoreoScreen extends StatelessWidget {
  const EventChoreoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DanceRang'),
        centerTitle: true,
        actions: [
          // Settings (gear) visible ONLY here and ONLY to admin
          ValueListenableBuilder(
            valueListenable: AppState.currentRole,
            builder: (_, role, __) {
              final isAdmin = role.toString().contains('admin');
              if (!isAdmin) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Coming soon: edit copy/prices',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inline settings coming soon')),
                ),
                icon: const Icon(Icons.settings_rounded),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text('Event Choreography', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          // Pricing blocks
          _PriceCard(
            title: 'School Function',
            base: 4500,
            bulk: 3500,
            detail: 'Per dance • Solo / Group • 5+ dances → ₹3500 per dance',
          ),
          const SizedBox(height: 12),
          _PriceCard(
            title: 'Sangeet',
            base: 7500,
            bulk: 5500,
            detail: 'Per dance • Solo / Group • 5+ dances → ₹5500 per dance',
          ),
          const SizedBox(height: 12),
          _PriceCard(
            title: 'Corporate Performance',
            base: 7500,
            bulk: 5500,
            detail: 'Per dance • Solo / Group • 5+ dances → ₹5500 per dance',
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('What’s included', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  _Bullet('Music editing & choreography'),
                  _Bullet('Dedicated private sessions'),
                  _Bullet('Faculty/Admin availability on event day'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          _ActionsRow(),
          const SizedBox(height: 12),
          _BookForm(),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.title, required this.base, required this.bulk, required this.detail});
  final String title;
  final int base;
  final int bulk;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('₹$base per dance  •  5+ dances → ₹$bulk per dance'),
            const SizedBox(height: 6),
            Text(detail, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.red),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppState.settings,
      builder: (_, s, __) {
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _call(s.adminPhone),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call now'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _whatsapp(s.whatsapp),
                icon: const Icon(Icons.whatsapp),
                label: const Text('WhatsApp'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> _whatsapp(String? number) async {
    if (number == null || number.isEmpty) return;
    final uri = Uri.parse('https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _BookForm extends StatefulWidget {
  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _date = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'School Function';
  int _dances = 1;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _date.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request sent. We’ll contact you soon.')),
    );
    _form.currentState!.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Book now', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Client name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Client phone *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'School Function', child: Text('School Function')),
                  DropdownMenuItem(value: 'Sangeet', child: Text('Sangeet')),
                  DropdownMenuItem(value: 'Corporate Performance', child: Text('Corporate Performance')),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
                decoration: const InputDecoration(labelText: 'Event type'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _date,
                      decoration: const InputDecoration(labelText: 'Event date'),
                      readOnly: true,
                      onTap: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (d != null) _date.text = d.toLocal().toString().split(' ').first;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('No. of dances:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _dances,
                    items: List.generate(10, (i) => i + 1)
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) => setState(() => _dances = v ?? _dances),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}