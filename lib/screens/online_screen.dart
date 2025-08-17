import 'package:flutter/material.dart';
import '../widgets/section_scaffold.dart';

class OnlineScreen extends StatelessWidget {
  const OnlineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final styles = const [
      _Style('Hip Hop', Icons.directions_run_rounded),
      _Style('Bollywood', Icons.movie_creation_rounded),
      _Style('Contemporary', Icons.theaters_rounded),
      _Style('Classical', Icons.account_balance_rounded),
      _Style('Freestyle', Icons.music_note_rounded),
      _Style('Salsa', Icons.favorite_rounded),
    ];

    return DRSectionScaffold(
      sectionTitle: 'Online',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1,
        ),
        itemCount: styles.length,
        itemBuilder: (ctx, i) {
          final s = styles[i];
          return InkWell(
            onTap: () => Navigator.pushNamed(
              ctx,
              '/online/style',
              arguments: s.title,
            ),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(.18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s.icon, size: 32),
                  const SizedBox(height: 8),
                  Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Style {
  final String title;
  final IconData icon;
  const _Style(this.title, this.icon);
}