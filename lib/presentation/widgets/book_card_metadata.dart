import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/app_localizations.dart';
import '../../data/database/app_database.dart' as drift_db;
import '../../domain/models/book_language.dart';
import '../../services/reading_level_estimator.dart';

String bookLanguageLabel(BuildContext context, drift_db.Book book) {
  final saved = normalizeBookLanguage(book.language);
  if (saved != null) return saved;

  final metadata = book.externalMetadataJson;
  if (metadata != null && metadata.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(metadata);
      final raw = decoded is Map<String, dynamic> ? decoded['raw'] : null;
      final languages = raw is Map<String, dynamic> ? raw['languages'] : null;
      if (languages is List) {
        final labels = languages
            .whereType<String>()
            .map(normalizeBookLanguage)
            .whereType<String>()
            .toList();
        if (labels.isNotEmpty) return labels.join(', ');
      }
    } catch (_) {
      // Metadata is best-effort display data; malformed JSON should not break UI.
    }
  }

  return inferLanguageFromTitle(book.title) ??
      context.tr('未知语言', 'Unknown language');
}

String bookReadingProgressLabel(
  BuildContext context,
  drift_db.Book book, {
  Iterable<int> finishedChapterIndexes = const <int>[],
}) {
  final percent = estimatedBookReadingProgress(
    book,
    finishedChapterIndexes: finishedChapterIndexes,
  );
  return context.tr('进度 $percent%', '$percent% read');
}

String? bookReadingLevelLabel(BuildContext context, drift_db.Book book) {
  final code = normalizeCefrReadingLevel(book.readingLevelCode);
  if (code == null) return null;

  final source = book.readingLevelSource;
  if (source == estimatedReadingLevelSource) {
    return context.tr('难度估算 $code', 'CEFR est. $code');
  }
  return context.tr('难度 $code', 'CEFR $code');
}

String? normalizeCefrReadingLevel(String? value) {
  final normalized = value?.trim().toUpperCase();
  if (normalized == null || normalized.isEmpty) return null;
  return switch (normalized) {
    'A1' || 'A2' || 'B1' || 'B2' => normalized,
    _ => null,
  };
}

int estimatedBookReadingProgress(
  drift_db.Book book, {
  Iterable<int> finishedChapterIndexes = const <int>[],
}) {
  final totalParagraphs = book.paragraphCount;
  if (totalParagraphs <= 0) return 0;

  final chapterIndex = _chapterIndexFromId(book.currentChapterId);
  final totalChapters = book.chapterCount <= 0 ? 1 : book.chapterCount;
  final averageParagraphsPerChapter = totalParagraphs / totalChapters;
  final finishedIndexes = finishedChapterIndexes
      .where((index) => index >= 0 && index < totalChapters)
      .toSet();
  var estimatedPosition = chapterIndex == null
      ? 0.0
      : (chapterIndex * averageParagraphsPerChapter) +
            book.currentParagraphIndex;

  for (final finishedIndex in finishedIndexes) {
    if (chapterIndex == null || finishedIndex > chapterIndex) {
      estimatedPosition += averageParagraphsPerChapter;
    } else if (finishedIndex == chapterIndex) {
      final partialChapterPosition = book.currentParagraphIndex.clamp(
        0,
        averageParagraphsPerChapter,
      );
      estimatedPosition += averageParagraphsPerChapter - partialChapterPosition;
    }
  }
  return ((estimatedPosition / totalParagraphs) * 100).clamp(0, 100).round();
}

int? _chapterIndexFromId(String? chapterId) {
  if (chapterId == null || chapterId.trim().isEmpty) return null;
  final explicit = RegExp(r'_ch_(\d+)$').firstMatch(chapterId);
  if (explicit != null) return int.tryParse(explicit.group(1)!);
  final trailing = RegExp(r'(\d+)$').firstMatch(chapterId);
  return trailing == null ? null : int.tryParse(trailing.group(1)!);
}
