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

            return Container(
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
            );
          },
        );
      },
    );
  }
}


