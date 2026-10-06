import 'package:flutter/material.dart';

/// Presents artwork as a printed object on the paper-toned page: tight
/// corners, a hairline edge and a soft, warm shadow instead of a floating
/// one. A book is a 2:3 board with a bound spine; [BookStyleCover.square]
/// keeps square art such as a podcast's square, without the spine.
class BookStyleCover extends StatelessWidget {
  const BookStyleCover({
    super.key,
    required this.height,
    required this.artwork,
    this.showShadow = true,
  }) : aspectRatio = bookAspectRatio,
       showSpine = true;

  const BookStyleCover.square({
    super.key,
    required double size,
    required this.artwork,
    this.showShadow = true,
  }) : height = size,
       aspectRatio = 1,
       showSpine = false;

  /// Width over height of a trade paperback.
  static const bookAspectRatio = 2 / 3;

  final double height;
  final double aspectRatio;
  final bool showSpine;

  /// Fills the cover.
  final Widget artwork;
  final bool showShadow;

  BorderRadius get _radius => showSpine
      ? const BorderRadius.only(
          topLeft: Radius.circular(2),
          bottomLeft: Radius.circular(2),
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        )
      : BorderRadius.circular(6);

  @override
  Widget build(BuildContext context) {
    final width = height * aspectRatio;
    final spineWidth = (width * 0.07).clamp(4.0, 16.0);
    // A warm umber instead of black keeps the shadow in the same family as
    // the page tint.
    const shadowInk = Color(0xFF3B2F24);
    final outline = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: shadowInk.withValues(alpha: 0.10),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                  BoxShadow(
                    color: shadowInk.withValues(alpha: 0.14),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              artwork,
              // The spine: a shaded binding, the bright crease where the board
              // hinges, then a short shadow falling back onto the front.
              if (showSpine)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: spineWidth + 6,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.26),
                            Colors.black.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.24),
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0),
                          ],
                          stops: [
                            0,
                            spineWidth / (spineWidth + 6) * 0.9,
                            spineWidth / (spineWidth + 6),
                            (spineWidth + 1.5) / (spineWidth + 6),
                            1,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _radius,
                    border: Border.all(color: outline, width: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
