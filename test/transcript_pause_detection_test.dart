import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/transcript_pause_detection.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';

Uint8List recording(int silenceMs) {
  const rate = 16000;
  final samples = (1000 + silenceMs) * 16;
  final bytes = Uint8List(44 + samples * 2);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String text) =>
      bytes.setRange(offset, offset + 4, text.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    final quiet = i >= 8000 && i < 8000 + silenceMs * 16;
    data.setInt16(
      44 + i * 2,
      quiet ? 50 : (i.isEven ? 5000 : -5000),
      Endian.little,
    );
  }
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('worker reads audio and returns detected boundaries', () async {
    final directory = await Directory.systemTemp.createTemp('pause-worker-');
    try {
      final file = File('${directory.path}/sample.wav');
      await file.writeAsBytes(recording(400));
      expect(await detectAudioPauseEnds(file.path), [900]);
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('detects sustained quiet audio but ignores short gaps', () {
    expect(detectWavPauseEnds(recording(400)), [900]);
    expect(detectWavPauseEnds(recording(200)), isEmpty);
    expect(detectWavPauseEnds(Uint8List(10)), isEmpty);
  });
  test('marks nearest onset without changing or fabricating timestamps', () {
    final timings = [
      const AudioTextTiming(text: 'before', startMs: 0, endMs: 950),
      const AudioTextTiming(text: 'after', startMs: 950, endMs: 1500),
    ];
    final marked = markTranscriptPauses(timings, [900, 5000]);
    expect(marked.first.pauseBefore, isFalse);
    expect(marked.last.pauseBefore, isTrue);
    expect(marked.last.startMs, 950);
    expect(AudioTextTiming.fromJson(marked.last.toJson()).pauseBefore, isTrue);
    expect(marked.last.shifted(100).pauseBefore, isTrue);
  });
}
