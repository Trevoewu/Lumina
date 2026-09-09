import 'package:flutter/material.dart';

import 'macos_window_toolbar.dart';

/// Horizontal clearance shared by page controls and the window chrome.
class MacosPageToolbarScope extends InheritedWidget {
  const MacosPageToolbarScope({
    super.key,
    required this.leadingInset,
    required super.child,
  });

  final double leadingInset;

  static MacosPageToolbarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MacosPageToolbarScope>();

  @override
  bool updateShouldNotify(MacosPageToolbarScope oldWidget) =>
      leadingInset != oldWidget.leadingInset;
}

class MacosPageToolbar extends StatelessWidget {
  const MacosPageToolbar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: macosTopControlsReservedHeight,
    child: Padding(
      padding: EdgeInsets.only(
        left: MacosPageToolbarScope.maybeOf(context)?.leadingInset ?? 0,
      ),
      child: ClipRect(child: child),
    ),
  );
}
