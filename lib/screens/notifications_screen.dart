import 'package:flutter/material.dart';
import '../app_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: AppState.notifications,
        builder: (_, items, __) {
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_rounded),
                title: Text(items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}