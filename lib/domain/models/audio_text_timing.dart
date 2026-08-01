class AudioTextTiming {
  final String text;
  final int startMs;
  final int endMs;

  /// Identifies the transcription chunk that produced this marker.
  ///
  /// Older persisted transcripts do not have this field. A null value keeps
  /// their original stitching behavior, while new transcripts can keep a
  /// chunk boundary from reflowing an already-rendered tail sentence.
  final int? chunkStartMs;

  const AudioTextTiming({
    required this.text,
    required this.startMs,
    required this.endMs,
    this.chunkStartMs,
  });

  AudioTextTiming shifted(int offsetMs) => AudioTextTiming(
    text: text,
    startMs: startMs + offsetMs,
    endMs: endMs + offsetMs,
    chunkStartMs: chunkStartMs == null ? null : chunkStartMs! + offsetMs,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
    if (chunkStartMs != null) 'chunkStartMs': chunkStartMs,
  };

  factory AudioTextTiming.fromJson(Map<String, dynamic> json) {
    return AudioTextTiming(
      text: json['text'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.round() ?? 0,
      endMs: (json['endMs'] as num?)?.round() ?? 0,
      chunkStartMs: (json['chunkStartMs'] as num?)?.round(),
    );
  }
}
