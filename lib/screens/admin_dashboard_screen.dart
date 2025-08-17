import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/booking.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Members', value: '${AppState.totalMembers}')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Active Subs', value: '${AppState.activeSubscriptionsCount()}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<List<Booking>>(
                  valueListenable: AppState.studioBookings,
                  builder: (_, __, ___) => _StatCard(
                    label: 'Upcoming Bookings',
                    value: '${AppState.upcomingBookingsCount()}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/members'), // <-- OPEN MEMBERS
                  borderRadius: BorderRadius.circular(12),
                  child: _StatCard(
                    label: 'Active Members',
                    value: '${AppState.activeMembers.length}',
                    footer: 'Manage Members →', // hint
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Quick Actions', style: text.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text('Members'),
              subtitle: const Text('View, filter, add, toggle active/inactive'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/members'), // <-- also here
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.footer});
  final String label;
  final String value;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(footer!, style: t.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }
}