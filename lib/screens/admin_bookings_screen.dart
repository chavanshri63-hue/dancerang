import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_choreography_chat_screen.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});
  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Bookings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFE53935),
          tabs: const [
            Tab(text: 'Event'),
            Tab(text: 'Studio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BookingsList(
            stream: FirebaseFirestore.instance
                .collection('eventChoreoBookings')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            type: 'event',
          ),
          _BookingsList(
            stream: FirebaseFirestore.instance
                .collection('studioBookings')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            type: 'studio',
          ),
        ],
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String type; // 'event' | 'studio'
  const _BookingsList({required this.stream, required this.type});

  void _showEventBookingDetails(BuildContext context, Map<String, dynamic> data) {
    final name = (data['contactName'] as String?) ?? '—';
    final phone = (data['phone'] as String?) ?? '—';
    final packageName = (data['packageName'] as String?) ?? 'Event Booking';
    final date = (data['eventDate'] is Timestamp) ? (data['eventDate'] as Timestamp).toDate() : null;
    final totalAmount = (data['totalAmount'] as int?) ?? 0;
    final paidAmount = (data['advanceAmount'] as int?) ?? 0;
    final finalAmount = (data['finalAmount'] as int?) ?? 0;
    final pendingAmount = finalAmount > 0 ? finalAmount : (totalAmount - paidAmount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Event Booking Details', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Package: $packageName', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Name: $name', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Phone: $phone', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              date != null ? 'Event Date: ${date.day}/${date.month}/${date.year}' : 'Event Date: —',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text('Total Amount: ₹$totalAmount', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text('Paid Amount: ₹$paidAmount', style: const TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 4),
            Text('Pending Amount: ₹${pendingAmount < 0 ? 0 : pendingAmount}', style: const TextStyle(color: Colors.orangeAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStudioBookingDetails(BuildContext context, Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? '—';
    final phone = (data['phone'] as String?) ?? '—';
    final branch = (data['branch'] as String?) ?? '—';
    final date = (data['date'] is Timestamp) ? (data['date'] as Timestamp).toDate() : null;
    final time = (data['time'] as String?) ?? '';
    final totalAmount = (data['totalAmount'] as int?) ?? 0;
    final paidAmount = (data['advanceAmount'] as int?) ?? 0;
    final finalAmount = (data['finalAmount'] as int?) ?? 0;
    final pendingAmount = finalAmount > 0 ? finalAmount : (totalAmount - paidAmount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Studio Booking Details', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Phone: $phone', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              date != null ? 'Date: ${date.day}/${date.month}/${date.year}' : 'Date: —',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text('Time: $time', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Branch: $branch', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Total Amount: ₹$totalAmount', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text('Paid Amount: ₹$paidAmount', style: const TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 4),
            Text('Pending Amount: ₹${pendingAmount < 0 ? 0 : pendingAmount}', style: const TextStyle(color: Colors.orangeAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFF9800);
      case 'completed':
        return const Color(0xFF4F46E5);
      default:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white70));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No bookings yet', style: TextStyle(color: Colors.white70)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final status = (data['status'] as String?) ?? 'pending';
            final createdAt = (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : null;
            final title = type == 'event'
                ? ((data['packageName'] as String?) ?? 'Event Booking')
                : ((data['studioName'] as String?) ?? 'Studio Booking');
            final subtitle = type == 'event'
                ? (data['contactName'] as String? ?? data['userId'] as String? ?? '')
                : (data['userId'] as String? ?? '');

            return GestureDetector(
              onTap: type == 'studio'
                  ? () => _showStudioBookingDetails(context, data)
                  : () => _showEventBookingDetails(context, data),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          if (subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                          if (createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Created • ${createdAt.day}/${createdAt.month}/${createdAt.year}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                    if (type == 'event') ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Open Chat',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventChoreoChatScreen(
                                bookingId: (data['bookingId'] as String?) ?? docs[i].id,
                                isAdmin: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat, color: Colors.white70, size: 18),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _statusColor(status).withValues(alpha: 0.5)),
                      ),
                      child: Text(status.toUpperCase(), style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


