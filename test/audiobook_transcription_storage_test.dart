import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/book_sources/librivox_repository.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/services/audiobook_manifest_validator.dart';
import 'package:lumina/services/audiobook_transcription_storage.dart';
import 'package:lumina/services/manifest_store.dart';

void main() {
  test(
    'chapter subtitles survive reopen and preserve original audio and progress',
    () async {
      final root = await Directory.systemTemp.createTemp('book_asr_');
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final manifests = ManifestStore(documentsDirectory: () async => root);
      addTearDown(() async {
        await database.close();
        await root.delete(recursive: true);
      });
      final book = await LibrivoxRepository().importAudiobook(
        book: LibrivoxBook.fromJson({
          'id': '100',
          'title': 'Recorded book',
          'language': 'English',
          'sections': [
            {
              'id': '200',
              'title': 'First chapter',
              'listen_url': 'https://archive.org/download/example/one.mp3',
              'playtime': '60',
            },
            {
              'id': '201',
              'title': 'Second chapter',
              'listen_url': 'https://archive.org/download/example/two.mp3',
              'playtime': '60',
            },
          ],
        }),
        database: database,
        manifestStore: manifests,
        appDir: root.path,
      );
      final chapters = await database.getChapters(book.id);
      final chapter = chapters.first;
      final original = (await manifests.load(book.id, chapter.id))!;
      final storage = AudiobookTranscriptionStorage(
        database,
        manifests: manifests,
        book: book,
        chapter: chapter,
      );
      await database.updateReadingProgress(
        book.id,
        chapterId: chapter.id,
        chapterPositionMs: 12000,
        offsetMs: 12000,
      );
      await storage.saveAudioPath(chapter.id, '/tmp/chapter-download.mp3');
      await storage.update(
        chapter.id,
        status: 'running',
        transcriptJson: jsonEncode([
          {
            'text': 'Hello world.',
            'startMs': 500,
            'endMs': 2100,
            'chunkStartMs': 0,
          },
        ]),
        progressMs: 30000,
        language: 'en',
      );
      await storage.update(chapter.id, status: 'paused');

      final reopened = AudiobookTranscriptionStorage(
        database,
        manifests: manifests,
        book: book,
        chapter: chapter,
      );
      final state = (await reopened.read(chapter.id))!;
      expect(state.transcriptStatus, 'paused');
      expect(state.transcriptProgressMs, 30000);
      expect(state.localAudioPath, '/tmp/chapter-download.mp3');
      expect(state.transcriptJson, contains('Hello world.'));
      final paragraphs = await database.getParagraphs(chapter.id);
      expect(paragraphs.single.content, 'Hello world.');
      final updated = validateAudiobookManifest(
        (await manifests.load(book.id, chapter.id))!,
        paragraphs,
      );
      expect(updated.isReady, isTrue);
      expect(
        updated.segments.single.audioFile,
        original.segments.single.audioFile,
      );
      expect(
        updated.segments.single.paragraphId,
        original.segments.single.paragraphId,
      );
      expect(updated.segments.single.timings.single.startMs, 500);
      expect(
        (await database.getChapterPlaybackProgress(chapter.id))!.positionMs,
        12000,
      );
      expect((await database.select(database.podcastEpisodes).get()), isEmpty);
      expect(
        (await manifests.load(
          book.id,
          chapters.last.id,
        ))!.segments.single.timings,
        isEmpty,
      );

      await reopened.clear(chapter.id);
      expect((await reopened.read(chapter.id))!.transcriptProgressMs, 0);
      expect(
        (await manifests.load(book.id, chapter.id))!.segments.single.audioFile,
        original.segments.single.audioFile,
      );
      expect((await manifests.load(book.id, chapter.id))!.isReady, isTrue);
    },
  );
}
