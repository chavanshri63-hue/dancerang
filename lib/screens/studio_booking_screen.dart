// lib/screens/studio_booking_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

class StudioBookingScreen extends StatefulWidget {
  const StudioBookingScreen({super.key});

  @override
  State<StudioBookingScreen> createState() => _StudioBookingScreenState();
}

class _StudioBookingScreenState extends State<StudioBookingScreen> {
  DateTime? start;
  DateTime? end;

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: start ?? now,
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (t == null) return;
    setState(() => start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _pickEnd() async {
    final base = start ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: base,
      lastDate: base.add(const Duration(days: 365)),
      initialDate: end ?? base,
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 11, minute: 0),
    );
    if (t == null) return;
    setState(() => end = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Not set';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m';
    }

  void _payAndBook() {
    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end time')),
      );
      return;
    }

    final upi = AppState.defaultUpiId ?? 'dancerang@upi';
    // Note: We’re NOT calling AppState.addBooking anymore (it doesn’t exist now).
    // Later, if you want to persist, we’ll add a Booking list + addBooking().

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Booking request sent'),
        content: Text(
          'Your slot request has been recorded.\n'
          'You can pay on UPI ID:\n$upi',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DanceRang'),
        centerTitle: true,
        actions: const [SizedBox(width: 16)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Rates
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Rates', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Weekday ₹1000/hr (₹800/hr if > 3h)'),
                Text('Weekend ₹1200/hr (₹1000/hr if > 3h)'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Rules
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• Outdoor shoes not allowed. Carry clean dance shoes.'),
                Text('• Full payment in advance to confirm the slot.'),
                Text('• Any property damage will be charged at actuals.'),
                Text('• Please arrive 10 minutes early for setup.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pickers
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Pick start'),
            subtitle: Text(_fmt(start)),
            onTap: _pickStart,
          ),
          ListTile(
            leading: const Icon(Icons.stop_rounded),
            title: const Text('Pick end'),
            subtitle: Text(_fmt(end)),
            onTap: _pickEnd,
          ),
          const SizedBox(height: 12),

          // Pay & Book button
          ElevatedButton.icon(
            onPressed: _payAndBook,
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Pay & Book'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 32),

          // My bookings (placeholder)
          const Text(
            'My Bookings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: const Text('No bookings yet.'),
          ),
        ],
      ),
    );
  }
}