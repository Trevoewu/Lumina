import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/book_rights.dart';
import '../../services/book_parser.dart';
import '../database/app_database.dart' as drift_db;

class GutendexSearchResult {
  final int count;
  final String? next;
  final String? previous;
  final List<GutendexBook> books;

  const GutendexSearchResult({
    required this.count,
    required this.books,
    this.next,
    this.previous,
  });

  factory GutendexSearchResult.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    return GutendexSearchResult(
      count: (json['count'] as num?)?.toInt() ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      books: rawResults is List
          ? rawResults
                .whereType<Map<String, dynamic>>()
                .map(GutendexBook.fromJson)
                .toList()
          : const [],
    );
  }
}

class GutendexBook {
  final int id;
  final String title;
  final List<GutendexPerson> authors;
  final List<String> languages;
  final List<String> summaries;
  final bool? copyright;
  final int downloadCount;
  final Map<String, String> formats;
  final Map<String, dynamic> rawJson;

  const GutendexBook({
    required this.id,
    required this.title,
    required this.authors,
    required this.languages,
    required this.summaries,
    required this.copyright,
    required this.downloadCount,
    required this.formats,
    required this.rawJson,
  });

  factory GutendexBook.fromJson(Map<String, dynamic> json) {
    final rawAuthors = json['authors'];
    final rawLanguages = json['languages'];
    final rawSummaries = json['summaries'];
    final rawFormats = json['formats'];
    return GutendexBook(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Untitled',
      authors: rawAuthors is List
          ? rawAuthors
                .whereType<Map<String, dynamic>>()
                .map(GutendexPerson.fromJson)
                .toList()
          : const [],
      languages: rawLanguages is List
          ? rawLanguages.whereType<String>().toList()
          : const [],
      summaries: rawSummaries is List
          ? rawSummaries
                .whereType<String>()
                .map((summary) => summary.trim())
                .where((summary) => summary.isNotEmpty)
                .toList()
          : const [],
      copyright: json['copyright'] as bool?,
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      formats: rawFormats is Map
          ? rawFormats.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      rawJson: json,
    );
  }

  String get authorLabel {
    if (authors.isEmpty) return 'Unknown';
    return authors.map((author) => author.name).join(', ');
  }

  String get languageLabel =>
      languages.isEmpty ? 'unknown' : languages.join(', ');

  String? get coverUrl => formats['image/jpeg'];

  String? get summary => summaries.isEmpty ? null : summaries.first;

  bool get isPublicDomain => copyright == false;

  String? get epubUrl {
    final exact = formats['application/epub+zip'];
    if (exact != null) return exact;
    for (final entry in formats.entries) {
      if (entry.key.toLowerCase().contains('epub')) return entry.value;
    }
    return null;
  }

  String? get textUrl {
    final utf8 = formats['text/plain; charset=utf-8'];
    if (utf8 != null) return utf8;
    for (final entry in formats.entries) {
      if (entry.key.toLowerCase().startsWith('text/plain')) {
        return entry.value;
      }
    }
    return null;
  }

  String? get preferredDownloadUrl => epubUrl ?? textUrl;

  String get preferredExtension => epubUrl != null ? '.epub' : '.txt';

  bool get canImport => isPublicDomain && preferredDownloadUrl != null;
}

class GutendexPerson {
  final String name;
  final int? birthYear;
  final int? deathYear;

  const GutendexPerson({required this.name, this.birthYear, this.deathYear});

  factory GutendexPerson.fromJson(Map<String, dynamic> json) {
    return GutendexPerson(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Unknown',
      birthYear: (json['birth_year'] as num?)?.toInt(),
      deathYear: (json['death_year'] as num?)?.toInt(),
    );
  }
}

class GutendexRepository {
  final Dio _dio;

  GutendexRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://gutendex.com',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
            ),
          );

  Future<GutendexSearchResult> search({
    required String query,
    int page = 1,
  }) async {
    final parameters = <String, dynamic>{
      'copyright': 'false',
      'sort': query.trim().isEmpty ? 'popular' : 'popular',
      if (query.trim().isNotEmpty) 'search': query.trim(),
      if (page > 1) 'page': page,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/books/',
      queryParameters: parameters,
    );
    final data = response.data;
    if (data == null) throw StateError('Gutendex returned an empty response');
    return GutendexSearchResult.fromJson(data);
  }

  Future<drift_db.Book> importPublicDomainBook({
    required GutendexBook book,
    required drift_db.AppDatabase database,
    required String appDir,
    void Function(int received, int total)? onDownloadProgress,
  }) async {
    if (!book.isPublicDomain) {
      throw StateError('This Gutendex book is not marked public domain.');
    }
    final sourceUrl = book.preferredDownloadUrl;
    if (sourceUrl == null) {
      throw StateError('No EPUB or plain text download is available.');
    }

    final existing = await database.getBookByExternalSource(
      gutendexSourceId,
      book.id.toString(),
    );
    if (existing != null) return existing;

    final importDir = Directory(p.join(appDir, 'imports', gutendexSourceId));
    await importDir.create(recursive: true);
    final tempSource = File(
      p.join(importDir.path, '${book.id}${book.preferredExtension}'),
    );
    await _dio.download(
      sourceUrl,
      tempSource.path,
      onReceiveProgress: onDownloadProgress,
    );

    final parsed = await BookParser.parse(
      sourcePath: tempSource.path,
      appDir: appDir,
    );
    await tempSource.delete().catchError((_) => tempSource);

    final coverPath =
        parsed.book.coverPath ??
        await _downloadCover(
          book: book,
          bookId: parsed.book.id,
          appDir: appDir,
        );
    final metadataJson = jsonEncode({
      'source': gutendexSourceId,
      'source_url': 'https://gutendex.com/books/${book.id}',
      'download_url': sourceUrl,
      'rights_status': publicDomainRightsStatus,
      'raw': book.rawJson,
    });

    final row = drift_db.Book(
      id: parsed.book.id,
      title: book.title,
      author: book.authors.isEmpty ? parsed.book.author : book.authorLabel,
      language: book.languages.isEmpty ? null : book.languages.join(','),
      format: parsed.book.format.name,
      sourcePath: parsed.book.sourcePath,
      coverPath: coverPath,
      chapterCount: parsed.book.chapterCount,
      paragraphCount: parsed.book.paragraphCount,
      currentChapterId: parsed.book.currentChapterId,
      currentParagraphIndex: parsed.book.currentParagraphIndex,
      playbackOffsetMs: parsed.book.playbackOffsetMs,
      voiceId: parsed.book.voiceId,
      importedAt: parsed.book.importedAt,
      lastReadAt: parsed.book.lastReadAt,
      kind: 'book',
      externalSource: gutendexSourceId,
      externalId: book.id.toString(),
      rightsStatus: publicDomainRightsStatus,
      externalMetadataJson: metadataJson,
    );

    await database.replaceBookData(
      book: row,
      chapterEntries: parsed.chapters
          .map(
            (chapter) => drift_db.Chapter(
              id: chapter.id,
              bookId: chapter.bookId,
              chapterIndex: chapter.index,
              title: chapter.title,
              textOffset: chapter.textOffset,
            ),
          )
          .toList(),
      paragraphEntries: parsed.paragraphs
          .map(
            (paragraph) => drift_db.Paragraph(
              id: paragraph.id,
              chapterId: paragraph.chapterId,
              bookId: paragraph.bookId,
              paragraphIndex: paragraph.index,
              content: paragraph.text,
            ),
          )
          .toList(),
    );
    return row;
  }

  Future<String?> _downloadCover({
    required GutendexBook book,
    required String bookId,
    required String appDir,
  }) async {
    final url = book.coverUrl;
    if (url == null) return null;
    try {
      final coverDir = Directory(p.join(appDir, 'books', bookId));
      await coverDir.create(recursive: true);
      final output = File(p.join(coverDir.path, 'cover_gutendex.jpg'));
      await _dio.download(url, output.path);
      return output.path;
    } catch (_) {
      return null;
    }
  }
}
