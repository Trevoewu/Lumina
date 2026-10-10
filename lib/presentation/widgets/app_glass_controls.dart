import 'dart:ui';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design_system/app_icon.dart';

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
  Widget build(BuildContext context) {
    if (usesNativeMenus) return _buildNative(context);
    return _buildFlutter(context);
  }

  /// iOS 26's own pull-down menu: the system's animation, haptics and Liquid
  /// Glass, drawn entirely by UIKit. The Flutter menu hosted a native glass
  /// view inside a Material route, which stuttered as it opened.
  Widget _buildNative(BuildContext context) {
    final entries = widget.itemBuilder(context);
    return SizedBox.square(
      dimension: 44,
      child: CNPopupMenuButton.icon(
        buttonImageAsset: const CNImageAsset(
          'assets/ui_icons/more@3x.png',
          size: 22,
        ),
        tint: Theme.of(context).colorScheme.onSurface,
        buttonStyle: CNButtonStyle.plain,
        size: 44,
        items: nativeMenuItems(entries),
        onSelected: (index) {
          final value = nativeMenuValue(entries, index);
          if (value != null) widget.onSelected(value);
        },
      ),
    );
  }

  Widget _buildFlutter(BuildContext context) => PopupMenuButton<T>(
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
      child: IconButton(
        icon: const AppIcon(AppIcons.moreHorizontal, size: 22),
        color: Theme.of(context).colorScheme.onSurface,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onPressed: () => _menuKey.currentState?.showButtonMenu(),
      ),
    ),
  );
}

/// The native menu needs iOS 26; before it, the package would show an
/// action sheet instead, so older systems keep the Flutter menu.
bool get usesNativeMenus =>
    defaultTargetPlatform == TargetPlatform.iOS &&
    PlatformVersion.shouldUseNativeGlass;

/// The same entries as native menu items, one for one so a selected index
/// maps straight back. Labels come from each item's [Text].
List<CNPopupMenuEntry> nativeMenuItems<T>(List<PopupMenuEntry<T>> entries) => [
  for (final entry in entries)
    if (entry is PopupMenuDivider)
      const CNPopupMenuDivider()
    else if (entry is PopupMenuItem<T>)
      CNPopupMenuItem(
        label: _labelOf(entry.child) ?? '',
        enabled: entry.enabled,
      )
    else
      const CNPopupMenuItem(label: '', enabled: false),
];

/// The value of the native item at [index], which counts dividers too.
T? nativeMenuValue<T>(List<PopupMenuEntry<T>> entries, int index) {
  if (index < 0 || index >= entries.length) return null;
  final entry = entries[index];
  return entry is PopupMenuItem<T> && entry.enabled ? entry.value : null;
}

String? _labelOf(Widget? child) => switch (child) {
  Text(:final data?) => data,
  Text(:final textSpan?) => textSpan.toPlainText(),
  _ => null,
};

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

/// A value picker — the current choice as a button, the choices in a menu
/// with it checked — as iOS 26's native pull-down menu. Callers keep their
/// Flutter menu for [usesNativeMenus] being false.
class AppNativeChoiceMenu<T> extends StatelessWidget {
  const AppNativeChoiceMenu({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.color,
    this.insideModal = false,
  });

  /// Each choice and its label, in menu order.
  final Map<T, String> choices;
  final T selected;
  final ValueChanged<T> onSelected;

  /// The button label's colour; the secondary text colour by default.
  final Color? color;

  /// True inside a sheet or dialog. The native button otherwise hides itself
  /// whenever any modal is open, which would include the one it sits in.
  final bool insideModal;

  @override
  Widget build(BuildContext context) {
    final values = choices.keys.toList(growable: false);
    return CNPopupMenuButton(
      buttonLabel: choices[selected] ?? '',
      buttonStyle: CNButtonStyle.plain,
      tint: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      height: 36,
      shrinkWrap: true,
      autoHideOnModal: !insideModal,
      items: [
        for (final value in values)
          CNPopupMenuItem(label: choices[value]!, checked: value == selected),
      ],
      onSelected: (index) {
        if (index >= 0 && index < values.length) onSelected(values[index]);
      },
    );
  }
}
