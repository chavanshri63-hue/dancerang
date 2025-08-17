import 'package:flutter/material.dart';

/// Reusable card:
/// 1) Full custom body via `child`, OR
/// 2) ListTile-style with shorthand: `icon`, `title`, `subtitle`, `trailing`, `onTap`
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    // Option 1: full custom
    this.child,

    // Option 2: shorthand (ListTile-style)
    this.icon,            // <- NEW: shorthand leading icon
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,

    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.padding = const EdgeInsets.all(12),
  });

  /// Custom content (if provided, shorthand fields are ignored)
  final Widget? child;

  /// Shorthand: quick fields
  final IconData? icon;         // <- NEW
  final String? title;
  final String? subtitle;
  final Widget? leading;        // custom leading overrides `icon`
  final Widget? trailing;
  final VoidCallback? onTap;

  final EdgeInsets margin;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = _buildInner(context);

    final card = Card(
      margin: margin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: padding, child: body),
    );

    return onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: card,
          );
  }

  Widget _buildInner(BuildContext context) {
    // If full custom child provided, use it.
    if (child != null) return child!;

    // Build ListTile-style row using shorthand
    final Widget? effectiveLeading =
        leading ?? (icon != null ? Icon(icon, size: 22) : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (effectiveLeading != null) ...[
          effectiveLeading,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}