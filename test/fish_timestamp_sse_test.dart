import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';

void main() {
  test('Fish timestamp SSE replaces cumulative alignment snapshots', () {
    final accumulator = FishTimestampSseAccumulator();
    accumulator.addPayload(
      jsonEncode({
        'audio_base64': base64Encode([1, 2]),
        'chunk_seq': 0,
        'chunk_audio_offset_sec': 0,
        'alignment': {
          'segments': [
            {'text': 'Hello', 'start': 0.0, 'end': 0.4},
          ],
        },
      }),
    );
    accumulator.addPayload(
      jsonEncode({
        'audio_base64': base64Encode([3]),
        'chunk_seq': 0,
        'chunk_audio_offset_sec': 0,
        'alignment': {
          'segments': [
            {'text': 'Hello', 'start': 0.0, 'end': 0.4},
            {'text': 'world', 'start': 0.4, 'end': 0.9},
          ],
        },
      }),
    );
    accumulator.addPayload(
      jsonEncode({
        'audio_base64': base64Encode([4]),
        'chunk_seq': 1,
        'chunk_audio_offset_sec': 1.0,
        'alignment': {
          'segments': [
            {'text': 'Again', 'start': 0.1, 'end': 0.6},
          ],
        },
      }),
    );

    final result = accumulator.finish();
    expect(result.audioBytes, [1, 2, 3, 4]);
    expect(result.timings.map((timing) => timing.text), [
      'Hello',
      'world',
      'Again',
    ]);
    expect(result.timings.map((timing) => timing.startMs), [0, 400, 1100]);
    expect(result.alignedDurationMs, 1600);
  });
}
