import 'dart:io';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSta.settings,
      builder: (_, settings, __) {
        final bgPath = settings.dashboardBgPath;
        final hasBg = bgPath != null && bgPath.isNotEmpty && File(bgPath).existsSync();

        return Scaffold(
          appBar: AppBar(
            title: const Text('DanceRang'),
            centerTitle: true,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Hero background
              if (hasBg)
                Image.file(File(bgPath!), fit: BoxFit.cover)
              else
                Image.asset('assets/images/placeholder_bg.jpg', fit: BoxFit.cover),

              // Dark overlay for readability
              Container(color: Colors.black.withOpacity(0.35)),

              // Content
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    // Welcome strip
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.card.withOpacity(.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.handshake_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Welcome, ${AppState.memberName.value} 👋',
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // GRID (no Profile tile here; Event Choreography is a separate tile)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _DashTile(
                          icon: Icons.qr_code_2_rounded,
                          title: 'Attendance',
                          subtitle: 'My QR / Scan',
                          onTap: () => Navigator.pushNamed(context, '/attendance/qr'),
                        ),
                        _DashTile(
                          icon: Icons.event_available_rounded,
                          title: "Today's Class",
                          subtitle: 'View details',
                          onTap: () => Navigator.pushNamed(context, '/classes'),
                        ),
                        _DashTile(
                          icon: Icons.campaign_rounded,
                          title: 'Updates',
                          subtitle: 'Photos & posts',
                          onTap: () => Navigator.pushNamed(context, '/updates'),
                        ),
                        _DashTile(
                          icon: Icons.workspace_premium_rounded,
                          title: 'Workshops',
                          subtitle: 'Register & pay',
                          onTap: () => Navigator.pushNamed(context, '/workshops'),
                        ),
                        // NEW: Event Choreography (separate box)
                        _DashTile(
                          icon: Icons.celebration_rounded,
                          title: 'Event Choreography',
                          subtitle: 'School • Sangeet • Corporate',
                          onTap: () => Navigator.pushNamed(context, '/event-choreo'),
                        ),
                        // Studio kept accessible via bottom tab, but you can keep a tile too if you want:
                        _DashTile(
                          icon: Icons.meeting_room_rounded,
                          title: 'Studio Booking',
                          subtitle: 'Pay & book',
                          onTap: () => Navigator.pushNamed(context, '/studio'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Content cards (admin-manageable)
                    if (settings.bannerItems.isNotEmpty)
                      Text('Highlights', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (settings.bannerItems.isNotEmpty) const SizedBox(height: 8),

                    if (settings.bannerItems.isNotEmpty)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final b in settings.bannerItems)
                            _ContentCard(title: b.title ?? '—', path: b.path),
                        ],
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),

          // Admin-only quick manage (to edit background + cards)
          floatingActionButton: ValueListenableBuilder(
            valueListenable: AppState.currentRole,
            builder: (_, role, __) {
              final isAdmin = role.toString().contains('admin');
              if (!isAdmin) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                onPressed: () => Navigator.pushNamed(context, '/dashboard/manage'),
                icon: const Icon(Icons.settings_suggest_rounded),
                label: const Text('Manage'),
              );
            },
          ),
        );
      },
    );
  }
}

class _DashTile extends StatelessWidget {
  const _DashTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card.withOpacity(.8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.red.withOpacity(.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.red, size: 22),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.title, this.path});
  final String title;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final has = path != null && path!.isNotEmpty && File(path!).existsSync();
    return SizedBox(
      width: 260,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: has
                    ? Image.file(File(path!), fit: BoxFit.cover)
                    : Image.asset('assets/images/placeholder_bg.jpg', fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}