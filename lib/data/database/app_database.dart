import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────
// 表定义
// ─────────────────────────────────────────────

/// 书籍表。
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get format => text()(); // 'epub' | 'txt'
  TextColumn get sourcePath => text()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get chapterCount => integer().withDefault(const Constant(0))();
  IntColumn get paragraphCount => integer().withDefault(const Constant(0))();
  TextColumn get currentChapterId => text().nullable()();
  IntColumn get currentParagraphIndex =>
      integer().withDefault(const Constant(0))();
  IntColumn get playbackOffsetMs => integer().withDefault(const Constant(0))();
  TextColumn get voiceId => text().nullable()();
  IntColumn get importedAt => integer()();
  IntColumn get lastReadAt => integer().withDefault(const Constant(0))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get kind => text().withDefault(const Constant('book'))();
  TextColumn get externalSource => text().nullable()();
  TextColumn get externalId => text().nullable()();
  TextColumn get rightsStatus =>
      text().withDefault(const Constant('user_uploaded'))();
  TextColumn get externalMetadataJson => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get readingLevelSystem => text().nullable()();
  TextColumn get readingLevelCode => text().nullable()();
  TextColumn get readingLevelSource => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 章节表。
class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer().named('chapter_index')();
  TextColumn get title => text()();
  IntColumn get textOffset => integer().withDefault(const Constant(0))();

  /// Optional narrator override for this chapter.
  TextColumn get voiceId => text().nullable()();

  /// Hidden chapters remain in the database and can be restored later.
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
}

/// 每章独立的播放位置。
///
/// Books 中的进度仍表示“整本书最后播放到哪里”，这里则保留每个播放过
/// 的章节，供章节列表展示进度并在重新进入该章时续播。
@DataClassName('ChapterPlaybackProgress')
class ChapterPlaybackProgresses extends Table {
  TextColumn get chapterId => text()();
  TextColumn get bookId => text()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get paragraphIndex => integer().withDefault(const Constant(0))();
  IntColumn get paragraphOffsetMs => integer().withDefault(const Constant(0))();
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {chapterId};
}

/// 段落表。段落可能很多，用 chapterId + index 建索引。
class Paragraphs extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text()();
  TextColumn get bookId => text()();
  IntColumn get paragraphIndex => integer().named('paragraph_index')();
  TextColumn get content => text().named('text')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {chapterId, paragraphIndex},
  ];
}

/// 书签表。
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get chapterId => text()();
  IntColumn get paragraphIndex => integer()();
  TextColumn get excerpt => text()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 音色表。
class Voices extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get providerId => text()();
  TextColumn get type => text()(); // 'preset' | 'clone' | 'description'
  TextColumn get providerVoiceId => text()();
  TextColumn get samplePath => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get presetDescription => text().nullable()();
  TextColumn get previewUrl => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// App 设置表（KV 存储）。
/// API Key 等敏感信息不存这里，存 flutter_secure_storage。
/// 这里存非敏感的：当前 Provider、当前音色、字体大小、主题等。
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 成本记录表（用于预算告警）。
class CostRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get chapterId => text()();
  TextColumn get providerId => text()();
  IntColumn get characters => integer()();
  IntColumn get createdAt => integer()();
}

/// 每日真实收听时长。日期使用设备本地时区的 YYYY-MM-DD。
class ListeningDays extends Table {
  TextColumn get dateKey => text()();
  IntColumn get listenedMs => integer().withDefault(const Constant(0))();
  IntColumn get sessions => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {dateKey};
}

/// Vocabulary.com 查询结果。成功结果永久保留，避免重复网络请求。
class DictionaryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get provider => text()();
  TextColumn get language => text()();
  TextColumn get normalizedTerm => text()();
  TextColumn get displayWord => text()();
  TextColumn get status => text()();
  TextColumn get usPhonetic => text().nullable()();
  TextColumn get ukPhonetic => text().nullable()();
  TextColumn get definitionsJson => text().nullable()();
  TextColumn get otherFormsJson => text().nullable()();
  TextColumn get shortExplanation => text().nullable()();
  TextColumn get longExplanation => text().nullable()();
  TextColumn get sourceUrl => text()();
  TextColumn get readingLevelSystem => text().nullable()();
  TextColumn get readingLevelCode => text().nullable()();
  TextColumn get readingLevelSource => text().nullable()();
  IntColumn get fetchedAt => integer()();
  IntColumn get expiresAt => integer().nullable()();
  IntColumn get lastAccessedAt => integer()();
  IntColumn get accessCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {provider, language, normalizedTerm},
  ];
}

/// 用户收藏的词条。上下文为快照，不随原书删除。
class FavoriteWords extends Table {
  TextColumn get id => text()();
  TextColumn get dictionaryEntryId => text()();
  TextColumn get contextText => text().nullable()();
  IntColumn get selectionStart => integer().nullable()();
  IntColumn get selectionEnd => integer().nullable()();
  TextColumn get sourceBookId => text().nullable()();
  TextColumn get sourceBookTitle => text().nullable()();
  TextColumn get sourceChapterId => text().nullable()();
  TextColumn get sourceChapterTitle => text().nullable()();
  TextColumn get sourceParagraphId => text().nullable()();
  TextColumn get sourceLineId => text().nullable()();
  IntColumn get audioStartMs => integer().nullable()();
  IntColumn get audioEndMs => integer().nullable()();
  IntColumn get favoritedAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {dictionaryEntryId},
  ];
}

/// 用户订阅的 Podcast 节目。
class PodcastShows extends Table {
  TextColumn get id => text()();
  TextColumn get feedUrl => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get websiteUrl => text().nullable()();
  TextColumn get categoriesJson => text().nullable()();
  IntColumn get subscribedAt => integer()();
  IntColumn get lastRefreshedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {feedUrl},
  ];
}

/// Podcast 单集、播放进度与本地转写结果。
class PodcastEpisodes extends Table {
  TextColumn get id => text()();
  TextColumn get showId => text()();
  TextColumn get guid => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get audioUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get publishedAt => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get playbackPositionMs =>
      integer().withDefault(const Constant(0))();
  IntColumn get lastPlayedAt => integer().withDefault(const Constant(0))();
  BoolColumn get isPlayed => boolean().withDefault(const Constant(false))();
  TextColumn get localAudioPath => text().nullable()();
  TextColumn get transcriptJson => text().nullable()();
  TextColumn get transcriptLanguage => text().nullable()();
  TextColumn get transcriptStatus =>
      text().withDefault(const Constant('none'))();
  TextColumn get transcriptError => text().nullable()();

  /// Audio offset already covered by fully transcribed chunks. A paused run
  /// resumes from here instead of listening to the episode again.
  IntColumn get transcriptProgressMs =>
      integer().withDefault(const Constant(0))();
  TextColumn get sourceTranscriptUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {showId, guid},
  ];
}

/// One durable AI conversation per audiobook chapter or podcast episode.
class AiThreads extends Table {
  TextColumn get id => text()();
  TextColumn get scopeType => text()(); // 'chapter' | 'episode'
  TextColumn get scopeId => text()();
  TextColumn get scopeParentId => text()(); // book id | show id
  TextColumn get contentFingerprint => text()();
  TextColumn get summaryText => text().nullable()();
  TextColumn get remoteConversationId => text().nullable()();
  TextColumn get lastResponseId => text().nullable()();
  TextColumn get modelId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {scopeType, scopeId},
  ];
}

/// Locally persisted user-visible messages for an AI thread.
class AiMessages extends Table {
  TextColumn get id => text()();
  TextColumn get threadId => text()();
  TextColumn get role => text()(); // 'user' | 'assistant'
  TextColumn get kind => text().withDefault(const Constant('chat'))();
  TextColumn get content => text()();
  TextColumn get citationsJson => text().nullable()();
  TextColumn get responseId => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────
// 数据库
// ─────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Books,
    Chapters,
    ChapterPlaybackProgresses,
    Paragraphs,
    Bookmarks,
    Voices,
    AppSettings,
    CostRecords,
    ListeningDays,
    DictionaryEntries,
    FavoriteWords,
    PodcastShows,
    PodcastEpisodes,
    AiThreads,
    AiMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  final bool _repairPathsOnOpen;

  AppDatabase() : _repairPathsOnOpen = true, super(_open());

  AppDatabase.forTesting(super.e) : _repairPathsOnOpen = false;

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(books, books.kind);
      }
      if (from < 3) {
        await m.createTable(listeningDays);
      }
      if (from < 4) {
        await m.createTable(dictionaryEntries);
        await m.createTable(favoriteWords);
      }
      if (from < 5) {
        await m.addColumn(books, books.externalSource);
        await m.addColumn(books, books.externalId);
        await m.addColumn(books, books.rightsStatus);
        await m.addColumn(books, books.externalMetadataJson);
      }
      if (from < 6) {
        await m.addColumn(books, books.language);
      }
      if (from < 7) {
        await m.addColumn(books, books.readingLevelSystem);
        await m.addColumn(books, books.readingLevelCode);
        await m.addColumn(books, books.readingLevelSource);
      }
      if (from >= 4 && from < 8) {
        await m.addColumn(
          dictionaryEntries,
          dictionaryEntries.readingLevelSystem,
        );
        await m.addColumn(
          dictionaryEntries,
          dictionaryEntries.readingLevelCode,
        );
        await m.addColumn(
          dictionaryEntries,
          dictionaryEntries.readingLevelSource,
        );
      }
      if (from < 9) {
        final chapterTableExists =
            await m.database
                .customSelect(
                  "SELECT 1 FROM sqlite_master WHERE type = 'table' "
                  "AND name = 'chapters'",
                )
                .getSingleOrNull() !=
            null;
        if (chapterTableExists) {
          await m.addColumn(chapters, chapters.voiceId);
          await m.addColumn(chapters, chapters.isHidden);
        } else {
          // Defensive support for very early databases that did not yet have
          // chapter rows (including the original import-only schema).
          await m.createTable(chapters);
        }
      }
      if (from < 10) {
        await m.createTable(podcastShows);
        await m.createTable(podcastEpisodes);
      }
      if (from < 11) {
        await m.createTable(chapterPlaybackProgresses);
      }
      if (from >= 10 && from < 12) {
        await m.addColumn(podcastShows, podcastShows.categoriesJson);
      }
      if (from >= 11 && from < 13) {
        await m.addColumn(
          chapterPlaybackProgresses,
          chapterPlaybackProgresses.isFinished,
        );
      }
      if (from < 14) {
        await m.createTable(aiThreads);
        await m.createTable(aiMessages);
      }
      if (from < 15) {
        final booksTableExists =
            await m.database
                .customSelect(
                  "SELECT 1 FROM sqlite_master WHERE type = 'table' "
                  "AND name = 'books'",
                )
                .getSingleOrNull() !=
            null;
        if (booksTableExists) {
          await m.addColumn(books, books.isRead);
        } else {
          await m.createTable(books);
        }
      }
      if (from >= 10 && from < 16) {
        // A database can carry the podcast schema version without ever having
        // created the episodes table (shows-only imports from schema 10).
        final episodesTableExists =
            await m.database
                .customSelect(
                  "SELECT 1 FROM sqlite_master WHERE type = 'table' "
                  "AND name = 'podcast_episodes'",
                )
                .getSingleOrNull() !=
            null;
        if (episodesTableExists) {
          await m.addColumn(
            podcastEpisodes,
            podcastEpisodes.transcriptProgressMs,
          );
        } else {
          await m.createTable(podcastEpisodes);
        }
      }
    },
    beforeOpen: (_) async {
      if (_repairPathsOnOpen) {
        final documents = await getApplicationDocumentsDirectory();
        await repairMovedDocumentPaths(documents.path);
      }
    },
  );

  // ── 书籍 ──

  Future<List<Book>> getAllBooks() => select(books).get();

  Stream<List<Book>> watchAllBooks() => select(books).watch();

  Future<Book?> getBook(String id) =>
      (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<Book?> getBookByExternalSource(String source, String externalId) =>
      (select(books)..where(
            (b) =>
                b.externalSource.equals(source) &
                b.externalId.equals(externalId),
          ))
          .getSingleOrNull();

  Future<void> upsertBook(Book entry) =>
      into(books).insertOnConflictUpdate(entry);

  Future<void> updateBookCoverPath(String bookId, String coverPath) async {
    await (update(books)..where((b) => b.id.equals(bookId))).write(
      BooksCompanion(coverPath: Value(coverPath)),
    );
  }

  Future<void> updateBookReadStatus(String bookId, bool isRead) async {
    await (update(books)..where((book) => book.id.equals(bookId))).write(
      BooksCompanion(isRead: Value(isRead)),
    );
  }

  Future<void> updateBookExternalMetadata(
    String bookId,
    String metadataJson,
  ) async {
    await (update(books)..where((b) => b.id.equals(bookId))).write(
      BooksCompanion(externalMetadataJson: Value(metadataJson)),
    );
  }

  /// iOS may assign a new app-container UUID after an update. Repair absolute
  /// paths saved under the previous Documents directory when the files are
  /// still present in the current container.
  Future<void> repairMovedDocumentPaths(String currentDocumentsPath) async {
    final entries = await select(books).get();
    for (final book in entries) {
      final sourcePath = await _existingRebasedPath(
        book.sourcePath,
        currentDocumentsPath,
      );
      final coverPath = book.coverPath == null
          ? null
          : await _existingRebasedPath(book.coverPath!, currentDocumentsPath);

      if (sourcePath == book.sourcePath && coverPath == book.coverPath) {
        continue;
      }
      await (update(books)..where((row) => row.id.equals(book.id))).write(
        BooksCompanion(
          sourcePath: Value(sourcePath),
          coverPath: coverPath == null
              ? const Value.absent()
              : Value(coverPath),
        ),
      );
    }
  }

  Future<void> updateBookMetadata(
    String bookId, {
    String? title,
    String? author,
    String? coverPath,
    String? voiceId,
    String? language,
    String? readingLevelSystem,
    String? readingLevelCode,
    String? readingLevelSource,
    bool clearAuthor = false,
    bool clearCover = false,
    bool clearLanguage = false,
    bool clearReadingLevel = false,
  }) async {
    await (update(books)..where((b) => b.id.equals(bookId))).write(
      BooksCompanion(
        title: title == null ? const Value.absent() : Value(title),
        author: clearAuthor
            ? const Value(null)
            : author == null
            ? const Value.absent()
            : Value(author),
        coverPath: clearCover
            ? const Value(null)
            : coverPath == null
            ? const Value.absent()
            : Value(coverPath),
        voiceId: voiceId == null ? const Value.absent() : Value(voiceId),
        language: clearLanguage
            ? const Value(null)
            : language == null
            ? const Value.absent()
            : Value(language),
        readingLevelSystem: clearReadingLevel
            ? const Value(null)
            : readingLevelSystem == null
            ? const Value.absent()
            : Value(readingLevelSystem),
        readingLevelCode: clearReadingLevel
            ? const Value(null)
            : readingLevelCode == null
            ? const Value.absent()
            : Value(readingLevelCode),
        readingLevelSource: clearReadingLevel
            ? const Value(null)
            : readingLevelSource == null
            ? const Value.absent()
            : Value(readingLevelSource),
      ),
    );
  }

  Future<void> deleteBook(String id) =>
      (delete(books)..where((b) => b.id.equals(id))).go();

  Future<void> deleteBookCascade(String id) async {
    await transaction(() async {
      await _deleteAiThreadsForParent('chapter', id);
      await (delete(bookmarks)..where((b) => b.bookId.equals(id))).go();
      await (delete(
        chapterPlaybackProgresses,
      )..where((p) => p.bookId.equals(id))).go();
      await (delete(paragraphs)..where((p) => p.bookId.equals(id))).go();
      await (delete(chapters)..where((c) => c.bookId.equals(id))).go();
      await (delete(books)..where((b) => b.id.equals(id))).go();
    });
  }

  Future<void> updateReadingProgress(
    String bookId, {
    String? chapterId,
    int? paragraphIndex,
    int? offsetMs,
    int? chapterPositionMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await (update(books)..where((b) => b.id.equals(bookId))).write(
        BooksCompanion(
          currentChapterId: chapterId == null
              ? const Value.absent()
              : Value(chapterId),
          currentParagraphIndex: paragraphIndex == null
              ? const Value.absent()
              : Value(paragraphIndex),
          playbackOffsetMs: offsetMs == null
              ? const Value.absent()
              : Value(offsetMs),
          lastReadAt: Value(now),
        ),
      );
      if (chapterId != null && chapterPositionMs != null) {
        final existing = await getChapterPlaybackProgress(chapterId);
        await into(chapterPlaybackProgresses).insertOnConflictUpdate(
          ChapterPlaybackProgress(
            chapterId: chapterId,
            bookId: bookId,
            positionMs: chapterPositionMs,
            paragraphIndex: paragraphIndex ?? 0,
            paragraphOffsetMs: offsetMs ?? 0,
            isFinished: existing?.isFinished ?? false,
            updatedAt: now,
          ),
        );
      }
    });
  }

  // ── 章节 ──

  Future<List<Chapter>> getChapters(
    String bookId, {
    bool includeHidden = false,
  }) =>
      (select(chapters)
            ..where(
              (c) =>
                  c.bookId.equals(bookId) &
                  (includeHidden
                      ? const Constant(true)
                      : c.isHidden.equals(false)),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.chapterIndex)]))
          .get();

  Future<List<Chapter>> getAllChapters() =>
      (select(chapters)..orderBy([
            (c) => OrderingTerm.asc(c.bookId),
            (c) => OrderingTerm.asc(c.chapterIndex),
          ]))
          .get();

  Future<Chapter?> getChapter(String id) =>
      (select(chapters)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<ChapterPlaybackProgress?> getChapterPlaybackProgress(
    String chapterId,
  ) => (select(
    chapterPlaybackProgresses,
  )..where((p) => p.chapterId.equals(chapterId))).getSingleOrNull();

  Future<List<ChapterPlaybackProgress>> getChapterPlaybackProgresses(
    String bookId,
  ) => (select(
    chapterPlaybackProgresses,
  )..where((p) => p.bookId.equals(bookId))).get();

  Future<Map<String, Set<int>>> getFinishedChapterIndexesByBook() async {
    final query = select(chapterPlaybackProgresses).join([
      innerJoin(
        chapters,
        chapters.id.equalsExp(chapterPlaybackProgresses.chapterId),
      ),
    ])..where(chapterPlaybackProgresses.isFinished.equals(true));
    final result = <String, Set<int>>{};
    for (final row in await query.get()) {
      final chapter = row.readTable(chapters);
      result
          .putIfAbsent(chapter.bookId, () => <int>{})
          .add(chapter.chapterIndex);
    }
    return result;
  }

  Future<void> markChapterFinished(String bookId, String chapterId) async {
    final existing = await getChapterPlaybackProgress(chapterId);
    await into(chapterPlaybackProgresses).insertOnConflictUpdate(
      ChapterPlaybackProgress(
        chapterId: chapterId,
        bookId: bookId,
        positionMs: existing?.positionMs ?? 0,
        paragraphIndex: existing?.paragraphIndex ?? 0,
        paragraphOffsetMs: existing?.paragraphOffsetMs ?? 0,
        isFinished: true,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> insertChapters(List<Chapter> entries) async {
    await batch((b) => b.insertAll(chapters, entries));
  }

  Future<void> updateChapterNarrator(String chapterId, String? voiceId) async {
    await (update(chapters)..where((c) => c.id.equals(chapterId))).write(
      ChaptersCompanion(voiceId: Value(voiceId)),
    );
  }

  Future<void> updateChapterHidden(String chapterId, bool isHidden) async {
    await (update(chapters)..where((c) => c.id.equals(chapterId))).write(
      ChaptersCompanion(isHidden: Value(isHidden)),
    );
  }

  Future<void> replaceBookData({
    required Book book,
    required List<Chapter> chapterEntries,
    required List<Paragraph> paragraphEntries,
  }) async {
    await transaction(() async {
      await _deleteAiThreadsForParent('chapter', book.id);
      await (delete(bookmarks)..where((b) => b.bookId.equals(book.id))).go();
      await (delete(
        chapterPlaybackProgresses,
      )..where((p) => p.bookId.equals(book.id))).go();
      await (delete(paragraphs)..where((p) => p.bookId.equals(book.id))).go();
      await (delete(chapters)..where((c) => c.bookId.equals(book.id))).go();
      await into(books).insertOnConflictUpdate(book);
      await batch((b) {
        b.insertAll(chapters, chapterEntries);
        b.insertAll(paragraphs, paragraphEntries);
      });
    });
  }

  // ── 段落 ──

  Future<List<Paragraph>> getParagraphs(String chapterId) =>
      (select(paragraphs)
            ..where((p) => p.chapterId.equals(chapterId))
            ..orderBy([(p) => OrderingTerm.asc(p.paragraphIndex)]))
          .get();

  Future<List<Paragraph>> searchParagraphs(String query, {int limit = 80}) {
    return (select(paragraphs)
          ..where((p) => p.content.like('%$query%'))
          ..orderBy([(p) => OrderingTerm.asc(p.paragraphIndex)])
          ..limit(limit))
        .get();
  }

  Future<void> insertParagraphs(List<Paragraph> entries) async {
    await batch((b) => b.insertAll(paragraphs, entries));
  }

  // ── 书签 ──

  Future<List<Bookmark>> getBookmarks(String bookId) =>
      (select(bookmarks)
            ..where((b) => b.bookId.equals(bookId))
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .get();

  Future<void> addBookmark(Bookmark entry) => into(bookmarks).insert(entry);

  Future<void> deleteBookmark(String id) =>
      (delete(bookmarks)..where((b) => b.id.equals(id))).go();

  // ── 音色 ──

  Future<List<Voice>> getAllVoices() => select(voices).get();

  Future<List<Voice>> getVoicesByProvider(String providerId) =>
      (select(voices)..where((v) => v.providerId.equals(providerId))).get();

  Future<void> upsertVoice(Voice entry) =>
      into(voices).insertOnConflictUpdate(entry);

  Future<void> deleteVoice(String id) =>
      (delete(voices)..where((v) => v.id.equals(id))).go();

  Future<void> deleteVoicesByProvider(String providerId) =>
      (delete(voices)..where((v) => v.providerId.equals(providerId))).go();

  Future<void> clearVoiceSettings() async {
    await transaction(() async {
      await update(books).write(const BooksCompanion(voiceId: Value(null)));
      await update(
        chapters,
      ).write(const ChaptersCompanion(voiceId: Value(null)));
      await delete(voices).go();
    });
  }

  // ── 设置 ──

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(
      appSettings,
    ).insertOnConflictUpdate(AppSetting(key: key, value: value));
  }

  Future<void> clearSettings() => delete(appSettings).go();

  // ── 成本 ──

  Future<void> recordCost(Insertable<CostRecord> entry) =>
      into(costRecords).insert(entry);

  Future<int> totalCharactersSince(int sinceMs) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(characters), 0) AS total FROM cost_records WHERE created_at >= ?',
      variables: [Variable<int>(sinceMs)],
    ).getSingle();
    return row.data['total'] as int? ?? 0;
  }

  // ── 收听统计 ──

  Future<void> addListeningTime(
    String dateKey,
    int listenedMs, {
    bool newSession = false,
  }) async {
    if (listenedMs <= 0 && !newSession) return;
    await customStatement(
      '''
      INSERT INTO listening_days (date_key, listened_ms, sessions, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(date_key) DO UPDATE SET
        listened_ms = listening_days.listened_ms + excluded.listened_ms,
        sessions = listening_days.sessions + excluded.sessions,
        updated_at = excluded.updated_at
      ''',
      [
        dateKey,
        listenedMs,
        newSession ? 1 : 0,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Stream<List<ListeningDay>> watchListeningDays() => (select(
    listeningDays,
  )..orderBy([(row) => OrderingTerm.asc(row.dateKey)])).watch();

  // ── 词典 ──

  Future<DictionaryEntry?> getDictionaryEntry(
    String provider,
    String language,
    String normalizedTerm,
  ) {
    return (select(dictionaryEntries)..where(
          (row) =>
              row.provider.equals(provider) &
              row.language.equals(language) &
              row.normalizedTerm.equals(normalizedTerm),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertDictionaryEntry(DictionaryEntry entry) =>
      into(dictionaryEntries).insertOnConflictUpdate(entry);

  Future<void> touchDictionaryEntry(String id, int accessedAt) async {
    await customStatement(
      '''
      UPDATE dictionary_entries
      SET last_accessed_at = ?, access_count = access_count + 1
      WHERE id = ?
      ''',
      [accessedAt, id],
    );
  }

  Future<List<DictionaryEntry>> getRecentDictionaryEntries({int? limit}) {
    final query = select(dictionaryEntries)
      ..where(
        (row) =>
            row.status.equals('success') &
            row.provider.equals('vocabulary_com'),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.lastAccessedAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Cached words starting with [prefix], most recently used first.
  Future<List<DictionaryEntry>> searchDictionaryEntries(
    String prefix, {
    int limit = 5,
  }) {
    final normalized = prefix.trim().toLowerCase();
    if (normalized.isEmpty) return Future.value(const []);
    return (select(dictionaryEntries)
          ..where(
            (row) =>
                row.status.equals('success') &
                row.provider.equals('vocabulary_com') &
                row.normalizedTerm.like('${_escapeLike(normalized)}%'),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.lastAccessedAt)])
          ..limit(limit))
        .get();
  }

  static String _escapeLike(String value) =>
      value.replaceAll('%', '').replaceAll('_', '');

  // ── 收藏单词 ──

  Future<FavoriteWord?> getFavoriteForEntry(String dictionaryEntryId) =>
      (select(favoriteWords)
            ..where((row) => row.dictionaryEntryId.equals(dictionaryEntryId)))
          .getSingleOrNull();

  Future<void> upsertFavoriteWord(FavoriteWord favorite) =>
      into(favoriteWords).insertOnConflictUpdate(favorite);

  Future<void> deleteFavoriteForEntry(String dictionaryEntryId) => (delete(
    favoriteWords,
  )..where((row) => row.dictionaryEntryId.equals(dictionaryEntryId))).go();

  Future<List<({FavoriteWord favorite, DictionaryEntry entry})>>
  getFavoriteWordEntries() async {
    final query = select(favoriteWords).join([
      innerJoin(
        dictionaryEntries,
        dictionaryEntries.id.equalsExp(favoriteWords.dictionaryEntryId),
      ),
    ])..orderBy([OrderingTerm.desc(favoriteWords.favoritedAt)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          favorite: row.readTable(favoriteWords),
          entry: row.readTable(dictionaryEntries),
        ),
    ];
  }

  // ── Podcast ──

  Stream<List<PodcastShow>> watchPodcastShows() =>
      (select(podcastShows)
            ..where((show) => show.subscribedAt.isBiggerThanValue(0))
            ..orderBy([(show) => OrderingTerm.desc(show.lastRefreshedAt)]))
          .watch();

  Future<List<PodcastShow>> getPodcastShows() =>
      (select(podcastShows)
            ..where((show) => show.subscribedAt.isBiggerThanValue(0))
            ..orderBy([(show) => OrderingTerm.desc(show.lastRefreshedAt)]))
          .get();

  Future<List<PodcastShow>> getAllPodcastShows() => (select(
    podcastShows,
  )..orderBy([(show) => OrderingTerm.desc(show.lastRefreshedAt)])).get();

  Future<PodcastShow?> getPodcastShow(String id) => (select(
    podcastShows,
  )..where((show) => show.id.equals(id))).getSingleOrNull();

  Future<PodcastShow?> getPodcastShowByFeedUrl(String feedUrl) => (select(
    podcastShows,
  )..where((show) => show.feedUrl.equals(feedUrl))).getSingleOrNull();

  Future<void> upsertPodcastShow(PodcastShow show) =>
      into(podcastShows).insertOnConflictUpdate(show);

  Stream<List<PodcastEpisode>> watchPodcastEpisodes(String showId) =>
      (select(podcastEpisodes)
            ..where((episode) => episode.showId.equals(showId))
            ..orderBy([(episode) => OrderingTerm.desc(episode.publishedAt)]))
          .watch();

  Future<List<PodcastEpisode>> getPodcastEpisodes(String showId) =>
      (select(podcastEpisodes)
            ..where((episode) => episode.showId.equals(showId))
            ..orderBy([(episode) => OrderingTerm.desc(episode.publishedAt)]))
          .get();

  Future<List<PodcastEpisode>> getAllPodcastEpisodes() =>
      select(podcastEpisodes).get();

  Future<List<PodcastEpisode>> getRecentPodcastEpisodes({
    int? limit,
    bool subscribedOnly = true,
  }) async {
    if (!subscribedOnly) {
      final query = select(podcastEpisodes)
        ..orderBy([(episode) => OrderingTerm.desc(episode.publishedAt)]);
      if (limit != null) query.limit(limit);
      return query.get();
    }

    final query =
        select(podcastEpisodes).join([
            innerJoin(
              podcastShows,
              podcastShows.id.equalsExp(podcastEpisodes.showId),
              useColumns: false,
            ),
          ])
          ..where(podcastShows.subscribedAt.isBiggerThanValue(0))
          ..orderBy([OrderingTerm.desc(podcastEpisodes.publishedAt)]);
    if (limit != null) query.limit(limit);
    return [
      for (final row in await query.get()) row.readTable(podcastEpisodes),
    ];
  }

  Future<PodcastEpisode?> getPodcastEpisode(String id) => (select(
    podcastEpisodes,
  )..where((episode) => episode.id.equals(id))).getSingleOrNull();

  Stream<PodcastEpisode?> watchPodcastEpisode(String id) => (select(
    podcastEpisodes,
  )..where((episode) => episode.id.equals(id))).watchSingleOrNull();

  Future<PodcastEpisode?> getPodcastEpisodeByGuid(String showId, String guid) =>
      (select(podcastEpisodes)..where(
            (episode) =>
                episode.showId.equals(showId) & episode.guid.equals(guid),
          ))
          .getSingleOrNull();

  Future<void> upsertPodcastEpisode(PodcastEpisode episode) =>
      into(podcastEpisodes).insertOnConflictUpdate(episode);

  Future<void> deletePodcastShowCascade(String showId) async {
    await transaction(() async {
      await _deleteAiThreadsForParent('episode', showId);
      await (delete(
        podcastEpisodes,
      )..where((episode) => episode.showId.equals(showId))).go();
      await (delete(
        podcastShows,
      )..where((show) => show.id.equals(showId))).go();
    });
  }

  Future<void> updatePodcastProgress(
    String episodeId, {
    required int positionMs,
    required bool isPlayed,
  }) async {
    await (update(
      podcastEpisodes,
    )..where((episode) => episode.id.equals(episodeId))).write(
      PodcastEpisodesCompanion(
        playbackPositionMs: Value(positionMs),
        lastPlayedAt: Value(DateTime.now().millisecondsSinceEpoch),
        // Completion is sticky: replaying an already-finished episode from
        // the beginning should not silently turn it back into an unplayed one.
        isPlayed: isPlayed ? const Value(true) : const Value.absent(),
      ),
    );
  }

  Future<void> updatePodcastLocalAudioPath(
    String episodeId,
    String? localAudioPath,
  ) async {
    await (update(podcastEpisodes)
          ..where((episode) => episode.id.equals(episodeId)))
        .write(PodcastEpisodesCompanion(localAudioPath: Value(localAudioPath)));
  }

  Future<void> clearPodcastTranscript(String episodeId) async {
    await (update(
      podcastEpisodes,
    )..where((episode) => episode.id.equals(episodeId))).write(
      const PodcastEpisodesCompanion(
        transcriptJson: Value(null),
        transcriptLanguage: Value(null),
        transcriptStatus: Value('none'),
        transcriptError: Value(null),
        transcriptProgressMs: Value(0),
      ),
    );
  }

  Future<void> updatePodcastTranscript(
    String episodeId, {
    required String status,
    String? transcriptJson,
    String? language,
    String? error,
    int? progressMs,
  }) async {
    await (update(
      podcastEpisodes,
    )..where((episode) => episode.id.equals(episodeId))).write(
      PodcastEpisodesCompanion(
        transcriptStatus: Value(status),
        // Status/progress updates must not erase transcript chunks that were
        // already persisted. A non-null value explicitly replaces the field.
        transcriptJson: transcriptJson == null
            ? const Value.absent()
            : Value(transcriptJson),
        transcriptLanguage: language == null
            ? const Value.absent()
            : Value(language),
        transcriptError: Value(error),
        transcriptProgressMs: progressMs == null
            ? const Value.absent()
            : Value(progressMs),
      ),
    );
  }

  // ── AI threads ──

  Future<AiThread?> getAiThread(String scopeType, String scopeId) =>
      (select(aiThreads)..where(
            (thread) =>
                thread.scopeType.equals(scopeType) &
                thread.scopeId.equals(scopeId),
          ))
          .getSingleOrNull();

  Stream<AiThread?> watchAiThread(String scopeType, String scopeId) =>
      (select(aiThreads)..where(
            (thread) =>
                thread.scopeType.equals(scopeType) &
                thread.scopeId.equals(scopeId),
          ))
          .watchSingleOrNull();

  Future<void> upsertAiThread(AiThread thread) =>
      into(aiThreads).insertOnConflictUpdate(thread);

  Future<List<AiMessage>> getAiMessages(String threadId) =>
      (select(aiMessages)
            ..where((message) => message.threadId.equals(threadId))
            ..orderBy([(message) => OrderingTerm.asc(message.createdAt)]))
          .get();

  Stream<List<AiMessage>> watchAiMessages(String threadId) =>
      (select(aiMessages)
            ..where((message) => message.threadId.equals(threadId))
            ..orderBy([(message) => OrderingTerm.asc(message.createdAt)]))
          .watch();

  Future<void> insertAiMessage(AiMessage message) =>
      into(aiMessages).insert(message);

  Future<void> deleteAiMessages(String threadId, {String? kind}) async {
    final query = delete(aiMessages)
      ..where((message) => message.threadId.equals(threadId));
    if (kind != null) {
      query.where((message) => message.kind.equals(kind));
    }
    await query.go();
  }

  Future<void> deleteAiThread(String threadId) async {
    await transaction(() async {
      await deleteAiMessages(threadId);
      await (delete(
        aiThreads,
      )..where((thread) => thread.id.equals(threadId))).go();
    });
  }

  Future<void> _deleteAiThreadsForParent(
    String scopeType,
    String parentId,
  ) async {
    final threads =
        await (select(aiThreads)..where(
              (thread) =>
                  thread.scopeType.equals(scopeType) &
                  thread.scopeParentId.equals(parentId),
            ))
            .get();
    for (final thread in threads) {
      await deleteAiMessages(thread.id);
    }
    await (delete(aiThreads)..where(
          (thread) =>
              thread.scopeType.equals(scopeType) &
              thread.scopeParentId.equals(parentId),
        ))
        .go();
  }
}

Future<String> _existingRebasedPath(
  String storedPath,
  String currentDocumentsPath,
) async {
  if (await File(storedPath).exists()) return storedPath;

  final candidate = rebaseApplicationDocumentsPath(
    storedPath,
    currentDocumentsPath,
  );
  if (candidate != storedPath && await File(candidate).exists()) {
    return candidate;
  }
  return storedPath;
}

/// Replaces the obsolete portion before `/Documents/` while retaining the
/// app-owned relative path. Paths outside Documents are left unchanged.
String rebaseApplicationDocumentsPath(
  String storedPath,
  String currentDocumentsPath,
) {
  final normalized = storedPath.replaceAll('\\', '/');
  const marker = '/Documents/';
  final markerIndex = normalized.lastIndexOf(marker);
  if (markerIndex < 0) return storedPath;

  final relativePath = normalized.substring(markerIndex + marker.length);
  if (relativePath.isEmpty) return storedPath;

  final candidate = p.normalize(
    p.joinAll([currentDocumentsPath, ...p.posix.split(relativePath)]),
  );
  final documents = p.normalize(currentDocumentsPath);
  if (!p.isWithin(documents, candidate)) return storedPath;
  return candidate;
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'lumina.db'));
    return NativeDatabase.createInBackground(file);
  });
}
