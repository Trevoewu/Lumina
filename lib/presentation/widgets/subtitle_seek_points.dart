import '../../data/database/app_database.dart';
import '../../domain/models/chapter_manifest.dart';
import 'synced_lyrics_list.dart';

List<int> subtitleSeekPoints(
  List<Paragraph> paragraphs,
  ChapterManifest? manifest,
) {
  if (manifest == null) return const [];
  final offsets = <String, int>{};
  var offset = 0;
  for (final segment in manifest.segments) {
    if (segment.durationMs > 0) offsets[segment.paragraphId] = offset;
    offset += segment.durationMs;
  }
  return {
    for (final line in buildSyncedLyricLines(paragraphs, manifest))
      if (offsets.containsKey(line.paragraphId))
        offsets[line.paragraphId]! + line.startMs,
  }.toList()..sort();
}

int nearestSubtitleStart(List<int> points, int positionMs) {
  if (points.isEmpty) return positionMs;
  var low = 0;
  var high = points.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (points[mid] < positionMs) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  if (low == 0) return points.first;
  if (low == points.length) return points.last;
  return positionMs - points[low - 1] <= points[low] - positionMs
      ? points[low - 1]
      : points[low];
}

/// Step from the currently playing line, clamping at transcript boundaries.
int? stepSubtitleStart(List<int> points, int positionMs, int lines) {
  if (points.isEmpty) return null;
  var low = 0;
  var high = points.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (points[mid] <= positionMs) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  final current = (low - 1).clamp(0, points.length - 1);
  return points[(current + lines).clamp(0, points.length - 1)];
}
