import 'dart:math' as math;

import 'package:flutter/services.dart';

const cefrJReadingLevelSystem = 'cefr_j';
const estimatedReadingLevelSource = 'estimated';
const userReadingLevelSource = 'user';

class ReadingLevelEstimate {
  final String system;
  final String code;
  final String source;
  final int knownWords;
  final int sampledWords;

  const ReadingLevelEstimate({
    required this.system,
    required this.code,
    required this.source,
    required this.knownWords,
    required this.sampledWords,
  });
}

class ReadingLevelEstimator {
  static const _assetPath =
      'assets/reading_levels/cefrj-vocabulary-profile-1.5.csv';
  static const _minimumKnownWords = 80;
  static const _sampleWordLimit = 5000;
  static const _minimumKnownRatio = 0.35;

  static final ReadingLevelEstimator instance = ReadingLevelEstimator._();

  Future<Map<String, int>>? _profileFuture;

  ReadingLevelEstimator._();

  Future<ReadingLevelEstimate?> estimateEnglish(Iterable<String> texts) async {
    final tokens = _tokenize(texts).take(_sampleWordLimit).toList();
    if (tokens.isEmpty) return null;

    final profile = await _loadProfile();
    final levels = <int>[];
    for (final token in tokens) {
      final level = profile[token] ?? profile[_normalizeToken(token)];
      if (level != null) levels.add(level);
    }

    if (levels.length < _minimumKnownWords) return null;
    if (levels.length / tokens.length < _minimumKnownRatio) return null;

    levels.sort();
    final percentileIndex = ((levels.length - 1) * 0.90).round();
    return ReadingLevelEstimate(
      system: cefrJReadingLevelSystem,
      code: _levelName(levels[percentileIndex]),
      source: estimatedReadingLevelSource,
      knownWords: levels.length,
      sampledWords: tokens.length,
    );
  }

  Future<Map<String, int>> _loadProfile() {
    return _profileFuture ??= _readProfile();
  }

  Future<Map<String, int>> _readProfile() async {
    final raw = await rootBundle.loadString(_assetPath);
    final rows = _parseCsv(raw);
    final profile = <String, int>{};
    for (final row in rows.skip(1)) {
      if (row.length < 3) continue;
      final headword = row[0].trim().toLowerCase();
      final level = _levelIndex(row[2]);
      if (headword.isEmpty || level == null) continue;
      final normalized = _normalizeToken(headword);
      if (normalized.isEmpty || normalized.contains(' ')) continue;
      profile.update(
        normalized,
        (existing) => math.min(existing, level),
        ifAbsent: () => level,
      );
    }
    return profile;
  }

  static Iterable<String> _tokenize(Iterable<String> texts) sync* {
    final pattern = RegExp(r"[A-Za-z]+(?:['-][A-Za-z]+)?");
    for (final text in texts) {
      for (final match in pattern.allMatches(text)) {
        final token = match.group(0)?.toLowerCase();
        if (token == null || token.length < 2) continue;
        yield token;
      }
    }
  }

  static String _normalizeToken(String token) {
    var normalized = token
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z\-']+"), '')
        .replaceAll(RegExp(r"^'+|'+$"), '');
    if (normalized.endsWith("'s")) {
      normalized = normalized.substring(0, normalized.length - 2);
    }
    if (normalized.endsWith("s'")) {
      normalized = normalized.substring(0, normalized.length - 2);
    }
    return normalized;
  }

  static int? _levelIndex(String value) {
    return switch (value.trim().toUpperCase()) {
      'A1' => 0,
      'A2' => 1,
      'B1' => 2,
      'B2' => 3,
      _ => null,
    };
  }

  static String _levelName(int index) {
    return switch (index) {
      0 => 'A1',
      1 => 'A2',
      2 => 'B1',
      _ => 'B2',
    };
  }

  static List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == '"') {
        if (inQuotes && i + 1 < raw.length && raw[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (!inQuotes && char == ',') {
        row.add(field.toString());
        field.clear();
        continue;
      }

      if (!inQuotes && (char == '\n' || char == '\r')) {
        if (char == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        if (row.any((value) => value.isNotEmpty)) {
          rows.add(List<String>.from(row));
        }
        row.clear();
        continue;
      }

      field.write(char);
    }

    row.add(field.toString());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
    return rows;
  }
}
