import 'package:flutter/material.dart';

enum PaymentChoice { online, cash }

class PaymentOptionDialog extends StatelessWidget {
  const PaymentOptionDialog({super.key});

  static Future<PaymentChoice?> show(BuildContext context) {
    return showDialog<PaymentChoice>(
      context: context,
      builder: (context) => const PaymentOptionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Choose Payment Method', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Select how you want to pay for this item.', style: TextStyle(color: Colors.white70)),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, PaymentChoice.online),
          child: const Text('Pay Online'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.pop(context, PaymentChoice.cash),
          icon: const Icon(Icons.payments_outlined, color: Colors.orange),
          label: const Text('Mark as Paid Cash', style: TextStyle(color: Colors.orange)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}


