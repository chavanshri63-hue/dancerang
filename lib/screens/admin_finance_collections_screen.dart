import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AdminFinanceCollectionsScreen extends StatefulWidget {
  const AdminFinanceCollectionsScreen({super.key});

  @override
  State<AdminFinanceCollectionsScreen> createState() => _AdminFinanceCollectionsScreenState();
}

class _AdminFinanceCollectionsScreenState extends State<AdminFinanceCollectionsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = '30 days';
  String _selectedFilter = 'all';
  
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    
    try {
      // Calculate date range
      final now = DateTime.now();
      final days = _getDaysFromPeriod(_selectedPeriod);
      final startDate = now.subtract(Duration(days: days));

      // Load payments (using payments collection, not transactions)
      Query query = FirebaseFirestore.instance
          .collection('payments')
          .where('created_at', isGreaterThan: Timestamp.fromDate(startDate));

      if (_selectedFilter != 'all') {
        // Map filter values to actual payment statuses
        if (_selectedFilter == 'success') {
          // For success, include both 'success' and 'paid' statuses
          query = query.where('status', whereIn: ['success', 'paid']);
        } else {
          query = query.where('status', isEqualTo: _selectedFilter);
        }
      }

      final paymentsSnapshot = await query.orderBy('created_at', descending: true).get();

      // Load pending payments separately
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('status', whereIn: ['pending', 'pending_cash'])
          .get();

      // Load subscriptions
      final subscriptionsSnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      // Get all user IDs to fetch names
      final Set<String> userIds = {};
      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['user_id'] != null) {
          userIds.add(data['user_id'] as String);
        }
      }
      for (var doc in pendingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['user_id'] != null) {
          userIds.add(data['user_id'] as String);
        }
      }

      // Fetch user names
      final Map<String, String> userNameMap = {};
      for (var userId in userIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            userNameMap[userId] = (userData?['name'] ?? userData?['displayName'] ?? 'Unknown') as String;
          }
        } catch (e) {
          userNameMap[userId] = 'Unknown';
        }
      }

      // Process payments
      List<Map<String, dynamic>> transactions = [];
      double totalRevenue = 0;
      double totalPending = 0;
      int successfulPayments = 0;
      int failedPayments = 0;

      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['user_id'] as String?;
        final userName = userId != null ? userNameMap[userId] ?? 'Unknown' : 'Unknown';
        
        transactions.add({
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'status': data['status'] ?? 'pending',
          'type': data['payment_type'] ?? 'unknown',
          'userName': userName,
          'createdAt': data['created_at'],
          'description': data['description'] ?? '',
        });

        final status = data['status'] as String? ?? 'pending';
        if (status == 'success' || status == 'paid') {
          totalRevenue += (data['amount'] ?? 0.0).toDouble();
          successfulPayments++;
        } else if (status == 'pending' || status == 'pending_cash') {
          totalPending += (data['amount'] ?? 0.0).toDouble();
        } else if (status == 'failed' || status == 'cancelled') {
          failedPayments++;
        }
      }

      // Process pending payments
      List<Map<String, dynamic>> pendingPayments = [];
      for (var doc in pendingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['user_id'] as String?;
        final userName = userId != null ? userNameMap[userId] ?? 'Unknown' : 'Unknown';
        
        pendingPayments.add({
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'userName': userName,
          'createdAt': data['created_at'],
          'description': data['description'] ?? '',
        });
      }

      // Process subscriptions
      List<Map<String, dynamic>> subscriptions = [];
      for (var doc in subscriptionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        subscriptions.add({
          'id': doc.id,
          'planName': data['planName'] ?? 'Unknown Plan',
          'amount': data['amount'] ?? 0.0,
          'status': data['status'] ?? 'active',
          'userName': data['userName'] ?? 'Unknown',
          'startDate': data['startDate'],
          'endDate': data['endDate'],
        });
      }

      setState(() {
        _summary = {
          'totalRevenue': totalRevenue,
          'totalPending': totalPending,
          'successfulPayments': successfulPayments,
          'failedPayments': failedPayments,
          'totalTransactions': transactions.length,
          'activeSubscriptions': subscriptions.where((s) => s['status'] == 'active').length,
        };
        _transactions = transactions;
        _pendingPayments = pendingPayments;
        _subscriptions = subscriptions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading finance data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _getDaysFromPeriod(String period) {
    switch (period) {
      case '7 days':
        return 7;
      case '30 days':
        return 30;
      case '90 days':
        return 90;
      case '1 year':
        return 365;
      default:
        return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Finance & Collections',
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            items: const [
              DropdownMenuItem(value: '7 days', child: Text('7 days')),
              DropdownMenuItem(value: '30 days', child: Text('30 days')),
              DropdownMenuItem(value: '90 days', child: Text('90 days')),
              DropdownMenuItem(value: '1 year', child: Text('1 year')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _loadFinanceData();
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
                  
                  // Filter Tabs
                  _buildFilterTabs(),
                  const SizedBox(height: 20),
                  
                  // Content based on filter
                  _buildContent(),
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
      childAspectRatio: 1.2,
      children: [
        _buildSummaryCard(
          'Total Revenue',
          '₹${(((_summary['totalRevenue'] ?? 0) as num).toDouble()).toStringAsFixed(0)}',
          Icons.currency_rupee,
          const Color(0xFF10B981),
        ),
        _buildSummaryCard(
          'Pending Amount',
          '₹${(((_summary['totalPending'] ?? 0) as num).toDouble()).toStringAsFixed(0)}',
          Icons.pending,
          const Color(0xFFF59E0B),
        ),
        _buildSummaryCard(
          'Successful Payments',
          '${_summary['successfulPayments'] ?? 0}',
          Icons.check_circle,
          const Color(0xFF4F46E5),
        ),
        _buildSummaryCard(
          'Active Subscriptions',
          '${_summary['activeSubscriptions'] ?? 0}',
          Icons.subscriptions,
          const Color(0xFFE53935),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterTab('all', 'All Transactions'),
              const SizedBox(width: 8),
              _buildFilterTab('success', 'Successful'),
              const SizedBox(width: 8),
              _buildFilterTab('pending', 'Pending'),
              const SizedBox(width: 8),
              _buildFilterTab('failed', 'Failed'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        _loadFinanceData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE53935) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFE53935) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedFilter == 'all') {
      return _buildTransactionsList();
    } else if (_selectedFilter == 'pending') {
      return _buildPendingPaymentsList();
    } else {
      return _buildTransactionsList();
    }
  }

  Widget _buildTransactionsList() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No transactions found',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return _buildTransactionItem(transaction);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPaymentsList() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Payments',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_pendingPayments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No pending payments',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingPayments.length,
                itemBuilder: (context, index) {
                  final payment = _pendingPayments[index];
                  return _buildPendingPaymentItem(payment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final status = transaction['status'] as String;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['userName'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  transaction['description'],
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${transaction['amount'].toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentItem(Map<String, dynamic> payment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.pending, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['userName'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  payment['description'],
                  style: const TextStyle(color: Colors.white70),
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
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _approvePayment(payment['id']),
                    child: const Text('Approve', style: TextStyle(color: Colors.green)),
                  ),
                  TextButton(
                    onPressed: () => _rejectPayment(payment['id']),
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approvePayment(String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({'status': 'approved'});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadFinanceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectPayment(String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({'status': 'rejected'});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment rejected'),
          backgroundColor: Colors.orange,
        ),
      );
      
      _loadFinanceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
