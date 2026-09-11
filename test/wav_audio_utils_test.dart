import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/services/wav_audio_utils.dart';

void main() {
  test('uses actual bytes for a streaming WAV placeholder size', () {
    final wav = _pcmWav(
      actualDataBytes: 48000,
      declaredDataBytes: 0xFFFFFF00,
      byteRate: 48000,
    );

    expect(wavDurationMs(wav), 1000);
  });

  test('uses the declared data size for a regular WAV', () {
    final wav = _pcmWav(
      actualDataBytes: 96000,
      declaredDataBytes: 48000,
      byteRate: 48000,
    );

    expect(wavDurationMs(wav), 1000);
  });

  test('repairs an existing manifest from the cached WAV file', () async {
    final root = await Directory.systemTemp.createTemp('lumina_wav_test');
    addTearDown(() => root.delete(recursive: true));
    final audio = File('${root.path}/c1/p1.wav');
    await audio.parent.create(recursive: true);
    await audio.writeAsBytes(
      _pcmWav(
        actualDataBytes: 48000,
        declaredDataBytes: 0xFFFFFF00,
        byteRate: 48000,
      ),
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'fish_audio_api',
      voiceId: 'v1',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'c1/p1.wav',
          durationMs: 89478480,
          state: ParagraphAudioState.ready,
          format: 'wav',
        ),
      ],
    );

    final repaired = await repairManifestWavDurations(manifest, root);

    expect(repaired.segments.single.durationMs, 1000);
    expect(repaired.totalDurationMs, 1000);
  });

  test('sanitizeWavHeader fixes placeholder data and riff sizes', () {
    final wav = _pcmWav(
      actualDataBytes: 48000,
      declaredDataBytes: 0xFFFFFF00,
      byteRate: 48000,
    );
    // Artificially corrupt RIFF size too
    ByteData.sublistView(wav).setUint32(4, 0xFFFFFFFF, Endian.little);

    final fixed = sanitizeWavHeader(wav);
    final d = ByteData.sublistView(fixed);

    expect(d.getUint32(40, Endian.little), 48000);
    expect(d.getUint32(4, Endian.little), 36 + 48000);
  });

  test('sanitizeWavHeader leaves already valid WAV untouched', () {
    final wav = _pcmWav(
      actualDataBytes: 48000,
      declaredDataBytes: 48000,
      byteRate: 48000,
    );

    final result = sanitizeWavHeader(wav);
    expect(result, same(wav));
  });
}

Uint8List _pcmWav({
  required int actualDataBytes,
  required int declaredDataBytes,
  required int byteRate,
}) {
  final bytes = Uint8List(44 + actualDataBytes);
  final data = ByteData.sublistView(bytes);

  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, 36 + actualDataBytes, Endian.little);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, declaredDataBytes, Endian.little);
  return bytes;
}
