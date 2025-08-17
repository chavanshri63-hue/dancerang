// lib/widgets/section_scaffold.dart
import 'package:flutter/material.dart';
import '../app_state.dart';

/// Shows one clean header everywhere:
/// AppBar: "DanceRang" (center)
/// Under it: big bold centered section title
class DRSectionScaffold extends StatelessWidget {
  const DRSectionScaffold({
    super.key,
    required this.sectionTitle,
    required this.child,
    this.actions,
  });

  final String sectionTitle;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);

    final right = <Widget>[
      ...?actions,
      IconButton(
        tooltip: 'Settings',
        onPressed: () {
          if (AppState.currentRole.value == UserRole.admin) {
            Navigator.pushNamed(context, '/settings');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Admin only')),
            );
          }
        },
        icon: const Icon(Icons.settings_rounded),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DanceRang'),
        centerTitle: true,
        actions: right,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(sectionTitle, style: titleStyle),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}