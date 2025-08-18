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
      showSectionTitle: false, // <<< hide the extra "Profile" heading
      actions: const [],
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(radius: 22, child: Icon(Icons.person)),
              title: ValueListenableBuilder<String>(
                valueListenable: AppState.memberName,
                builder: (_, name, __) => Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              subtitle: ValueListenableBuilder<UserRole>(
                valueListenable: AppState.currentRole,
                builder: (_, role, __) => Text('Role: ${role.name.toUpperCase()}'),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          ValueListenableBuilder<String?>(
            valueListenable: AppState.subscriptionPlan,
            builder: (_, plan, __) => Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.subscriptions_rounded),
                title: const Text('Online Subscription'),
                subtitle: Text(plan ?? '—'),
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Login / Switch role', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              _btn('Student', () => AppState.loginAs(UserRole.student)),
              _btn('Faculty', () => AppState.loginAs(UserRole.faculty)),
              _btn('Admin',   () => AppState.loginAs(UserRole.admin)),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: AppState.logout, child: const Text('Logout')),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => SizedBox(
        height: 44,
        child: ElevatedButton(onPressed: onTap, child: Text(label)),
      );
}