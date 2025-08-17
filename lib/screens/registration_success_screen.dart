import 'package:flutter/material.dart';

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registration')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 72),
              const SizedBox(height: 16),
              Text('You’re registered!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Workshop: $title'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              )
            ],
          ),
        ),
      ),
    );
  }
}