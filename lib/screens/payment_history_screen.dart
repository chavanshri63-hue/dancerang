import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Query query = FirebaseFirestore.instance
          .collection('payments')
          .where('user_id', isEqualTo: user.uid);

      if (_selectedFilter != 'all') {
        query = query.where('status', isEqualTo: _selectedFilter);
      }

      final snapshot = await query.orderBy('created_at', descending: true).get();

      List<Map<String, dynamic>> payments = [];
      double totalAmount = 0;
      int successfulPayments = 0;
      int pendingPayments = 0;
      int failedPayments = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        payments.add({
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'status': data['status'] ?? 'pending',
          'type': data['payment_type'] ?? 'unknown',
          'description': data['description'] ?? '',
          'createdAt': data['created_at'],
          'paymentMethod': data['payment_method'] ?? 'Razorpay',
        });

        if (data['status'] == 'success' || data['status'] == 'paid') {
          totalAmount += (data['amount'] ?? 0.0).toDouble();
          successfulPayments++;
        } else if (data['status'] == 'pending' || data['status'] == 'pending_cash') {
          pendingPayments++;
        } else if (data['status'] == 'failed' || data['status'] == 'cancelled') {
          failedPayments++;
        }
      }

      setState(() {
        _payments = payments;
        _summary = {
          'totalAmount': totalAmount,
          'successfulPayments': successfulPayments,
          'pendingPayments': pendingPayments,
          'failedPayments': failedPayments,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading payment history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Payment History',
        actions: [
          DropdownButton<String>(
            value: _selectedFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'success', child: Text('Successful')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'failed', child: Text('Failed')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFilter = value!;
              });
              _loadPaymentHistory();
            },
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  _buildSummaryCards(),
                  const SizedBox(height: 20),
                  
                  // Payment List
                  _buildPaymentList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          'Total Spent',
          '₹${_summary['totalAmount'].toStringAsFixed(0)}',
          Icons.currency_rupee,
          const Color(0xFF10B981),
        ),
        _buildSummaryCard(
          'Successful',
          '${_summary['successfulPayments']}',
          Icons.check_circle,
          const Color(0xFF4F46E5),
        ),
        _buildSummaryCard(
          'Pending',
          '${_summary['pendingPayments']}',
          Icons.pending,
          const Color(0xFFF59E0B),
        ),
        _buildSummaryCard(
          'Failed',
          '${_summary['failedPayments']}',
          Icons.cancel,
          const Color(0xFFE53935),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentList() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Payments',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_payments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No payments found',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payments.length,
                itemBuilder: (context, index) {
                  final payment = _payments[index];
                  return _buildPaymentItem(payment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final status = payment['status'] as String;
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'success':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
        break;
      case 'failed':
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.white70;
        statusIcon = Icons.help;
    }

    final createdAt = payment['createdAt'] as Timestamp?;
    final date = createdAt?.toDate() ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['description'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${payment['type']} • ${payment['paymentMethod']}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${payment['amount'].toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
