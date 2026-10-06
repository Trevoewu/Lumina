import 'package:flutter/material.dart';
import '../../core/app_design_tokens.dart';

/// Transcript weight on the font's `wght` axis.
const double subtitleFontWeight = 450;

/// Shared subtitle metrics for playback, selection, measurement and preview.
TextStyle subtitleTextStyle(
  BuildContext context, {
  required Color color,
  double fontScale = 1,
  bool focusMode = false,
  bool expanded = false,
}) => TextStyle(
  fontSize:
      (focusMode
          ? 21
          : expanded
          ? 22
          : 18) *
      fontScale,
  // A touch heavier than regular so the dimmed sentences stay legible. Every
  // line, playing or not, shares this weight, so highlighting never reflows.
  // Only variable fonts have a weight axis to land between 400 and 500;
  // static faces ignore the variation and keep their regular cut.
  fontWeight: FontWeight.normal,
  fontVariations: const [FontVariation.weight(subtitleFontWeight)],
  color: color,
  height: 1.5,
  letterSpacing: 0,
  fontFamily: context.appDesign.readingFontFamily,
  fontFamilyFallback: context.appDesign.readingFontFamilyFallback,
);

/// The same sentence spacing and press surface in playback and previews.
class SubtitleLine extends StatelessWidget {
  const SubtitleLine({
    super.key,
    required this.gap,
    required this.child,
    this.backgroundColor = Colors.transparent,
  });
  final double gap;
  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.symmetric(vertical: gap.clamp(20.0, 80.0) / 2),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
}
