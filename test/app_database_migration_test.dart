import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema 1 books migrate to schema 2 without data loss', () async {
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

    expect(version.read<int>('user_version'), 2);
    expect(books, hasLength(1));
    expect(books.single.title, 'Migration Test');
    expect(books.single.kind, 'book');
  });
}
