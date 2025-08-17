import 'package:flutter/material.dart';
import '../services/payments_service.dart';

class WorkshopDetailScreen extends StatelessWidget {
  const WorkshopDetailScreen({
    super.key,
    required this.title,
    required this.dateLabel,
    required this.priceInr,
    required this.upiId,
  });

  final String title;       // e.g. "Bollywood Basics"
  final String dateLabel;   // e.g. "24 Aug · 5–7 PM"
  final int priceInr;       // e.g. 999
  final String upiId;       // e.g. "dancerang@upi"

  Future<void> _pay(BuildContext context, {String? preferredApp}) async {
    final ok = await PaymentsService.payForWorkshop(
      upiId: upiId,
      name: title,
      amountInr: priceInr,
      note: '$title · $dateLabel',
      preferredApp: preferredApp, // 'gpay' | 'phonepe' | 'paytm' | 'bhim' | 'tez' | null
    );

    final msg = ok ? 'Opening payment app…' : 'No supported UPI app found.';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Workshop details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(title, style: text.titleMedium),
              subtitle: Text(dateLabel),
              trailing: Text('₹$priceInr', style: text.titleMedium),
            ),
          ),
          const SizedBox(height: 16),
          Text('Pay with', style: text.titleMedium),
          const SizedBox(height: 8),

          // Quick app-specific buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PayChip(label: 'GPay', icon: Icons.account_balance_wallet, onTap: () => _pay(context, preferredApp: 'gpay')),
              _PayChip(label: 'PhonePe', icon: Icons.phone_android, onTap: () => _pay(context, preferredApp: 'phonepe')),
              _PayChip(label: 'Paytm', icon: Icons.payment, onTap: () => _pay(context, preferredApp: 'paytm')),
              _PayChip(label: 'BHIM', icon: Icons.account_balance, onTap: () => _pay(context, preferredApp: 'bhim')),
            ],
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _pay(context), // generic fallback
            child: const Text('Pay with any UPI app'),
          ),
        ],
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}