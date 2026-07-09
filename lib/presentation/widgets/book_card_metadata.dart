import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/app_localizations.dart';
import '../../data/database/app_database.dart' as drift_db;
import '../../domain/models/book_language.dart';

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

String bookReadingProgressLabel(BuildContext context, drift_db.Book book) {
  final percent = estimatedBookReadingProgress(book);
  return context.tr('进度 $percent%', '$percent% read');
}

int estimatedBookReadingProgress(drift_db.Book book) {
  final totalParagraphs = book.paragraphCount;
  if (totalParagraphs <= 0) return 0;

  final chapterIndex = _chapterIndexFromId(book.currentChapterId);
  if (chapterIndex == null) return 0;

  final totalChapters = book.chapterCount <= 0 ? 1 : book.chapterCount;
  final averageParagraphsPerChapter = totalParagraphs / totalChapters;
  final estimatedPosition =
      (chapterIndex * averageParagraphsPerChapter) + book.currentParagraphIndex;
  return ((estimatedPosition / totalParagraphs) * 100).clamp(0, 100).round();
}

int? _chapterIndexFromId(String? chapterId) {
  if (chapterId == null || chapterId.trim().isEmpty) return null;
  final explicit = RegExp(r'_ch_(\d+)$').firstMatch(chapterId);
  if (explicit != null) return int.tryParse(explicit.group(1)!);
  final trailing = RegExp(r'(\d+)$').firstMatch(chapterId);
  return trailing == null ? null : int.tryParse(trailing.group(1)!);
}
