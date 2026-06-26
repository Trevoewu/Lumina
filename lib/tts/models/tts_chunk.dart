import 'dart:typed_data';

/// 单次 TTS 合成结果。
class TtsChunk {
  /// 音频字节（二进制）。
  final Uint8List audioBytes;

  /// 音频时长（毫秒），由 Provider 返回或本地探测。
  final int durationMs;

  /// 音频格式（'mp3', 'wav', 'pcm' ...）。
  final String format;

  /// 本次合成的计费字符数（若 Provider 返回）。
  final int? billedCharacters;

  /// 采样率。
  final int? sampleRate;

  const TtsChunk({
    required this.audioBytes,
    required this.durationMs,
    required this.format,
    this.billedCharacters,
    this.sampleRate,
  });
}
