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

  test('schema 1 books migrate to schema 4 without data loss', () async {
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

    expect(version.read<int>('user_version'), 4);
    expect(books, hasLength(1));
    expect(books.single.title, 'Migration Test');
    expect(books.single.kind, 'book');

    await database.updateReadingProgress(
      'book-1',
      chapterId: 'chapter-3',
      paragraphIndex: 17,
      offsetMs: 2450,
    );
    final updated = await database.getBook('book-1');
    expect(updated?.currentChapterId, 'chapter-3');
    expect(updated?.currentParagraphIndex, 17);
    expect(updated?.playbackOffsetMs, 2450);

    await database.addListeningTime('2026-06-30', 120000, newSession: true);
    final listeningDays = await database.watchListeningDays().first;
    expect(listeningDays, hasLength(1));
    expect(listeningDays.single.listenedMs, 120000);
    expect(listeningDays.single.sessions, 1);
  });
}
