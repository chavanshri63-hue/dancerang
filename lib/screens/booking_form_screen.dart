// lib/screens/booking_form_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';

class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({super.key});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _form = GlobalKey<FormState>();

  // Controllers
  final _clientName = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _dancesCount = TextEditingController(text: '1');
  final _notes = TextEditingController();

  // Pickers
  DateTime? _date;
  TimeOfDay? _time;

  // Selections
  String _eventType = 'School / College Function';
  String _groupType = 'Solo';
  bool _includeMusicEdit = true;
  bool _includeSessions = true;
  bool _includeEventDaySupport = true;

  @override
  void dispose() {
    _clientName.dispose();
    _phone.dispose();
    _location.dispose();
    _dancesCount.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ---- Pricing rules ----
  int _ratePerDance() {
    final count = int.tryParse(_dancesCount.text.trim()) ?? 1;
    switch (_eventType) {
      case 'School / College Function':
        return count > 5 ? 3500 : 4500;
      case 'Sangeet / Wedding':
        return count > 5 ? 5500 : 7500;
      case 'Corporate Event (Performance)':
        return count > 5 ? 5500 : 7500;
      default:
        return 0;
    }
  }

  int _estimateTotal() {
    final count = (int.tryParse(_dancesCount.text.trim()) ?? 1).clamp(1, 999);
    return count * _ratePerDance();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _date ?? now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _callNow() async {
    final uri = Uri.parse('tel:${_phone.text.trim().isEmpty ? "0000000000" : _phone.text.trim()}');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calling not supported on this device')),
        );
      }
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;

    final summary = '''
Event: $_eventType • $_groupType
Client: ${_clientName.text.trim()} (${_phone.text.trim()})
Location: ${_location.text.trim()}
Date/Time: ${_date == null ? '—' : _date!.toLocal().toString().split(' ').first} ${_time == null ? '' : '• ${_time!.format(context)}'}
Dances: ${_dancesCount.text.trim()} @ ₹${_ratePerDance()} = ₹${_estimateTotal()}
Includes: ${[
      if (_includeMusicEdit) 'Music edit',
      if (_includeSessions) 'Private sessions',
      if (_includeEventDaySupport) 'Event-day support',
    ].join(', ')}
Notes: ${_notes.text.trim().isEmpty ? '—' : _notes.text.trim()}
''';

    // Local notify feed
    AppState.pushNotification('New event booking enquiry • ${_clientName.text.trim()}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enquiry sent'),
        content: SingleChildScrollView(child: Text(summary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('We will contact you shortly.')),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Book Event / Choreography')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero visual (simple, uses theme only)
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(.20),
                  Theme.of(context).colorScheme.secondary.withOpacity(.10),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Professional choreography for\nschools · weddings · corporate',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Price summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick estimate', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('₹${_estimateTotal()} (₹${_ratePerDance()}/dance)'),
                  const SizedBox(height: 8),
                  const Text('• School: 4500/dance (3500 if >5)'),
                  const Text('• Sangeet: 7500/dance (5500 if >5)'),
                  const Text('• Corporate: 7500/dance (5500 if >5)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Form(
            key: _form,
            child: Column(
              children: [
                // Event type
                DropdownButtonFormField<String>(
                  value: _eventType,
                  decoration: const InputDecoration(labelText: 'Event type *'),
                  items: const [
                    DropdownMenuItem(value: 'School / College Function', child: Text('School / College Function')),
                    DropdownMenuItem(value: 'Sangeet / Wedding', child: Text('Sangeet / Wedding')),
                    DropdownMenuItem(value: 'Corporate Event (Performance)', child: Text('Corporate Event (Performance)')),
                  ],
                  onChanged: (v) => setState(() => _eventType = v!),
                ),
                const SizedBox(height: 12),

                // Group type
                DropdownButtonFormField<String>(
                  value: _groupType,
                  decoration: const InputDecoration(labelText: 'Solo / Group *'),
                  items: const [
                    DropdownMenuItem(value: 'Solo', child: Text('Solo')),
                    DropdownMenuItem(value: 'Group', child: Text('Group')),
                  ],
                  onChanged: (v) => setState(() => _groupType = v!),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _clientName,
                  decoration: const InputDecoration(labelText: 'Client name *', prefixIcon: Icon(Icons.person)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone)),
                  validator: (v) => (v == null || v.trim().length < 8) ? 'Enter valid phone' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Location / Venue *', prefixIcon: Icon(Icons.location_on)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _dancesCount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of dances *', prefixIcon: Icon(Icons.numbers)),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(_date == null
                            ? 'Pick date'
                            : _date!.toLocal().toString().split(' ').first),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule),
                        title: Text(_time == null ? 'Pick time' : _time!.format(context)),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  value: _includeMusicEdit,
                  onChanged: (v) => setState(() => _includeMusicEdit = v),
                  title: const Text('Music editing included'),
                ),
                SwitchListTile(
                  value: _includeSessions,
                  onChanged: (v) => setState(() => _includeSessions = v),
                  title: const Text('Dedicated private sessions'),
                ),
                SwitchListTile(
                  value: _includeEventDaySupport,
                  onChanged: (v) => setState(() => _includeEventDaySupport = v),
                  title: const Text('Faculty/Admin available on event day'),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send),
                        label: const Text('Send enquiry'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _callNow,
                      icon: const Icon(Icons.call),
                      label: const Text('Call now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}