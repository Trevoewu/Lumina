import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
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
