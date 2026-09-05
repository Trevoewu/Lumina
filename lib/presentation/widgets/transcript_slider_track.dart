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

  const TranscriptSliderTrack({required this.ranges, required this.color});

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
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    // Only expose the subtitle layer beyond playback; the played portion
    // keeps the foreground color painted by the standard track above.
    context.canvas.save();
    context.canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    );
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
  }
}
