import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';
import 'payment_history_screen.dart';
import 'reminder_management_screen.dart';

class PaymentReminderScreen extends StatefulWidget {
  const PaymentReminderScreen({super.key});

  @override
  State<PaymentReminderScreen> createState() => _PaymentReminderScreenState();
}

class _PaymentReminderScreenState extends State<PaymentReminderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to payment success events for real-time updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && mounted) {
        // Force rebuild when payment succeeds
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: const GlassmorphismAppBar(
        title: 'Payment Reminders',
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Please login to view payment reminders',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('enrollments')
                  .where('status', isEqualTo: 'enrolled')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE53935),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorState();
                }

                final enrollments = snapshot.data?.docs ?? [];
                if (enrollments.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter enrollments that need payment
                final paymentDueEnrollments = enrollments.where((doc) {
                  final data = doc.data();
                  final completedSessions = data['completedSessions'] ?? 0;
                  final totalSessions = data['totalSessions'] ?? 8;
                  return (totalSessions - completedSessions) <= 1;
                }).toList();

                if (paymentDueEnrollments.isEmpty) {
                  return _buildNoPaymentDueState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: paymentDueEnrollments.length,
                  itemBuilder: (context, index) {
                    final enrollment = paymentDueEnrollments[index];
                    final data = enrollment.data();
                    return _buildPaymentReminderCard(enrollment.id, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFE53935),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Payments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Failed to load payment information',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.school_outlined,
            color: Color(0xFF6B7280),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Classes Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You are not enrolled in any classes',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPaymentDueState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF10B981),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'All Payments Up to Date!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No payments are due at this time',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentReminderCard(String enrollmentId, Map<String, dynamic> data) {
    final className = data['className'] ?? 'Unknown Class';
    final completedSessions = data['completedSessions'] ?? 5;
    final totalSessions = data['totalSessions'] ?? 8;
    final paymentAmount = data['paymentAmount'] ?? 2500;
    final remainingSessions = totalSessions - completedSessions;
    final isPaymentDue = remainingSessions <= 1;
    final nextPaymentDue = data['nextPaymentDue']?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPaymentDue 
              ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
              : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPaymentDue ? Colors.red : Colors.blue).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPaymentDue ? Icons.warning_rounded : Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaymentDue ? 'Payment Due Now!' : 'Payment Due Soon',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPaymentDue ? 'DUE' : 'SOON',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Session Progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completedSessions/$totalSessions sessions completed',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completedSessions / totalSessions,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Payment Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Amount',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹$paymentAmount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (nextPaymentDue != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Due: ${_formatDate(nextPaymentDue)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _handlePayment(enrollmentId, className, paymentAmount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isPaymentDue ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPaymentHistory(enrollmentId),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('History'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setReminder(enrollmentId),
                    icon: const Icon(Icons.notifications_outlined, size: 16),
                    label: const Text('Remind Later'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 7) return 'In $difference days';
    if (difference < 30) return 'In ${(difference / 7).round()} weeks';
    return 'In ${(difference / 30).round()} months';
  }

  void _handlePayment(String enrollmentId, String className, int amount) {
    // Navigate to payment screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Processing payment for $className - ₹$amount'),
        backgroundColor: const Color(0xFF3B82F6),
        action: SnackBarAction(
          label: 'View Details',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to payment details
          },
        ),
      ),
    );
  }

  void _showPaymentHistory(String enrollmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentHistoryScreen(),
      ),
    );
  }

  void _setReminder(String enrollmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReminderManagementScreen(),
      ),
    );
  }
}
