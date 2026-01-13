import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueDetailsScreen extends StatelessWidget {
  const RevenueDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        foregroundColor: Colors.white,
        title: const Text('Revenue (MTD)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('payments')
              .where('status', whereIn: ['success', 'paid'])
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            // Client-side filter for MTD using any available timestamp field
            final docs = allDocs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final ts = (data['created_at'] ?? data['createdAt'] ?? data['updated_at']);
              if (ts is Timestamp) {
                final dt = ts.toDate();
                return dt.isAfter(startOfMonth);
              }
              return true; // if no timestamp, include conservatively
            }).toList()
              ..sort((a, b) {
                final ad = ((a.data() as Map<String, dynamic>)['created_at'] ?? (a.data() as Map<String, dynamic>)['createdAt'] ?? (a.data() as Map<String, dynamic>)['updated_at']) as Timestamp?;
                final bd = ((b.data() as Map<String, dynamic>)['created_at'] ?? (b.data() as Map<String, dynamic>)['createdAt'] ?? (b.data() as Map<String, dynamic>)['updated_at']) as Timestamp?;
                return (bd?.toDate() ?? DateTime(1970)).compareTo(ad?.toDate() ?? DateTime(1970));
              });

            int total = 0;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              total += (data['amount'] ?? 0) as int;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Total: ₹$total', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text('No payments yet', style: TextStyle(color: Colors.white70)))
                      : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFF262626), height: 1),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final created = ((data['created_at'] ?? data['createdAt'] ?? data['updated_at']) as Timestamp?)?.toDate();
                            final when = created == null ? '' : '${created.day}/${created.month}/${created.year}  ${created.hour}:${created.minute.toString().padLeft(2, '0')}';
                            final desc = (data['description'] ?? data['payment_type'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              title: Text('₹${data['amount'] ?? 0}', style: const TextStyle(color: Colors.white)),
                              subtitle: Text('$desc  •  $when', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              trailing: Text((data['status'] ?? '').toString(), style: const TextStyle(color: Colors.green)),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


