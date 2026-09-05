import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import '../../domain/models/chapter_manifest.dart';
import '../../domain/models/book_rights.dart';
import '../../services/manifest_store.dart';
import '../database/app_database.dart' as drift_db;

class LibrivoxSearchResult {
  final List<LibrivoxBook> books;
  final bool hasMore;

  const LibrivoxSearchResult({required this.books, required this.hasMore});
}

class LibrivoxBook {
  final String id;
  final String title;
  final String description;
  final String language;
  final int totalTimeSeconds;
  final List<LibrivoxAuthor> authors;
  final List<LibrivoxSection> sections;
  final String? coverUrl;
  final String? projectUrl;
  final Map<String, dynamic> rawJson;

  const LibrivoxBook({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.totalTimeSeconds,
    required this.authors,
    required this.sections,
    required this.coverUrl,
    required this.projectUrl,
    required this.rawJson,
  });

  factory LibrivoxBook.fromJson(Map<String, dynamic> json) {
    final authors = (json['authors'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => LibrivoxAuthor.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final sections = (json['sections'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => LibrivoxSection.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((section) => section.listenUrl.isNotEmpty)
        .toList(growable: false);
    final rawDescription = (json['description'] as String? ?? '').trim();
    final description =
        html_parser
            .parseFragment(
              rawDescription.replaceAll(
                RegExp(r'<br\s*/?>', caseSensitive: false),
                '\n',
              ),
            )
            .text
            ?.replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
    return LibrivoxBook(
      id: json['id']?.toString() ?? '',
      title: _nonEmpty(json['title']) ?? 'Untitled',
      description: description,
      language: _nonEmpty(json['language']) ?? 'Unknown',
      totalTimeSeconds: _asInt(json['totaltimesecs']),
      authors: authors,
      sections: sections,
      coverUrl:
          _nonEmpty(json['coverart_jpg']) ??
          _nonEmpty(json['coverart_thumbnail']),
      projectUrl: _nonEmpty(json['url_librivox']),
      rawJson: json,
    );
  }

  String get authorLabel => authors.isEmpty
      ? 'Unknown'
      : authors.map((author) => author.displayName).join(', ');

  Set<String> get narratorNames => {
    for (final section in sections) ...section.readers,
  };

  bool get canImport => id.isNotEmpty && sections.isNotEmpty;
}

class LibrivoxAuthor {
  final String firstName;
  final String lastName;

  const LibrivoxAuthor({required this.firstName, required this.lastName});

  factory LibrivoxAuthor.fromJson(Map<String, dynamic> json) => LibrivoxAuthor(
    firstName: _nonEmpty(json['first_name']) ?? '',
    lastName: _nonEmpty(json['last_name']) ?? '',
  );

  String get displayName =>
      [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
}

class LibrivoxSection {
  final String id;
  final int number;
  final String title;
  final String listenUrl;
  final int playtimeSeconds;
  final List<String> readers;

  const LibrivoxSection({
    required this.id,
    required this.number,
    required this.title,
    required this.listenUrl,
    required this.playtimeSeconds,
    required this.readers,
  });

  factory LibrivoxSection.fromJson(Map<String, dynamic> json) {
    final readers = (json['readers'] as List? ?? const [])
        .whereType<Map>()
        .map((reader) => _nonEmpty(reader['display_name']))
        .whereType<String>()
        .toList(growable: false);
    return LibrivoxSection(
      id: json['id']?.toString() ?? '',
      number: _asInt(json['section_number']),
      title: _nonEmpty(json['title']) ?? 'Untitled chapter',
      listenUrl: _nonEmpty(json['listen_url']) ?? '',
      playtimeSeconds: _asInt(json['playtime']),
      readers: readers,
    );
  }

  String get narratorLabel =>
      readers.isEmpty ? 'LibriVox volunteer' : readers.join(', ');
}

class LibrivoxRepository {
  final Dio _dio;

  LibrivoxRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://librivox.org',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
            ),
          );

  Future<LibrivoxSearchResult> search({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final normalized = query.trim();
    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/api/feed/audiobooks',
        queryParameters: {
          'format': 'json',
          'extended': 1,
          'coverart': 1,
          'limit': pageSize + 1,
          'offset': (page - 1) * pageSize,
          if (normalized.isNotEmpty) 'title': '^$normalized',
        },
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const LibrivoxSearchResult(books: [], hasMore: false);
      }
      rethrow;
    }
    final decoded = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (decoded is! Map) {
      throw StateError('LibriVox returned an invalid response.');
    }
    final rawBooks = (decoded['books'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => LibrivoxBook.fromJson(Map<String, dynamic>.from(item)))
        .where((book) => book.canImport)
        .toList();
    final hasMore = rawBooks.length > pageSize;
    return LibrivoxSearchResult(
      books: rawBooks.take(pageSize).toList(growable: false),
      hasMore: hasMore,
    );
  }

  Future<drift_db.Book> importAudiobook({
    required LibrivoxBook book,
    required drift_db.AppDatabase database,
    required ManifestStore manifestStore,
    required String appDir,
  }) async {
    if (!book.canImport) {
      throw StateError('This LibriVox book has no playable chapters.');
    }
    final existing = await database.getBookByExternalSource(
      librivoxSourceId,
      book.id,
    );
    if (existing != null) return existing;

    final bookId = 'librivox-${book.id}';
    final bookDir = Directory(p.join(appDir, 'books', bookId));
    await bookDir.create(recursive: true);
    final sourceFile = File(p.join(bookDir.path, 'librivox.txt'));
    await sourceFile.writeAsString(
      [
        book.title,
        book.authorLabel,
        book.description,
      ].where((line) => line.isNotEmpty).join('\n\n'),
    );
    final coverPath = await _downloadCover(book, bookDir);
    final now = DateTime.now().millisecondsSinceEpoch;
    final chapters = <drift_db.Chapter>[];
    final paragraphs = <drift_db.Paragraph>[];
    final manifests = <ChapterManifest>[];

    for (var index = 0; index < book.sections.length; index++) {
      final section = book.sections[index];
      final chapterId =
          '$bookId-chapter-${section.id.isEmpty ? index + 1 : section.id}';
      final paragraphId = '$chapterId-audio';
      chapters.add(
        drift_db.Chapter(
          id: chapterId,
          bookId: bookId,
          chapterIndex: index,
          title: section.title,
          textOffset: 0,
          voiceId: section.narratorLabel,
          isHidden: false,
        ),
      );
      paragraphs.add(
        drift_db.Paragraph(
          id: paragraphId,
          chapterId: chapterId,
          bookId: bookId,
          paragraphIndex: 0,
          content: 'Narrated by ${section.narratorLabel}.',
        ),
      );
      manifests.add(
        ChapterManifest(
          chapterId: chapterId,
          bookId: bookId,
          providerId: librivoxSourceId,
          voiceId: section.narratorLabel,
          speed: 1,
          segments: [
            SegmentEntry(
              paragraphId: paragraphId,
              audioFile: section.listenUrl,
              durationMs: section.playtimeSeconds * 1000,
              state: ParagraphAudioState.ready,
              format: 'mp3',
            ),
          ],
          updatedAt: now,
        ),
      );
    }

    final metadataJson = jsonEncode({
      'source': librivoxSourceId,
      'source_url': book.projectUrl,
      'rights_status': publicDomainRightsStatus,
      'description': book.description,
      'narrators': book.narratorNames.toList(),
      'streaming_audio': true,
      'raw': book.rawJson,
    });
    final row = drift_db.Book(
      id: bookId,
      title: book.title,
      author: book.authorLabel,
      format: 'txt',
      sourcePath: sourceFile.path,
      coverPath: coverPath,
      chapterCount: chapters.length,
      paragraphCount: paragraphs.length,
      currentChapterId: null,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      voiceId: null,
      importedAt: now,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      externalSource: librivoxSourceId,
      externalId: book.id,
      rightsStatus: publicDomainRightsStatus,
      externalMetadataJson: metadataJson,
      language: book.language,
      readingLevelSystem: null,
      readingLevelCode: null,
      readingLevelSource: null,
    );
    await database.replaceBookData(
      book: row,
      chapterEntries: chapters,
      paragraphEntries: paragraphs,
    );
    for (final manifest in manifests) {
      await manifestStore.save(manifest);
    }
    return row;
  }

  Future<String?> _downloadCover(LibrivoxBook book, Directory bookDir) async {
    final url = book.coverUrl;
    if (url == null) return null;
    try {
      final output = File(p.join(bookDir.path, 'cover_librivox.jpg'));
      await _dio.download(url, output.path);
      return output.path;
    } catch (_) {
      return null;
    }
  }
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
