import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueDetailsScreen extends StatelessWidget {
  const RevenueDetailsScreen({super.key});

  Future<Map<String, String>> _loadPaymentDetails(
    Map<String, dynamic> data,
  ) async {
    final details = <String, String>{};
    final amount = (data['amount'] ?? 0).toString();
    final status = (data['status'] ?? '').toString();
    final methodRaw = (data['payment_method'] ??
            (status == 'pending_cash' ? 'cash' : 'online'))
        .toString();
    final method =
        methodRaw.toLowerCase() == 'cash' ? 'Cash' : 'Online';
    final paymentType = (data['payment_type'] ?? '').toString();
    final userId = (data['user_id'] ?? '').toString();
    final itemId = (data['item_id'] ?? '').toString();
    final ts = data['created_at'] ?? data['createdAt'] ?? data['updated_at'];

    details['amount'] = '₹$amount';
    details['status'] = status.isEmpty ? 'unknown' : status;
    details['method'] = method;
    details['type'] = paymentType.isEmpty ? 'unknown' : paymentType;
    details['time'] = _formatTimestamp(ts);

    String userName = 'Unknown';
    if (userId.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          userName =
              (userData['name'] ?? userData['displayName'] ?? 'Unknown')
                  .toString();
        }
      } catch (_) {}
    }
    details['user'] = userName;

    String itemName = '';
    final metadata = data['metadata'];
    if (metadata is Map) {
      itemName = (metadata['className'] ??
              metadata['class_name'] ??
              metadata['class'] ??
              '')
          .toString();
    }
    if (itemName.isEmpty && paymentType.contains('class') && itemId.isNotEmpty) {
      try {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(itemId)
            .get();
        if (classDoc.exists) {
          final classData = classDoc.data() ?? {};
          itemName = (classData['name'] ?? '').toString();
        }
      } catch (_) {}
    }
    if (itemName.isEmpty) {
      itemName = (data['description'] ?? data['payment_type'] ?? '—').toString();
    }
    details['item'] = itemName;

    return details;
  }

  String _formatTimestamp(dynamic raw) {
    if (raw is Timestamp) {
      final dt = raw.toDate();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} $hh:$mm';
    }
    return '—';
  }

  void _showPaymentDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1B1B1B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: FutureBuilder<Map<String, String>>(
            future: _loadPaymentDetails(data),
            builder: (context, snapshot) {
              final details = snapshot.data;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailRow('Paid By', details?['user'] ?? 'Loading...'),
                    _detailRow('Method', details?['method'] ?? 'Loading...'),
                    _detailRow('Class', details?['item'] ?? 'Loading...'),
                    _detailRow('Amount', details?['amount'] ?? 'Loading...'),
                    _detailRow('Status', details?['status'] ?? 'Loading...'),
                    _detailRow('Time', details?['time'] ?? 'Loading...'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

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
                              onTap: () => _showPaymentDetails(context, data),
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


