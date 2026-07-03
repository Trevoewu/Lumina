import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';

void main() {
  test('Fish generation profiles persist speed and quality policies', () async {
    final settings = <String, String>{};
    final provider = FishAudioApiTtsProvider(
      settingReader: (key) async => settings[key],
      settingWriter: (key, value) async => settings[key] = value,
    );

    expect(await provider.generationProfile, FishAudioGenerationProfile.fast);
    expect(await provider.generationConcurrency, 3);
    expect(FishAudioGenerationProfile.fast.sampleRate, 24000);
    expect(FishAudioGenerationProfile.fast.latency, 'low');

    await provider.setGenerationProfile(FishAudioGenerationProfile.quality);
    final restored = FishAudioApiTtsProvider(
      settingReader: (key) async => settings[key],
    );
    expect(
      await restored.generationProfile,
      FishAudioGenerationProfile.quality,
    );
    expect(await restored.generationConcurrency, 1);
    expect(FishAudioGenerationProfile.quality.sampleRate, 44100);
    expect(FishAudioGenerationProfile.quality.latency, 'balanced');
  });

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
