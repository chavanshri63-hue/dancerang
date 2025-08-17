// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/section_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DRSectionScaffold(
      sectionTitle: 'Profile',
      actions: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User card
          Card(
            child: ListTile(
              leading: const CircleAvatar(radius: 22, child: Icon(Icons.person)),
              title: ValueListenableBuilder<String>(
                valueListenable: AppState.memberName,
                builder: (_, name, __) => Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              subtitle: ValueListenableBuilder<UserRole>(
                valueListenable: AppState.currentRole,
                builder: (_, role, __) => Text('Role: ${role.name.toUpperCase()}'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dues
          ValueListenableBuilder<int>(
            valueListenable: AppState.pendingDue,
            builder: (_, due, __) => Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded),
                title: const Text('Pending Payment'),
                subtitle: Text('₹$due'),
                trailing: Text(due == 0 ? 'No dues' : 'Pay now'),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Subscription
          ValueListenableBuilder<String?>(
            valueListenable: AppState.subscriptionPlan,
            builder: (_, plan, __) => Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.subscriptions_rounded),
                title: const Text('Online Subscription'),
                subtitle: Text(plan ?? '—'),
                value: AppState.subscriptionActive.value,
                onChanged: (_) =>
                    AppState.subscriptionActive.value = !AppState.subscriptionActive.value,
              ),
            ),
          ),

          // ---------------- Admin tools block ----------------
          ValueListenableBuilder<UserRole>(
            valueListenable: AppState.currentRole,
            builder: (_, role, __) {
              if (role != UserRole.admin) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text('Admin tools', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.dashboard_customize_rounded),
                          title: const Text('Admin dashboard'),
                          subtitle: const Text('Stats, members, bookings'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pushNamed(context, '/admin'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.group_rounded),
                          title: const Text('Manage members'),
                          subtitle:
                              const Text('Search, filter, activate/deactivate'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pushNamed(context, '/members'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // ---------------------------------------------------

          const SizedBox(height: 12),
          Text('Login / Switch role', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _btn('Student', () => AppState.loginAs(UserRole.student)),
              _btn('Faculty', () => AppState.loginAs(UserRole.faculty)),
              _btn('Admin', () => AppState.loginAs(UserRole.admin)),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: AppState.logout, child: const Text('Logout')),
          const Divider(height: 32),

          // Settings list
          Card(
            child: Column(
              children: const [
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  subtitle: 'Manage alerts',
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy',
                  subtitle: 'Permissions & data',
                ),
                _SettingsTile(
                  icon: Icons.info_rounded,
                  title: 'About',
                  subtitle: 'Version & credits',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => SizedBox(
        height: 44,
        child: ElevatedButton(onPressed: onTap, child: Text(label)),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$title coming soon'))),
    );
  }
}