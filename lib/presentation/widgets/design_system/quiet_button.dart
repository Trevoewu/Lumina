import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import 'app_icon.dart';

/// A section's action on a flat page: ink on a hairline capsule, sized to its
/// label, so it reads as a button without becoming the loudest thing there.
class AppQuietButton extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final VoidCallback? onPressed;

  const AppQuietButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final color = onPressed == null ? ink.withValues(alpha: 0.3) : ink;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: ink.withValues(alpha: 0.14)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      icon: AppIcon(icon, size: 18, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Unfolds a section's clipped text in place: "More", then "Less", in
/// secondary ink with a turning chevron.
class AppMoreToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;

  const AppMoreToggle({
    super.key,
    required this.expanded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.appTextSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expanded
                  ? context.tr('收起', 'Less', '閉じる')
                  : context.tr('更多', 'More', 'もっと見る'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: expanded ? 0.5 : 0,
              child: AppIcon(AppIcons.arrowDown01, size: 17, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
