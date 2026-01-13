import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _loading = false; });
      return;
    }
    // Initial fetch
    final history = await PaymentService.getPaymentHistory(user.uid);
    setState(() {
      _payments = history;
      _loading = false;
      _stream = FirebaseFirestore.instance
          .collection('payments')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: const GlassmorphismAppBar(title: 'Invoice History'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _stream == null
              ? const Center(child: Text('No data', style: TextStyle(color: Colors.white70)))
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _payments.isEmpty) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    final items = docs.isEmpty ? _payments : docs.map((d) => {'id': d.id, ...d.data()}).toList();
                    if (items.isEmpty) {
                      return const Center(child: Text('No invoices yet', style: TextStyle(color: Colors.white70)));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final p = items[index];
                        final ts = p['created_at'];
                        final created = ts is Timestamp ? ts.toDate() : DateTime.now();
                        final amount = p['amount'] ?? 0;
                        final status = (p['status'] ?? '').toString();
                        final desc = (p['description'] ?? 'Payment').toString();
                        return _invoiceTile(
                          id: p['id'] ?? '',
                          title: desc,
                          subtitle: '${created.day}/${created.month}/${created.year}',
                          amount: amount,
                          status: status,
                        );
                      },
                    );
                  },
                ),
    );
  }

  Widget _invoiceTile({required String id, required String title, required String subtitle, required int amount, required String status}) {
    final color = PaymentService.getPaymentStatusColor(status);
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.12))),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.receipt_long, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹$amount', style: const TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}


