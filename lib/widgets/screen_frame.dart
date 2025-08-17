import 'package:flutter/material.dart';

/// Common wrapper so every screen stays below the notch/status bar,
/// with uniform horizontal padding and scroll support when needed.
class ScreenFrame extends StatelessWidget {
  final Widget child;
  final bool scrollable; // true => SingleChildScrollView

  const ScreenFrame({
    super.key,
    required this.child,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final pad = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget body = Padding(padding: pad, child: child);

    if (scrollable) {
      body = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: body,
      );
    }

    return SafeArea(
      // top safe area is most important here
      top: true,
      bottom: false,
      child: body,
    );
  }
}