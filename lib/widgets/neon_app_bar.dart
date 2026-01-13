import 'package:flutter/material.dart';

class NeonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onLeadingPressed;

  const NeonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.onLeadingPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB71C1C), // Dark red
            Color(0xFFD32F2F), // Medium red
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.6),
            blurRadius: 20.0,
            spreadRadius: 2.0,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFFFF5722).withOpacity(0.4),
            blurRadius: 30.0,
            spreadRadius: 1.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Color(0xFFE53935),
                blurRadius: 8.0,
                offset: Offset(0, 0),
              ),
              Shadow(
                color: Color(0xFFFF5722),
                blurRadius: 16.0,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
        leading: leading ?? (onLeadingPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onLeadingPressed,
              )
            : null),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
