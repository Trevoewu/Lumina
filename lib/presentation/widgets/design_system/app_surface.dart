import 'package:flutter/material.dart';

import '../../../core/app_design_tokens.dart';

enum AppSurfaceLevel { standard, elevated, immersive }

/// A semantic surface backed by the same tokens used by ThemeData.cardTheme.
class AppSurface extends StatelessWidget {
  final Widget child;
  final AppSurfaceLevel level;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  const AppSurface({
    super.key,
    required this.child,
    this.level = AppSurfaceLevel.standard,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    final resolvedRadius =
        borderRadius ??
        BorderRadius.circular(switch (level) {
          AppSurfaceLevel.standard => design.radiusMedium,
          AppSurfaceLevel.elevated => design.radiusMedium,
          AppSurfaceLevel.immersive => design.radiusLarge,
        });
    final resolvedColor =
        color ??
        switch (level) {
          AppSurfaceLevel.standard => scheme.surfaceContainer,
          AppSurfaceLevel.elevated => scheme.surfaceContainerHighest,
          AppSurfaceLevel.immersive => scheme.surfaceContainerHigh,
        };

    return Material(
      color: resolvedColor,
      elevation: level == AppSurfaceLevel.elevated ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: resolvedRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: resolvedRadius,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
