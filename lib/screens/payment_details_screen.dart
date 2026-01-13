import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';
import 'receipt_screen.dart';

class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic>? _nextPayment;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paymentsSub;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
    _listenPaymentsLive();
    
    // Listen to payment success events for real-time updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && mounted) {
        // Refresh payment data when payment succeeds
        _loadPaymentData();
      }
    });
  }

  @override
  void dispose() {
    _paymentsSub?.cancel();
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPaymentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load real payment data from Firestore
      final paymentHistory = await PaymentService.getPaymentHistory(user.uid);
      await PaymentService.getPendingPayments(user.uid);
      
      setState(() {
        _payments = paymentHistory.map((payment) => {
          'id': payment['id'],
          'amount': payment['amount'],
          'dueDate': (payment['created_at'] as Timestamp).toDate(),
          'status': payment['status'],
          'description': payment['description'],
          'type': payment['payment_type'],
          'receipt': payment['receipt'],
        }).toList();

        // Strictly real data only: do not inject mock payments

        _nextPayment = _payments.firstWhere(
          (payment) => payment['status'] == 'pending',
          orElse: () => _payments.isNotEmpty ? _payments.first : {},
        );
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payment data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _listenPaymentsLive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _paymentsSub = FirebaseFirestore.instance
        .collection('payments')
        .where('user_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _payments = items;
          
          // Update next payment
          _nextPayment = _payments.firstWhere(
            (payment) => payment['status'] == 'pending',
            orElse: () => _payments.isNotEmpty ? _payments.first : {},
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Payment Details',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : RefreshIndicator(
              onRefresh: _loadPaymentData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Next Payment Due Card
                    if (_nextPayment != null) ...[
                      _buildNextPaymentCard(),
                      const SizedBox(height: 20),
                    ],
                    
                    // Payment History
                    const Text(
                      'Payment History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF9FAFB),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Payment List
                    ..._payments.map((payment) => _buildPaymentCard(payment)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNextPaymentCard() {
    final payment = _nextPayment!;
    final daysUntilDue = payment['dueDate'].difference(DateTime.now()).inDays;
    final isOverdue = daysUntilDue < 0;
    
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 8,
      shadowColor: const Color(0xFFE53935).withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? Colors.red : const Color(0xFFE53935),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isOverdue ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFE53935).withValues(alpha: 0.1),
              Theme.of(context).cardColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOverdue ? Colors.red.withValues(alpha: 0.2) : const Color(0xFFE53935).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOverdue ? Icons.warning : Icons.payment,
                      color: isOverdue ? Colors.red : const Color(0xFFE53935),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOverdue ? 'Overdue Payment' : 'Next Payment Due',
                          style: TextStyle(
                            color: isOverdue ? Colors.red : const Color(0xFFE53935),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment['description'],
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${payment['amount']}',
                        style: const TextStyle(
                          color: Color(0xFFF9FAFB),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isOverdue 
                            ? 'Overdue by ${-daysUntilDue} days'
                            : daysUntilDue == 0 
                                ? 'Due today'
                                : 'Due in $daysUntilDue days',
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _showPaymentDialog(payment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOverdue ? Colors.red : const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isOverdue ? 'Pay Now' : 'Pay Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status'];
    final isPaid = status == 'success' || status == 'paid';
    final isOverdue = status == 'overdue';
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (isPaid) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Paid';
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'Overdue';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      statusText = 'Pending';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment['description'],
                    style: const TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${_formatDate(payment['dueDate'])}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${payment['amount']}',
                  style: const TextStyle(
                    color: Color(0xFFF9FAFB),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isPaid) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      _openReceipt(payment);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                      foregroundColor: Colors.green,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('View Receipt'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openReceipt(Map<String, dynamic> payment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(payment: payment),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showPaymentDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text(
          'Payment Options',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Amount: ₹${payment['amount']}',
              style: const TextStyle(
                color: Color(0xFFF9FAFB),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              payment['description'],
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose payment method:',
              style: TextStyle(color: Color(0xFFF9FAFB)),
            ),
            const SizedBox(height: 12),
            _buildPaymentOption('UPI', Icons.phone_android, Colors.blue),
            const SizedBox(height: 8),
            _buildPaymentOption('Card', Icons.credit_card, Colors.orange),
            const SizedBox(height: 8),
            _buildPaymentOption('Net Banking', Icons.account_balance, Colors.green),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processPayment(payment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(color: Color(0xFFF9FAFB)),
          ),
        ],
      ),
    );
  }

  void _processPayment(Map<String, dynamic> payment) async {
    // Show processing indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Processing payment...'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Generate unique payment ID
      final paymentId = PaymentService.generatePaymentId();
      // Use amount directly in rupees
      final int amountRupees = payment['amount'] as int;
      
      // Process payment using PaymentService
      final result = await PaymentService.processPayment(
        paymentId: paymentId,
        amount: amountRupees,
        description: payment['description'] as String,
        paymentType: payment['type'] as String,
        itemId: payment['id'] as String,
        metadata: {
          'due_date': payment['dueDate'],
          'original_payment_id': payment['id'],
        },
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment initiated. Complete the payment in Razorpay.'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Refresh payment data
          await _loadPaymentData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${result['error']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
