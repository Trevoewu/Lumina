import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('rebases a path from a previous iOS Documents container', () {
    expect(
      rebaseApplicationDocumentsPath(
        '/var/mobile/Containers/Data/Application/OLD/Documents/books/book-1/cover.jpg',
        '/var/mobile/Containers/Data/Application/NEW/Documents',
      ),
      '/var/mobile/Containers/Data/Application/NEW/Documents/books/book-1/cover.jpg',
    );
  });

  test('does not rebase paths outside the app Documents directory', () {
    const externalPath = '/private/var/mobile/Media/book.epub';
    expect(
      rebaseApplicationDocumentsPath(externalPath, '/new/Documents'),
      externalPath,
    );
  });

  test('repairs persisted source and cover paths when files moved', () async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_paths_');
    final oldDocuments = Directory('${tempDir.path}/old/Documents');
    final newDocuments = Directory('${tempDir.path}/new/Documents');
    final newBookDirectory = Directory('${newDocuments.path}/books/book-1')
      ..createSync(recursive: true);
    final source = File('${newBookDirectory.path}/source.epub')
      ..writeAsStringSync('book');
    final cover = File('${newBookDirectory.path}/cover.jpg')
      ..writeAsStringSync('cover');
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    await database
        .into(database.books)
        .insert(
          BooksCompanion.insert(
            id: 'book-1',
            title: 'Path Test',
            format: 'epub',
            sourcePath: '${oldDocuments.path}/books/book-1/source.epub',
            coverPath: Value('${oldDocuments.path}/books/book-1/cover.jpg'),
            importedAt: 1,
          ),
        );

    await database.repairMovedDocumentPaths(newDocuments.path);

    final repaired = await database.getBook('book-1');
    expect(repaired?.sourcePath, source.path);
    expect(repaired?.coverPath, cover.path);
  });

  test('schema 1 books migrate to schema 19 without data loss', () async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_migration_');
    final databaseFile = File('${tempDir.path}/lumina.db');

    final oldDatabase = sqlite3.open(databaseFile.path);
    oldDatabase.execute('''
      CREATE TABLE books (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NULL,
        format TEXT NOT NULL,
        source_path TEXT NOT NULL,
        cover_path TEXT NULL,
        chapter_count INTEGER NOT NULL DEFAULT 0,
        paragraph_count INTEGER NOT NULL DEFAULT 0,
        current_chapter_id TEXT NULL,
        current_paragraph_index INTEGER NOT NULL DEFAULT 0,
        playback_offset_ms INTEGER NOT NULL DEFAULT 0,
        voice_id TEXT NULL,
        imported_at INTEGER NOT NULL,
        last_read_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
    oldDatabase.execute('''
      INSERT INTO books (
        id, title, format, source_path, imported_at
      ) VALUES (
        'book-1', 'Migration Test', 'epub', '/tmp/test.epub', 1
      );
    ''');
    oldDatabase.execute('PRAGMA user_version = 1;');
    oldDatabase.close();

    final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final books = await database.getAllBooks();
    final version = await database
        .customSelect('PRAGMA user_version;')
        .getSingle();

    expect(version.read<int>('user_version'), 19);
    expect(await database.select(database.generationTasks).get(), isEmpty);
    expect(await database.select(database.generationTaskChunks).get(), isEmpty);
    expect(await database.getPodcastShows(), isEmpty);
    expect(await database.select(database.aiThreads).get(), isEmpty);
    expect(await database.select(database.aiMessages).get(), isEmpty);
    expect(books, hasLength(1));
    expect(books.single.title, 'Migration Test');
    expect(books.single.kind, 'book');
    expect(books.single.rightsStatus, 'user_uploaded');
    expect(books.single.language, equals(null));
    expect(books.single.readingLevelCode, equals(null));
    expect(books.single.isRead, isFalse);

    await database.updateBookReadStatus('book-1', true);
    expect((await database.getBook('book-1'))?.isRead, isTrue);
    await database.updateBookReadStatus('book-1', false);
    expect((await database.getBook('book-1'))?.isRead, isFalse);

    await database.updateReadingProgress(
      'book-1',
      chapterId: 'chapter-3',
      paragraphIndex: 17,
      offsetMs: 2450,
      chapterPositionMs: 62450,
    );
    final updated = await database.getBook('book-1');
    expect(updated?.currentChapterId, 'chapter-3');
    expect(updated?.currentParagraphIndex, 17);
    expect(updated?.playbackOffsetMs, 2450);
    final chapterThreeProgress = await database.getChapterPlaybackProgress(
      'chapter-3',
    );
    expect(chapterThreeProgress?.positionMs, 62450);
    expect(chapterThreeProgress?.paragraphIndex, 17);
    expect(chapterThreeProgress?.paragraphOffsetMs, 2450);
    expect(chapterThreeProgress?.isFinished, isFalse);

    await database.insertChapters([
      const Chapter(
        id: 'chapter-1',
        bookId: 'book-1',
        chapterIndex: 0,
        title: 'Chapter 1',
        textOffset: 0,
        isHidden: false,
      ),
    ]);
    await database.updateChapterNarrator('chapter-1', 'narrator-1');
    await database.updateChapterHidden('chapter-1', true);
    await database.updateReadingProgress(
      'book-1',
      chapterId: 'chapter-1',
      paragraphIndex: 2,
      offsetMs: 800,
      chapterPositionMs: 12800,
    );
    final allChapterProgress = await database.getChapterPlaybackProgresses(
      'book-1',
    );
    expect(
      allChapterProgress.map((progress) => progress.chapterId),
      containsAll(<String>['chapter-3', 'chapter-1']),
    );
    expect(await database.getChapters('book-1'), isEmpty);
    final hiddenChapters = await database.getChapters(
      'book-1',
      includeHidden: true,
    );
    expect(hiddenChapters.single.voiceId, 'narrator-1');
    expect(hiddenChapters.single.isHidden, isTrue);

    await database.addListeningTime('2026-06-30', 120000, newSession: true);
    final listeningDays = await database.watchListeningDays().first;
    expect(listeningDays, hasLength(1));
    expect(listeningDays.single.listenedMs, 120000);
    expect(listeningDays.single.sessions, 1);
  });

  test(
    'schema 11 data gains podcast categories and chapter completion',
    () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'lumina_podcast_migration_',
      );
      final databaseFile = File('${tempDir.path}/lumina.db');
      final oldDatabase = sqlite3.open(databaseFile.path);
      oldDatabase.execute('''
      CREATE TABLE podcast_shows (
        id TEXT NOT NULL PRIMARY KEY,
        feed_url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        author TEXT NULL,
        description TEXT NOT NULL DEFAULT '',
        image_url TEXT NULL,
        language TEXT NULL,
        website_url TEXT NULL,
        subscribed_at INTEGER NOT NULL,
        last_refreshed_at INTEGER NOT NULL
      );
    ''');
      oldDatabase.execute('''
      INSERT INTO podcast_shows (
        id, feed_url, title, description, subscribed_at, last_refreshed_at
      ) VALUES (
        'show-1', 'https://example.com/feed.xml', 'Legacy Show', '', 1, 1
      );
    ''');
      oldDatabase.execute('''
      CREATE TABLE podcast_episodes (
        id TEXT NOT NULL PRIMARY KEY,
        show_id TEXT NOT NULL,
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        audio_url TEXT NOT NULL,
        image_url TEXT NULL,
        published_at INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        playback_position_ms INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER NOT NULL DEFAULT 0,
        is_played INTEGER NOT NULL DEFAULT 0,
        local_audio_path TEXT NULL,
        transcript_json TEXT NULL,
        transcript_language TEXT NULL,
        transcript_status TEXT NOT NULL DEFAULT 'none',
        transcript_error TEXT NULL,
        source_transcript_url TEXT NULL,
        UNIQUE (show_id, guid)
      );
    ''');
      oldDatabase.execute('''
      INSERT INTO podcast_episodes (
        id, show_id, guid, title, audio_url, transcript_status
      ) VALUES (
        'episode-1', 'show-1', 'guid-1', 'Legacy Episode',
        'https://example.com/1.mp3', 'running'
      );
    ''');
      oldDatabase.execute('''
      CREATE TABLE chapter_playback_progresses (
        chapter_id TEXT NOT NULL PRIMARY KEY,
        book_id TEXT NOT NULL,
        position_ms INTEGER NOT NULL DEFAULT 0,
        paragraph_index INTEGER NOT NULL DEFAULT 0,
        paragraph_offset_ms INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');
      oldDatabase.execute('''
      INSERT INTO chapter_playback_progresses (
        chapter_id, book_id, position_ms, updated_at
      ) VALUES ('chapter-1', 'book-1', 1200, 1);
    ''');
      oldDatabase.execute('PRAGMA user_version = 11;');
      oldDatabase.close();

      final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(() async {
        await database.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final show = await database.getPodcastShow('show-1');
      final version = await database
          .customSelect('PRAGMA user_version;')
          .getSingle();
      expect(version.read<int>('user_version'), 19);
      expect(show?.title, 'Legacy Show');
      expect(show?.categoriesJson, equals(null));
      final progress = await database.getChapterPlaybackProgress('chapter-1');
      expect(progress?.positionMs, 1200);
      expect(progress?.isFinished, isFalse);
      final episode = await database.getPodcastEpisode('episode-1');
      expect(episode?.title, 'Legacy Episode');
      await database.updatePodcastEpisodeHidden('episode-1', true);
      expect(await database.getPodcastEpisodes('show-1'), isEmpty);
      await database.updatePodcastEpisodeHidden('episode-1', false);
      expect(await database.getPodcastEpisodes('show-1'), hasLength(1));
      expect(
        episode?.transcriptProgressMs,
        0,
        reason: 'legacy rows start a resume from the beginning',
      );
    },
  );
}
