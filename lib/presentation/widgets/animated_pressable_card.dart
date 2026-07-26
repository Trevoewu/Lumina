import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The standard interaction wrapper for cards that expose contextual actions.
///
/// Keep the card surface visually clean: pass its action menu through
/// [onLongPress] instead of adding a trailing "more" button. Long presses get
/// the shared scale animation and haptic feedback automatically.
class AnimatedPressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  const AnimatedPressableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<AnimatedPressableCard> createState() => _AnimatedPressableCardState();
}

class _AnimatedPressableCardState extends State<AnimatedPressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: widget.borderRadius,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      onHighlightChanged: (pressed) {
        if (_pressed == pressed) return;
        setState(() => _pressed = pressed);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
