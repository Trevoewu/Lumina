import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../data/database/app_database.dart';
import '../services/podcast_transcription_service.dart';
import 'ai_models.dart';

class AiTranscriptLine {
  final String reference;
  final String text;
  final int? positionMs;

  const AiTranscriptLine({
    required this.reference,
    required this.text,
    this.positionMs,
  });

  Map<String, Object?> toJson() => {
    'reference': reference,
    'text': text,
    if (positionMs != null) 'position_ms': positionMs,
  };
}

class AiTranscriptSnapshot {
  final AiContentScope scope;
  final List<AiTranscriptLine> lines;
  final String fingerprint;

  const AiTranscriptSnapshot({
    required this.scope,
    required this.lines,
    required this.fingerprint,
  });

  bool get isAvailable => lines.isNotEmpty;
}

class AiTranscriptTools {
  static const defaultChunkCharacters = 12000;
  static const maximumChunkCharacters = 24000;

  final AppDatabase database;

  const AiTranscriptTools(this.database);

  Future<AiTranscriptSnapshot> load(AiContentScope scope) async {
    final lines = scope.isPodcast
        ? await _podcastLines(scope.id)
        : await _chapterLines(scope.id);
    final canonical = lines
        .map((line) => '${line.reference}\u0000${line.text}')
        .join('\u0001');
    return AiTranscriptSnapshot(
      scope: scope,
      lines: lines,
      fingerprint: sha256.convert(utf8.encode(canonical)).toString(),
    );
  }

  String execute(
    AiTranscriptSnapshot snapshot,
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    return switch (toolName) {
      'read_transcript' => _readTranscript(snapshot, arguments),
      'search_transcript' => _searchTranscript(snapshot, arguments),
      _ => jsonEncode({
        'error': 'unknown_tool',
        'message': 'Unsupported tool: $toolName',
      }),
    };
  }

  String _readTranscript(
    AiTranscriptSnapshot snapshot,
    Map<String, dynamic> arguments,
  ) {
    if (!snapshot.isAvailable) {
      return jsonEncode({'error': 'transcript_unavailable', 'items': const []});
    }
    final requestedCursor = arguments['cursor'];
    final cursor = requestedCursor is int
        ? requestedCursor.clamp(0, snapshot.lines.length)
        : 0;
    final requestedMax = arguments['max_characters'];
    final maxCharacters = requestedMax is int
        ? requestedMax.clamp(1000, maximumChunkCharacters)
        : defaultChunkCharacters;
    final items = <AiTranscriptLine>[];
    var used = 0;
    var nextCursor = cursor;
    while (nextCursor < snapshot.lines.length) {
      final line = snapshot.lines[nextCursor];
      final lineLength = line.text.length + line.reference.length + 4;
      if (items.isNotEmpty && used + lineLength > maxCharacters) break;
      items.add(line);
      used += lineLength;
      nextCursor++;
    }
    return jsonEncode({
      'scope': snapshot.scope.type.value,
      'title': snapshot.scope.title,
      'cursor': cursor,
      'next_cursor': nextCursor,
      'has_more': nextCursor < snapshot.lines.length,
      'items': items.map((line) => line.toJson()).toList(growable: false),
    });
  }

  String _searchTranscript(
    AiTranscriptSnapshot snapshot,
    Map<String, dynamic> arguments,
  ) {
    final query = (arguments['query'] as String? ?? '').trim().toLowerCase();
    final requestedLimit = arguments['limit'];
    final limit = requestedLimit is int ? requestedLimit.clamp(1, 20) : 8;
    if (query.isEmpty) {
      return jsonEncode({
        'error': 'invalid_query',
        'message': 'query must not be empty',
        'items': const [],
      });
    }
    final matches = snapshot.lines
        .where((line) => line.text.toLowerCase().contains(query))
        .take(limit)
        .map((line) => line.toJson())
        .toList(growable: false);
    return jsonEncode({'query': query, 'items': matches});
  }

  Future<List<AiTranscriptLine>> _chapterLines(String chapterId) async {
    final paragraphs = await database.getParagraphs(chapterId);
    return [
      for (final paragraph in paragraphs)
        if (paragraph.content.trim().isNotEmpty)
          AiTranscriptLine(
            reference: 'P${paragraph.paragraphIndex + 1}',
            text: paragraph.content.trim(),
          ),
    ];
  }

  Future<List<AiTranscriptLine>> _podcastLines(String episodeId) async {
    final episode = await database.getPodcastEpisode(episodeId);
    if (episode == null) return const [];
    final timings = PodcastTranscriptionService.decodeTranscript(
      episode.transcriptJson,
    );
    return [
      for (final timing in timings)
        if (timing.text.trim().isNotEmpty)
          AiTranscriptLine(
            reference: _formatTimestamp(math.max(0, timing.startMs)),
            text: timing.text.trim(),
            positionMs: math.max(0, timing.startMs),
          ),
    ];
  }

  String _formatTimestamp(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return hours > 0
        ? '${two(hours)}:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}
