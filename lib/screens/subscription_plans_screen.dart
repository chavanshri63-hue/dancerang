import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/iap_service.dart';
import '../services/online_subscription_service.dart';
import '../widgets/glassmorphism_app_bar.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Subscription Plans',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('subscription_plans')
            .orderBy('priority', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
          }

        final plans = (snapshot.data?.docs ?? [])
            .where((doc) => (doc.data()['active'] ?? true) == true)
            .where((doc) => (doc.data()['billingCycle'] ?? 'monthly').toString() == 'monthly')
            .toList();
          if (plans.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.subscriptions, size: 64, color: Color(0xFF6B7280)),
                  SizedBox(height: 16),
                  Text(
                    'No subscription plans available',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final plan = plans[index].data();
              final planId = plans[index].id;
              return _SubscriptionPlanCard(
                planId: planId,
                name: plan['name'] ?? 'Plan',
                price: plan['price'] ?? 0,
                billingCycle: plan['billingCycle'] ?? 'monthly',
                description: plan['description'] ?? '',
                priority: plan['priority'] ?? 0,
                trialDays: plan['trialDays'] ?? 0,
                onSubscribe: () => _handleSubscribe(planId, plan),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleSubscribe(String planId, Map<String, dynamic> plan) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Please login to subscribe');
        return;
      }

      // Single-plan purchase flow for online videos.
      final result = await OnlineSubscriptionService.purchaseMonthly();

      if (result['success'] == true) {
        _showSuccess('Complete the purchase to activate your subscription.');
      } else {
        _showError(result['message'] ?? 'Could not start subscription purchase.');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final String planId;
  final String name;
  final int price;
  final String billingCycle;
  final String description;
  final int priority;
  final int trialDays;
  final VoidCallback onSubscribe;

  const _SubscriptionPlanCard({
    required this.planId,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.description,
    required this.priority,
    required this.trialDays,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = priority == 1;
    final cycleText = billingCycle == 'annual' ? 'year' : 
                     billingCycle == 'quarterly' ? 'quarter' : 'month';

    return Card(
      elevation: isPopular ? 8 : 4,
      shadowColor: isPopular ? const Color(0xFFE53935).withOpacity(0.3) : const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPopular ? const Color(0xFFE53935).withOpacity(0.5) : const Color(0xFF4F46E5).withOpacity(0.22),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: isPopular ? BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE53935).withOpacity(0.1),
              const Color(0xFF4F46E5).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ) : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE53935).withOpacity(0.5)),
                                ),
                                child: const Text(
                                  'POPULAR',
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹$price',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/$cycleText',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.subscriptions,
                      color: Color(0xFF4F46E5),
                      size: 24,
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              if (trialDays > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Text(
                    '$trialDays days free trial',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? const Color(0xFFE53935) : const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
