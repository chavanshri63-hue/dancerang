// lib/widgets/section_scaffold.dart
import 'package:flutter/material.dart';

/// Shows one clean header everywhere:
/// AppBar: "DanceRang"
/// Optional centered section title (can be hidden)
class DRSectionScaffold extends StatelessWidget {
  const DRSectionScaffold({
    super.key,
    required this.sectionTitle,
    required this.child,
    this.actions,
    this.showSectionTitle = true,
  });

  final String sectionTitle;
  final Widget child;
  final List<Widget>? actions;
  final bool showSectionTitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DanceRang'),
        centerTitle: true,
        actions: actions,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            if (showSectionTitle) ...[
              Align(
                alignment: Alignment.center,
                child: Text(sectionTitle, style: titleStyle),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}