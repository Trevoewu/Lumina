import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Direction for macOS navigation arrow buttons.
enum MacosNavArrowDirection { left, right }

/// Sidebar toggle icon using HugeIcons Stroke / Rounded style (`sidebarLeft`).
class SidebarToggleIcon extends StatelessWidget {
  const SidebarToggleIcon({
    super.key,
    this.size = 18.0,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return HugeIcon(
      icon: HugeIcons.strokeRoundedSidebarLeft,
      size: size,
      color: iconColor,
    );
  }
}

/// Navigation arrow icon using HugeIcons Stroke / Rounded style (`←` and `→`).
class MacosNavArrowIcon extends StatelessWidget {
  const MacosNavArrowIcon({
    super.key,
    required this.direction,
    this.size = 18.0,
    this.color,
  });

  final MacosNavArrowDirection direction;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return HugeIcon(
      icon: direction == MacosNavArrowDirection.left
          ? HugeIcons.strokeRoundedArrowLeft01
          : HugeIcons.strokeRoundedArrowRight01,
      size: size,
      color: iconColor,
    );
  }
}


/// A macOS-style toolbar button with subtle hover, active, and disabled states.
class MacosToolbarButton extends StatefulWidget {
  const MacosToolbarButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.tooltip,
    this.size = 28.0,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  State<MacosToolbarButton> createState() => _MacosToolbarButtonState();
}

class _MacosToolbarButtonState extends State<MacosToolbarButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    Color backgroundColor = Colors.transparent;
    if (_isEnabled) {
      if (_isPressed) {
        backgroundColor = onSurface.withValues(alpha: 0.16);
      } else if (_isHovered) {
        backgroundColor = onSurface.withValues(alpha: 0.08);
      }
    }

    final double contentOpacity = _isEnabled ? 0.85 : 0.22;

    Widget button = MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6.0),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: contentOpacity,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.tooltip != null && _isEnabled) {
      button = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 600),
        child: button,
      );
    }

    return button;
  }
}

/// macOS window top toolbar with traffic lights reservation, sidebar toggle,
/// and back/forward navigation buttons.
class MacosWindowToolbar extends StatelessWidget {
  const MacosWindowToolbar({
    super.key,
    required this.isSidebarVisible,
    required this.onToggleSidebar,
    required this.canGoBack,
    required this.onBack,
    required this.canGoForward,
    required this.onForward,
    this.height = 36.0,
    this.trafficLightsLeftPadding = 78.0,
    this.buttonTopOffset = 2.0,
  });

  final bool isSidebarVisible;
  final VoidCallback onToggleSidebar;
  final bool canGoBack;
  final VoidCallback? onBack;
  final bool canGoForward;
  final VoidCallback? onForward;
  final double height;
  final double trafficLightsLeftPadding;
  final double buttonTopOffset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: trafficLightsLeftPadding,
          top: buttonTopOffset,
          right: 16.0,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sidebar toggle button
              MacosToolbarButton(
                key: const ValueKey('macos-sidebar-toggle-button'),
                size: 26.0,
                tooltip: isSidebarVisible ? '隐藏侧边栏' : '显示侧边栏',
                onPressed: onToggleSidebar,
                child: const SidebarToggleIcon(size: 18.0),
              ),
              const SizedBox(width: 14.0),
              // Back button
              MacosToolbarButton(
                key: const ValueKey('macos-back-button'),
                size: 26.0,
                tooltip: '返回',
                onPressed: canGoBack ? onBack : null,
                child: const MacosNavArrowIcon(
                  direction: MacosNavArrowDirection.left,
                  size: 18.0,
                ),
              ),
              const SizedBox(width: 14.0),
              // Forward button
              MacosToolbarButton(
                key: const ValueKey('macos-forward-button'),
                size: 26.0,
                tooltip: '前进',
                onPressed: canGoForward ? onForward : null,
                child: const MacosNavArrowIcon(
                  direction: MacosNavArrowDirection.right,
                  size: 18.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
