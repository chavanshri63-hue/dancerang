import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('DanceRang'),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          icon: const Icon(Icons.notifications_rounded),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Settings coming soon'))),
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    );
  }
}