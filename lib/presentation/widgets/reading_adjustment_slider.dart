import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';

class ReadingAdjustmentSlider extends StatelessWidget {
  final Key sliderKey;
  final String label, thumb, leading, trailing;
  final double value, min, max;
  final int divisions;
  final bool fontEnds;
  final ValueChanged<double> onChanged;
  const ReadingAdjustmentSlider({
    super.key,
    required this.sliderKey,
    required this.label,
    required this.thumb,
    required this.leading,
    required this.trailing,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.fontEnds = false,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? const Color(0xFF303033) : const Color(0xFFF7F7F7);
    return LayoutBuilder(
      builder: (context, constraints) {
        final active = dark ? const Color(0xFF414144) : const Color(0xFFECECEE);
        final clampedValue = value.clamp(min, max);
        final fraction =
            ((53 +
                        (constraints.maxWidth - 106) *
                            ((clampedValue - min) / (max - min))) /
                    constraints.maxWidth)
                .clamp(0.0, 1.0);
        return SizedBox(
          height: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [active, active, track, track],
                stops: [0, fraction, fraction, 1],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Center(
                    child: Text(
                      leading,
                      style: TextStyle(
                        fontSize: fontEnds ? 12 : 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: label,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 36,
                        activeTrackColor: dark
                            ? const Color(0xFF414144)
                            : const Color(0xFFECECEE),
                        inactiveTrackColor: track,
                        overlayShape: SliderComponentShape.noOverlay,
                        showValueIndicator: ShowValueIndicator.never,
                        tickMarkShape: SliderTickMarkShape.noTickMark,
                        trackShape: const RectangularSliderTrackShape(),
                        thumbShape: _LabelThumb(
                          thumb,
                          context.appTextPrimary,
                          dark ? const Color(0xFF555558) : Colors.white,
                        ),
                      ),
                      child: Slider(
                        key: sliderKey,
                        value: clampedValue,
                        min: min,
                        max: max,
                        divisions: divisions,
                        semanticFormatterCallback: (v) => fontEnds
                            ? '${(v * 24).round()}'
                            : (divisions == 6 && min == 0
                                  ? v.round().toString()
                                  : v.toStringAsFixed(1)),
                        onChanged: (newValue) {
                          if (newValue != clampedValue) {
                            HapticFeedback.selectionClick();
                            onChanged(newValue);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Center(
                    child: Text(
                      trailing,
                      style: TextStyle(
                        fontSize: fontEnds ? 18 : 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LabelThumb extends SliderComponentShape {
  final String text;
  final Color foreground, background;
  const _LabelThumb(this.text, this.foreground, this.background);
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(38, 38);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: (painter.width + 18).clamp(38, 64),
      height: 38,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(22)));
    context.canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: .14),
      5,
      true,
    );
    context.canvas.drawPath(path, Paint()..color = background);
    painter.paint(
      context.canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
}
