class AudioTextTiming {
  final String text;
  final int startMs;
  final int endMs;

  const AudioTextTiming({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  AudioTextTiming shifted(int offsetMs) => AudioTextTiming(
    text: text,
    startMs: startMs + offsetMs,
    endMs: endMs + offsetMs,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
  };

  factory AudioTextTiming.fromJson(Map<String, dynamic> json) {
    return AudioTextTiming(
      text: json['text'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.round() ?? 0,
      endMs: (json['endMs'] as num?)?.round() ?? 0,
    );
  }
}
