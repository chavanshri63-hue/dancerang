// lib/screens/dashboard_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/section_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name = AppState.memberName.value;
    final t = Theme.of(context).textTheme;

    return DRSectionScaffold(
      sectionTitle: 'Dashboard',
      showSectionTitle: false, // <<< hide "Dashboard" title
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          icon: const Icon(Icons.notifications_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- HERO (Background) ----------
          ValueListenableBuilder<AppSettings>(
            valueListenable: AppState.settings,
            builder: (_, s, __) {
              final hasLocal = s.dashboardBgPath != null &&
                  s.dashboardBgPath!.isNotEmpty &&
                  File(s.dashboardBgPath!).existsSync();
              return Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: hasLocal
                        ? FileImage(File(s.dashboardBgPath!)) as ImageProvider
                        : const AssetImage('assets/images/placeholder_bg.jpeg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(.55), Colors.transparent],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: Text('Welcome, $name 👋',
                      style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // ---------- BANNERS (from settings.bannerItems) ----------
          ValueListenableBuilder<AppSettings>(
            valueListenable: AppState.settings,
            builder: (_, s, __) {
              final items = s.bannerItems;
              if (items.isEmpty) return const SizedBox.shrink();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (final b in items)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _BannerChip(title: b.title, path: b.path),
                      ),
                  ],
                ),
              );
            },
          ),

          // ---------- STATS ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This month attended'),
                        const SizedBox(height: 4),
                        Text('${AppState.attendedThisMonth()} classes',
                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last class'),
                        const SizedBox(height: 4),
                        Text(
                          AppState.lastClassDate()?.toLocal().toString().split(' ').first ?? '—',
                          style: t.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- GRID (added "Event Choreography") ----------
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _Tile(
                icon: Icons.qr_code_2_rounded,
                title: 'Attendance',
                subtitle: 'My QR / Scan',
                onTap: () => Navigator.pushNamed(context, '/attendance/qr'),
              ),
              _Tile(
                icon: Icons.event_available_rounded,
                title: "Today's Class",
                subtitle: 'View details',
                onTap: () => Navigator.pushNamed(context, '/classes'),
              ),
              _Tile(
                icon: Icons.campaign_rounded,
                title: 'Updates',
                subtitle: 'Photos & posts',
                onTap: () => Navigator.pushNamed(context, '/updates'),
              ),
              _Tile(
                icon: Icons.workspace_premium_rounded,
                title: 'Workshops',
                subtitle: 'Register & pay',
                onTap: () => Navigator.pushNamed(context, '/workshops'),
              ),
              _Tile(
                icon: Icons.celebration_rounded,
                title: 'Event Choreography',
                subtitle: 'School • Sangeet • Corporate',
                onTap: () => Navigator.pushNamed(context, '/events/choreo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({this.title, this.path});
  final String? title;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final hasFile = path != null && path!.isNotEmpty && File(path!).existsSync();
    return Chip(
      label: Text(
        (title ?? '').isEmpty ? '—' : title!,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      avatar: hasFile
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(path!), width: 24, height: 24, fit: BoxFit.cover),
            )
          : const Icon(Icons.image_rounded, size: 18),
      backgroundColor: AppTheme.cardLight,
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
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