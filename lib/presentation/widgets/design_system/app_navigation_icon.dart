import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

enum AppNavigationSymbol { home, search, dictionary }

/// A shared 24-point outline family using HugeIcons Stroke / Rounded style
/// for desktop navigation. Color and size follow the surrounding IconTheme.
class AppNavigationIcon extends StatelessWidget {
  const AppNavigationIcon(this.symbol, {super.key, this.size, this.color});

  final AppNavigationSymbol symbol;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final effectiveSize = size ?? theme.size ?? 24.0;
    final effectiveColor =
        (color ?? theme.color ?? Theme.of(context).colorScheme.onSurface)
            .withValues(alpha: theme.opacity ?? 1.0);

    final iconData = switch (symbol) {
      AppNavigationSymbol.home => HugeIcons.strokeRoundedHome01,
      AppNavigationSymbol.search => HugeIcons.strokeRoundedSearch01,
      AppNavigationSymbol.dictionary => HugeIcons.strokeRoundedBookOpen01,
    };

    return HugeIcon(icon: iconData, size: effectiveSize, color: effectiveColor);
  }
}
