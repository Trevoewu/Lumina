import 'audio_text_timing.dart';

/// 段落音频的生成状态。
enum ParagraphAudioState {
  /// 未生成。
  notGenerated,

  /// 正在生成。
  generating,

  /// 已就绪，可播放。
  ready,

  /// 生成失败。
  failed,
}

/// 章节音频清单中的一条记录：一个段落 → 一个音频分片。
///
/// 每章一个 manifest 文件，包含一组按段落顺序排列的 SegmentEntry。
/// 播放器把整章 manifest 当作无缝播放列表；
/// 段落偏移 = 前续所有 segment 的 durationMs 累加。
class SegmentEntry {
  final String paragraphId;

  /// 分片音频文件相对路径（相对于 audio/{bookId}/）。
  final String audioFile;

  /// 音频时长（毫秒）。
  final int durationMs;

  /// 生成状态。
  final ParagraphAudioState state;

  /// 音频格式。
  final String format;

  /// 该段落的计费字符数（用于成本统计）。
  final int? billedCharacters;

  /// 生成时间（毫秒），用于缓存清理策略。
  final int? generatedAt;

  /// 失败原因（若 state == failed）。
  final String? error;

  /// Text alignment relative to the beginning of this paragraph audio.
  final List<AudioTextTiming> timings;

  /// Fingerprint of the exact paragraph text used for synthesis.
  ///
  /// Older manifests may omit this field. They remain readable, but the
  /// generator will not treat their audio as version-safe until it has been
  /// regenerated once with a fingerprint.
  final String? contentFingerprint;

  const SegmentEntry({
    required this.paragraphId,
    required this.audioFile,
    required this.durationMs,
    required this.state,
    this.format = 'mp3',
    this.billedCharacters,
    this.generatedAt,
    this.error,
    this.timings = const [],
    this.contentFingerprint,
  });

  SegmentEntry copyWith({
    String? paragraphId,
    String? audioFile,
    int? durationMs,
    ParagraphAudioState? state,
    String? format,
    int? billedCharacters,
    int? generatedAt,
    String? error,
    List<AudioTextTiming>? timings,
    String? contentFingerprint,
  }) {
    return SegmentEntry(
      paragraphId: paragraphId ?? this.paragraphId,
      audioFile: audioFile ?? this.audioFile,
      durationMs: durationMs ?? this.durationMs,
      state: state ?? this.state,
      format: format ?? this.format,
      billedCharacters: billedCharacters ?? this.billedCharacters,
      generatedAt: generatedAt ?? this.generatedAt,
      error: error ?? this.error,
      timings: timings ?? this.timings,
      contentFingerprint: contentFingerprint ?? this.contentFingerprint,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paragraphId': paragraphId,
      'audioFile': audioFile,
      'durationMs': durationMs,
      'state': state.name,
      'format': format,
      'billedCharacters': billedCharacters,
      'generatedAt': generatedAt,
      'error': error,
      'timings': timings.map((timing) => timing.toJson()).toList(),
      'contentFingerprint': contentFingerprint,
    };
  }

  factory SegmentEntry.fromJson(Map<String, dynamic> json) {
    return SegmentEntry(
      paragraphId: json['paragraphId'] as String,
      audioFile: json['audioFile'] as String,
      durationMs: json['durationMs'] as int,
      state: ParagraphAudioState.values.byName(json['state'] as String),
      format: json['format'] as String? ?? 'mp3',
      billedCharacters: json['billedCharacters'] as int?,
      generatedAt: json['generatedAt'] as int?,
      error: json['error'] as String?,
      timings:
          (json['timings'] as List?)
              ?.whereType<Map>()
              .map(
                (timing) =>
                    AudioTextTiming.fromJson(Map<String, dynamic>.from(timing)),
              )
              .toList(growable: false) ??
          const [],
      contentFingerprint: json['contentFingerprint'] as String?,
    );
  }
}

/// 章节音频清单。
///
/// 方案 B 核心：每段一个音频文件 + 一张清单。
/// 播放器把清单当无缝播放列表，偏移 = 累计时长。
/// 单段失败/重生成不影响其他段。
class ChapterManifest {
  final String chapterId;
  final String bookId;

  /// 生成该批音频时使用的 Provider id。
  final String providerId;

  /// 生成该批音频时使用的音色 id。
  final String voiceId;

  /// 生成时使用的语速。
  final double speed;

  /// Provider model/profile identity used for this audio version.
  final String? configurationFingerprint;

  /// 段落音频记录（按段落顺序）。
  final List<SegmentEntry> segments;

  /// 清单最后更新时间（毫秒）。
  final int updatedAt;

  const ChapterManifest({
    required this.chapterId,
    required this.bookId,
    required this.providerId,
    required this.voiceId,
    required this.speed,
    required this.segments,
    required this.updatedAt,
    this.configurationFingerprint,
  });

  /// 计算到某段落的累计偏移（毫秒）。
  /// 返回该段落音频在整个章节音频中的起始时间。
  int offsetOf(String paragraphId) {
    int offset = 0;
    for (final seg in segments) {
      if (seg.paragraphId == paragraphId) break;
      if (seg.state == ParagraphAudioState.ready) {
        offset += seg.durationMs;
      }
    }
    return offset;
  }

  /// 通过绝对偏移（毫秒）定位到对应的段落 id。
  /// 用于播放进度 → 当前段落的高亮同步。
  String? paragraphAtOffset(int offsetMs) {
    int acc = 0;
    for (final seg in segments) {
      if (seg.state != ParagraphAudioState.ready) continue;
      if (offsetMs < acc + seg.durationMs) {
        return seg.paragraphId;
      }
      acc += seg.durationMs;
    }
    return segments.isEmpty ? null : segments.last.paragraphId;
  }

  /// 该章是否全部就绪可播。
  bool get isReady =>
      segments.isNotEmpty &&
      segments.every((s) => s.state == ParagraphAudioState.ready);

  /// 就绪段数。
  int get readyCount =>
      segments.where((s) => s.state == ParagraphAudioState.ready).length;

  /// 已就绪音频的总时长（毫秒）。
  int get totalDurationMs => segments
      .where((s) => s.state == ParagraphAudioState.ready)
      .fold(0, (sum, s) => sum + s.durationMs);

  Map<String, dynamic> toJson() {
    return {
      'chapterId': chapterId,
      'bookId': bookId,
      'providerId': providerId,
      'voiceId': voiceId,
      'speed': speed,
      'configurationFingerprint': configurationFingerprint,
      'segments': segments.map((s) => s.toJson()).toList(),
      'updatedAt': updatedAt,
    };
  }

  factory ChapterManifest.fromJson(Map<String, dynamic> json) {
    return ChapterManifest(
      chapterId: json['chapterId'] as String,
      bookId: json['bookId'] as String,
      providerId: json['providerId'] as String,
      voiceId: json['voiceId'] as String,
      speed: (json['speed'] as num).toDouble(),
      segments: (json['segments'] as List)
          .map((s) => SegmentEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updatedAt'] as int,
      configurationFingerprint: json['configurationFingerprint'] as String?,
    );
  }
}
