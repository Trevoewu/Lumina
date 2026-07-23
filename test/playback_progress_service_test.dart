import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/playback_progress_service.dart';

void main() {
  test(
    'audiobook progress stores both paragraph and chapter positions',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final handler = _ProgressAudioHandler();
      final service = PlaybackProgressService(
        database: database,
        audioHandler: handler,
      );
      addTearDown(() async {
        await handler.dispose();
        await database.close();
      });

      await database.upsertBook(
        const Book(
          id: 'book',
          title: 'Book',
          format: 'epub',
          sourcePath: '/book.epub',
          chapterCount: 1,
          paragraphCount: 2,
          currentParagraphIndex: 0,
          playbackOffsetMs: 0,
          importedAt: 1,
          lastReadAt: 0,
          kind: 'book',
          rightsStatus: 'user_uploaded',
        ),
      );

      service.start();
      handler.emitPosition();
      await service.dispose();

      final book = await database.getBook('book');
      final chapterProgress = await database.getChapterPlaybackProgress(
        'chapter',
      );
      expect(book?.currentChapterId, 'chapter');
      expect(book?.currentParagraphIndex, 1);
      expect(book?.playbackOffsetMs, 2500);
      expect(chapterProgress?.positionMs, 12500);
      expect(chapterProgress?.paragraphIndex, 1);
      expect(chapterProgress?.paragraphOffsetMs, 2500);
    },
  );
}

class _ProgressAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
  final _positionController = StreamController<Duration>.broadcast();
  final _paragraphController = StreamController<String?>.broadcast();

  void emitPosition() {
    _positionController.add(position);
  }

  @override
  String? get currentBookId => 'book';

  @override
  String? get currentChapterId => 'chapter';

  @override
  String? get currentPodcastEpisodeId => null;

  @override
  int? get currentParagraphIndex => 1;

  @override
  String? get currentParagraphId => 'paragraph-2';

  @override
  Stream<String?> get currentParagraphIdStream => _paragraphController.stream;

  @override
  Duration get position => const Duration(milliseconds: 2500);

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Duration get chapterPosition => const Duration(milliseconds: 12500);

  @override
  Duration get chapterDuration => const Duration(milliseconds: 20000);

  @override
  Stream<Duration> get chapterPositionStream => _positionController.stream;

  @override
  ChapterManifest? get currentManifest => null;

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _paragraphController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
