import 'dart:async';

import 'package:flutter/material.dart';

class SwipeAction {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final FutureOr<void> Function() onPressed;

  const SwipeAction({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
    this.foregroundColor = Colors.white,
  });
}

/// A list row that reveals a fixed set of trailing actions when dragged left.
///
/// The row settles fully open or closed, supports a velocity flick, and never
/// dismisses itself implicitly: destructive behavior only happens after the
/// user taps the corresponding revealed action.
class SwipeActionRow extends StatefulWidget {
  final Widget child;
  final List<SwipeAction> actions;
  final double actionWidth;
  final bool enabled;

  const SwipeActionRow({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 92,
    this.enabled = true,
  });

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow> {
  double _dragOffset = 0;
  bool _dragging = false;

  bool get _isOpen => _dragOffset < -0.5;

  void _settle({required bool open, required double revealWidth}) {
    setState(() {
      _dragging = false;
      _dragOffset = open ? -revealWidth : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.actions.isEmpty) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.actionWidth * widget.actions.length;
        final actionWidth = widget.actionWidth.clamp(
          64.0,
          availableWidth / widget.actions.length,
        );
        final revealWidth = actionWidth * widget.actions.length;
        final offset = _dragOffset.clamp(-revealWidth, 0.0);

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IgnorePointer(
                    ignoring: !_isOpen,
                    child: ExcludeSemantics(
                      excluding: !_isOpen,
                      child: SizedBox(
                        width: revealWidth,
                        child: Row(
                          children: [
                            for (final action in widget.actions)
                              SizedBox(
                                width: actionWidth,
                                height: double.infinity,
                                child: Semantics(
                                  button: true,
                                  label: action.label,
                                  child: Material(
                                    color: action.backgroundColor,
                                    child: InkWell(
                                      onTap: () async {
                                        _settle(
                                          open: false,
                                          revealWidth: revealWidth,
                                        );
                                        await action.onPressed();
                                      },
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: Text(
                                            action.label,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: action.foregroundColor,
                                              fontSize: 14,
                                              height: 1.15,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(offset, 0, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isOpen
                      ? () => _settle(open: false, revealWidth: revealWidth)
                      : null,
                  onHorizontalDragStart: (_) {
                    setState(() => _dragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragOffset = (_dragOffset + details.delta.dx).clamp(
                        -revealWidth,
                        0.0,
                      );
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    final shouldOpen =
                        velocity < -350 ||
                        (velocity <= 350 &&
                            _dragOffset.abs() > revealWidth * 0.35);
                    _settle(open: shouldOpen, revealWidth: revealWidth);
                  },
                  onHorizontalDragCancel: () => _settle(
                    open: _dragOffset.abs() > revealWidth * 0.35,
                    revealWidth: revealWidth,
                  ),
                  child: AbsorbPointer(absorbing: _isOpen, child: widget.child),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
