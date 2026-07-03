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
  TextColumn get kind => text().withDefault(const Constant('book'))();

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

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
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

// ─────────────────────────────────────────────
// 数据库
// ─────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Books,
    Chapters,
    Paragraphs,
    Bookmarks,
    Voices,
    AppSettings,
    CostRecords,
    ListeningDays,
  ],
)
class AppDatabase extends _$AppDatabase {
  final bool _repairPathsOnOpen;

  AppDatabase() : _repairPathsOnOpen = true, super(_open());

  AppDatabase.forTesting(super.e) : _repairPathsOnOpen = false;

  @override
  int get schemaVersion => 3;

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

  Future<void> upsertBook(Book entry) =>
      into(books).insertOnConflictUpdate(entry);

  Future<void> updateBookCoverPath(String bookId, String coverPath) async {
    await (update(books)..where((b) => b.id.equals(bookId))).write(
      BooksCompanion(coverPath: Value(coverPath)),
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
    bool clearAuthor = false,
    bool clearCover = false,
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
      ),
    );
  }

  Future<void> deleteBook(String id) =>
      (delete(books)..where((b) => b.id.equals(id))).go();

  Future<void> deleteBookCascade(String id) async {
    await transaction(() async {
      await (delete(bookmarks)..where((b) => b.bookId.equals(id))).go();
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
  }) async {
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
        lastReadAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  // ── 章节 ──

  Future<List<Chapter>> getChapters(String bookId) =>
      (select(chapters)
            ..where((c) => c.bookId.equals(bookId))
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

  Future<void> insertChapters(List<Chapter> entries) async {
    await batch((b) => b.insertAll(chapters, entries));
  }

  Future<void> replaceBookData({
    required Book book,
    required List<Chapter> chapterEntries,
    required List<Paragraph> paragraphEntries,
  }) async {
    await transaction(() async {
      await (delete(bookmarks)..where((b) => b.bookId.equals(book.id))).go();
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
    return NativeDatabase(file);
  });
}
