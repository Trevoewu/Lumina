import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/generation_orchestrator.dart';

void main() {
  /// 构造一个最简单的合法 WAV（无 fmt 以外额外 chunk），给定 PCM 字节数。
  Uint8List makeWav(int pcmBytes) {
    final headerSize = 44;
    final out = Uint8List(headerSize + pcmBytes);
    final d = ByteData.sublistView(out);
    out[0] = 0x52; // R
    out[1] = 0x49; // I
    out[2] = 0x46; // F
    out[3] = 0x46; // F
    d.setUint32(4, 36 + pcmBytes, Endian.little);
    out[8] = 0x57; // W
    out[9] = 0x41; // A
    out[10] = 0x56; // V
    out[11] = 0x45; // E
    out[12] = 0x66; // f
    out[13] = 0x6D; // m
    out[14] = 0x74; // t
    out[15] = 0x20; //
    d.setUint32(16, 16, Endian.little);
    d.setUint16(20, 1, Endian.little);
    d.setUint16(22, 1, Endian.little);
    d.setUint32(24, 24000, Endian.little);
    d.setUint32(28, 48000, Endian.little);
    d.setUint16(32, 2, Endian.little);
    d.setUint16(34, 16, Endian.little);
    out[36] = 0x64; // d
    out[37] = 0x61; // a
    out[38] = 0x74; // t
    out[39] = 0x61; // a
    d.setUint32(40, pcmBytes, Endian.little);
    for (var i = headerSize; i < out.length; i++) {
      out[i] = (i % 256);
    }
    return out;
  }

  test('concatWavPcm merges two WAVs into a single valid WAV', () {
    final wav1 = makeWav(4800);
    final wav2 = makeWav(3600);
    final merged = GenerationOrchestrator.concatWavPcm([wav1, wav2]);

    // RIFF header
    expect(String.fromCharCodes(merged.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(merged.sublist(8, 12)), 'WAVE');

    // data chunk
    expect(String.fromCharCodes(merged.sublist(36, 40)), 'data');

    final d = ByteData.sublistView(merged);
    final riffSize = d.getUint32(4, Endian.little);
    final dataSize = d.getUint32(40, Endian.little);

    expect(dataSize, 4800 + 3600);
    expect(riffSize, 36 + 4800 + 3600);
    expect(merged.length, 44 + 4800 + 3600);
  });

  test('concatWavPcm returns single WAV unchanged', () {
    final wav = makeWav(1000);
    final result = GenerationOrchestrator.concatWavPcm([wav]);
    expect(result, same(wav));
  });
}
