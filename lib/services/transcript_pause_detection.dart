import 'dart:math' as math;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../domain/models/audio_text_timing.dart';

/// Read and scan in a worker isolate, passing only a path into the worker and
/// the small list of boundaries back. The UI never owns the PCM buffer.
Future<List<int>> detectAudioPauseEnds(String path) => Isolate.run(() async {
  return detectWavPauseEnds(await File(path).readAsBytes());
});

/// Detect quiet intervals in the mono PCM16 WAV prepared for local ASR.
/// A 20 ms RMS window below -38 dBFS for 300 ms marks a possible pause.
/// This is energy detection, not a speech classifier; music may mask pauses.
List<int> detectWavPauseEnds(Uint8List bytes) {
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    return [];
  }
  final data = ByteData.sublistView(bytes);
  var rate = 0;
  var valid = false;
  for (var offset = 12; offset + 8 <= bytes.length;) {
    final size = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    if (tag == 'fmt ' && size >= 16 && start + 16 <= bytes.length) {
      valid =
          data.getUint16(start, Endian.little) == 1 &&
          data.getUint16(start + 2, Endian.little) == 1 &&
          data.getUint16(start + 14, Endian.little) == 16;
      rate = data.getUint32(start + 4, Endian.little);
    }
    if (tag == 'data') {
      if (!valid || rate <= 0) return [];
      final count = math.min(size, bytes.length - start) ~/ 2;
      final window = math.max(1, rate ~/ 50);
      final ends = <int>[];
      int? quietStart;
      for (var sample = 0; sample < count; sample += window) {
        final end = math.min(count, sample + window);
        var energy = 0.0;
        for (var i = sample; i < end; i++) {
          final value = data.getInt16(start + i * 2, Endian.little);
          energy += value * value;
        }
        final quiet = energy / (end - sample) < 170000;
        if (quiet) {
          quietStart ??= sample;
        } else if (quietStart != null) {
          if ((sample - quietStart) * 1000 / rate >= 300) {
            ends.add((sample * 1000 / rate).round());
          }
          quietStart = null;
        }
      }
      // Trailing silence has no following words in this extraction window.
      return ends;
    }
    offset = start + size + (size.isOdd ? 1 : 0);
  }
  return [];
}

/// Match each pause to the nearest word onset within 400 ms. Keep ASR timings
/// intact so highlighting and seeking still use the original alignment.
List<AudioTextTiming> markTranscriptPauses(
  List<AudioTextTiming> timings,
  List<int> pauseEndsMs,
) {
  final marked = <int>{};
  var cursor = 0;
  for (final pause in pauseEndsMs) {
    while (cursor + 1 < timings.length &&
        timings[cursor + 1].startMs <= pause) {
      cursor++;
    }
    int? best;
    var distance = 401;
    for (final index in [cursor, cursor + 1]) {
      if (index >= timings.length) continue;
      final delta = (timings[index].startMs - pause).abs();
      if (delta < distance) {
        best = index;
        distance = delta;
      }
    }
    if (best != null) marked.add(best);
  }
  return [
    for (var i = 0; i < timings.length; i++)
      AudioTextTiming(
        text: timings[i].text,
        startMs: timings[i].startMs,
        endMs: timings[i].endMs,
        chunkStartMs: timings[i].chunkStartMs,
        pauseBefore: timings[i].pauseBefore || marked.contains(i),
      ),
  ];
}
