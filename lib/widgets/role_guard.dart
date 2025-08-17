import 'package:flutter/material.dart';
import '../app_state.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allow,
    required this.child,
    this.fallback,
  });

  final bool Function(UserRole role) allow;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserRole>(
      valueListenable: AppState.currentRole,
      builder: (_, role, __) => allow(role) ? child : (fallback ?? const SizedBox.shrink()),
    );
  }
}