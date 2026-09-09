import 'dart:ui';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared material for floating controls and their menus.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({super.key, required this.child, this.radius = 24});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if ((defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        PlatformVersion.supportsLiquidGlass) {
      return LiquidGlassContainer(
        config: LiquidGlassConfig(
          effect: CNGlassEffect.regular,
          shape: CNGlassEffectShape.rect,
          cornerRadius: radius,
        ),
        child: child,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppGlassMenuButton<T> extends StatefulWidget {
  const AppGlassMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.tooltip,
  });
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  State<AppGlassMenuButton<T>> createState() => _AppGlassMenuButtonState<T>();
}

class _AppGlassMenuButtonState<T> extends State<AppGlassMenuButton<T>> {
  final _menuKey = GlobalKey<PopupMenuButtonState<T>>();

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    key: _menuKey,
    tooltip: widget.tooltip,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
    menuPadding: EdgeInsets.zero,
    color: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    position: PopupMenuPosition.under,
    onSelected: widget.onSelected,
    itemBuilder: (context) => [
      _GlassMenuEntries<T>(entries: widget.itemBuilder(context)),
    ],
    child: Semantics(
      label:
          widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
      button: true,
      child: CNButton.icon(
        icon: const CNSymbol('ellipsis', size: 22),
        config: const CNButtonConfig(
          style: CNButtonStyle.glass,
          width: 44,
          minHeight: 44,
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _menuKey.currentState?.showButtonMenu(),
      ),
    ),
  );
}

class _GlassMenuEntries<T> extends PopupMenuEntry<T> {
  const _GlassMenuEntries({required this.entries});
  final List<PopupMenuEntry<T>> entries;
  @override
  double get height =>
      entries.fold(16, (height, entry) => height + entry.height);
  @override
  bool represents(T? value) => false;
  @override
  State<_GlassMenuEntries<T>> createState() => _GlassMenuEntriesState<T>();
}

class _GlassMenuEntriesState<T> extends State<_GlassMenuEntries<T>> {
  @override
  Widget build(BuildContext context) => AppGlassSurface(
    radius: 20,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: widget.entries),
    ),
  );
}

/// Anchored popup using the same glass surface as the more menu.
Future<T?> showAppGlassMenu<T>({
  required BuildContext anchorContext,
  required List<PopupMenuEntry<T>> items,
}) {
  final anchor = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  return showMenu<T>(
    context: anchorContext,
    position: RelativeRect.fromRect(
      origin & anchor.size,
      Offset.zero & overlay.size,
    ),
    constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
    menuPadding: EdgeInsets.zero,
    color: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    items: [_GlassMenuEntries<T>(entries: items)],
  );
}
