import 'package:flutter/material.dart';

import '../../domain/models/chapter_manifest.dart';

/// Normalized subtitle intervals; gaps remain gaps, even for seek-ahead ASR.
List<({double start, double end})> transcriptCoverage(
  ChapterManifest? manifest,
  int durationMs,
) {
  if (manifest == null || durationMs <= 0) return const [];
  final ranges = <({double start, double end})>[];
  var offset = 0;
  for (final segment in manifest.segments) {
    for (final timing in segment.timings) {
      final start = ((offset + timing.startMs) / durationMs).clamp(0.0, 1.0);
      final end = ((offset + timing.endMs) / durationMs).clamp(0.0, 1.0);
      if (end > start) ranges.add((start: start, end: end));
    }
    offset += segment.durationMs;
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final merged = <({double start, double end})>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final previous = merged.removeLast();
      merged.add((
        start: previous.start,
        end: range.end > previous.end ? range.end : previous.end,
      ));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

/// Subtitle coverage fills the track beneath the opaque playback progress.
class TranscriptSliderTrack extends RoundedRectSliderTrackShape {
  final List<({double start, double end})> ranges;
  final Color color;
  final List<double> ticks;
  final Color? tickColor;
  final double? currentSentence;
  final Color? currentSentenceColor;
  final double emphasis;

  const TranscriptSliderTrack({
    required this.ranges,
    required this.color,
    this.ticks = const [],
    this.tickColor,
    this.currentSentence,
    this.currentSentenceColor,
    this.emphasis = 0,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final inactive = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    ).evaluate(enableAnimation)!;
    final active = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    ).evaluate(enableAnimation)!;
    final cached = ColorTween(
      begin: sliderTheme.disabledSecondaryActiveTrackColor,
      end: sliderTheme.secondaryActiveTrackColor,
    ).evaluate(enableAnimation)!;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    );
    canvas.drawRect(rect, Paint()..color = inactive);
    Rect filledTo(double x) => textDirection == TextDirection.ltr
        ? Rect.fromLTRB(rect.left, rect.top, x, rect.bottom)
        : Rect.fromLTRB(x, rect.top, rect.right, rect.bottom);
    if (secondaryOffset != null) {
      canvas.drawRect(filledTo(secondaryOffset.dx), Paint()..color = cached);
    }
    // Clip the whole capsule, keeping the playback boundary straight.
    canvas.drawRect(filledTo(thumbCenter.dx), Paint()..color = active);
    context.canvas.save();
    context.canvas.clipRect(
      textDirection == TextDirection.ltr
          ? Rect.fromLTRB(thumbCenter.dx, rect.top, rect.right, rect.bottom)
          : Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom),
    );
    final paint = Paint()..color = color;
    for (final range in ranges) {
      final left = textDirection == TextDirection.ltr
          ? range.start
          : 1 - range.end;
      final right = textDirection == TextDirection.ltr
          ? range.end
          : 1 - range.start;
      context.canvas.drawRect(
        Rect.fromLTRB(
          rect.left + left * rect.width,
          rect.top,
          rect.left + right * rect.width,
          rect.bottom,
        ),
        paint,
      );
    }
    context.canvas.restore();
    final tickPaint = Paint()
      ..color = tickColor ?? inactive
      ..strokeWidth = 1;
    for (final tick in ticks) {
      final fraction = textDirection == TextDirection.ltr ? tick : 1 - tick;
      final x = rect.left + fraction * rect.width;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), tickPaint);
    }
    canvas.restore();
    // The current sentence extends beyond the capsule, so paint it after
    // restoring the track clip. Its position is the sentence start.
    final sentence = currentSentence;
    if (sentence != null && currentSentenceColor != null) {
      final fraction = textDirection == TextDirection.ltr
          ? sentence
          : 1 - sentence;
      final marker = Rect.fromCenter(
        center: Offset(rect.left + fraction * rect.width, rect.center.dy),
        width: 2 + 2 * emphasis,
        height: 14 + 12 * emphasis,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(marker, Radius.circular(marker.width / 2)),
        Paint()..color = currentSentenceColor!,
      );
    }
  }
}
