import 'package:flutter/material.dart';
import 'dart:ui';

class GlassmorphismAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onLeadingPressed;
  final PreferredSizeWidget? bottom;

  const GlassmorphismAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.onLeadingPressed,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B1D22).withOpacity(0.8),
            const Color(0xFF0B0C0E).withOpacity(0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
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
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 1),
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
            actions: actions ?? [],
            bottom: bottom,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    if (bottom != null) {
      return Size.fromHeight(kToolbarHeight + bottom!.preferredSize.height);
    }
    return const Size.fromHeight(kToolbarHeight);
  }
}
