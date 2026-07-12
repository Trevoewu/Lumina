import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/services/generation_orchestrator.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/tts/models/tts_capabilities.dart';
import 'package:lumina/tts/models/tts_chunk.dart';
import 'package:lumina/tts/models/tts_voice.dart';
import 'package:lumina/tts/tts_provider.dart';

void main() {
  test('generation keeps the provider concurrency limit full', () async {
    final temp = await Directory.systemTemp.createTemp('lumina_parallel_');
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final store = _TestManifestStore(temp);
    final provider = _ConcurrentTestProvider(concurrency: 3);
    const voice = TtsVoice(
      id: 'voice',
      name: 'Test voice',
      providerId: 'parallel_test',
      type: VoiceType.preset,
      providerVoiceId: 'voice',
      createdAt: 1,
    );
    addTearDown(() async {
      await database.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    await _insertBookFixture(database);
    final orchestrator = GenerationOrchestrator(
      database: database,
      manifestStore: store,
    );

    final progress = await orchestrator
        .generateChapter(
          bookId: 'book',
          chapterId: 'chapter',
          provider: provider,
          voice: voice,
        )
        .toList();

    expect(provider.maxActiveRequests, 3);
    expect(progress.any((entry) => entry.generating == 3), isTrue);
    expect(progress.last.ready, 5);
    expect(progress.last.failed, 0);
    expect(store.saved?.isReady, isTrue);
    for (final segment in store.saved!.segments) {
      expect(await File(await store.absolutePath(segment)).exists(), isTrue);
    }
  });

  test(
    'duplicate chapter requests share the chapter generation lock',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'lumina_parallel_lock_',
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final store = _TestManifestStore(temp);
      final provider = _ConcurrentTestProvider(concurrency: 3);
      const voice = TtsVoice(
        id: 'voice',
        name: 'Test voice',
        providerId: 'parallel_test',
        type: VoiceType.preset,
        providerVoiceId: 'voice',
        createdAt: 1,
      );
      addTearDown(() async {
        await database.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      await _insertBookFixture(database);
      final orchestrator = GenerationOrchestrator(
        database: database,
        manifestStore: store,
      );

      final results = await Future.wait([
        orchestrator
            .generateChapter(
              bookId: 'book',
              chapterId: 'chapter',
              provider: provider,
              voice: voice,
            )
            .toList(),
        orchestrator
            .generateChapter(
              bookId: 'book',
              chapterId: 'chapter',
              provider: provider,
              voice: voice,
            )
            .toList(),
      ]);

      expect(provider.maxActiveRequests, 3);
      expect(provider.synthesisRequests, 5);
      expect(results.first.last.ready, 5);
      expect(results.last.last.ready, 5);
    },
  );

  test(
    'generation continues after the progress listener is cancelled',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'lumina_detached_job_',
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final store = _TestManifestStore(temp);
      final provider = _ConcurrentTestProvider(concurrency: 3);
      const voice = TtsVoice(
        id: 'voice',
        name: 'Test voice',
        providerId: 'parallel_test',
        type: VoiceType.preset,
        providerVoiceId: 'voice',
        createdAt: 1,
      );
      addTearDown(() async {
        await database.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      await _insertBookFixture(database);
      final orchestrator = GenerationOrchestrator(
        database: database,
        manifestStore: store,
      );
      final started = Completer<void>();
      final subscription = orchestrator
          .generateChapter(
            bookId: 'book',
            chapterId: 'chapter',
            provider: provider,
            voice: voice,
          )
          .listen((progress) {
            if (progress.generating > 0 && !started.isCompleted) {
              started.complete();
            }
          });

      await started.future;
      await subscription.cancel();
      for (
        var attempt = 0;
        attempt < 20 && store.saved?.isReady != true;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(store.saved?.isReady, isTrue);
      expect(provider.synthesisRequests, 5);
    },
  );

  test('generation pauses new work and resumes from saved segments', () async {
    final temp = await Directory.systemTemp.createTemp('lumina_pause_');
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final store = _TestManifestStore(temp);
    final provider = _ConcurrentTestProvider(concurrency: 1);
    const voice = TtsVoice(
      id: 'voice',
      name: 'Test voice',
      providerId: 'parallel_test',
      type: VoiceType.preset,
      providerVoiceId: 'voice',
      createdAt: 1,
    );
    addTearDown(() async {
      await database.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    await _insertBookFixture(database);
    final orchestrator = GenerationOrchestrator(
      database: database,
      manifestStore: store,
    );
    final paused = Completer<void>();
    final completed = Completer<void>();
    var pauseIssued = false;
    final subscription = orchestrator
        .generateChapter(
          bookId: 'book',
          chapterId: 'chapter',
          provider: provider,
          voice: voice,
        )
        .listen(
          (progress) {
            if (!pauseIssued && progress.generating > 0) {
              pauseIssued = true;
              expect(
                orchestrator.pauseChapter(bookId: 'book', chapterId: 'chapter'),
                isTrue,
              );
            }
            if (pauseIssued && progress.ready == 1 && !paused.isCompleted) {
              paused.complete();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completed.isCompleted) {
              completed.completeError(error, stackTrace);
            }
          },
          onDone: () {
            if (!completed.isCompleted) completed.complete();
          },
        );

    await paused.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(provider.synthesisRequests, 1);
    expect(
      orchestrator.resumeChapter(bookId: 'book', chapterId: 'chapter'),
      isTrue,
    );
    await completed.future.timeout(const Duration(seconds: 2));
    await subscription.cancel();

    expect(provider.synthesisRequests, 5);
    expect(store.saved?.isReady, isTrue);
  });

  test(
    'exclusive book task cancels generation before cache deletion',
    () async {
      final temp = await Directory.systemTemp.createTemp('lumina_cancel_race_');
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final store = _TestManifestStore(temp);
      final provider = _ConcurrentTestProvider(concurrency: 3);
      const voice = TtsVoice(
        id: 'voice',
        name: 'Test voice',
        providerId: 'parallel_test',
        type: VoiceType.preset,
        providerVoiceId: 'voice',
        createdAt: 1,
      );
      addTearDown(() async {
        await database.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      await _insertBookFixture(database);
      final orchestrator = GenerationOrchestrator(
        database: database,
        manifestStore: store,
      );
      final started = Completer<void>();
      orchestrator
          .generateChapter(
            bookId: 'book',
            chapterId: 'chapter',
            provider: provider,
            voice: voice,
          )
          .listen((progress) {
            if (progress.generating > 0 && !started.isCompleted) {
              started.complete();
            }
          });
      await started.future;

      await orchestrator.runBookExclusive('book', () async {
        await store.deleteBook('book');
        await expectLater(
          orchestrator
              .generateChapter(
                bookId: 'book',
                chapterId: 'chapter',
                provider: provider,
                voice: voice,
              )
              .drain<void>(),
          throwsStateError,
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(store.saved, isNull);
      final bookAudio = Directory('${temp.path}/book');
      expect(
        await bookAudio.exists()
            ? await bookAudio
                  .list(recursive: true)
                  .where((e) => e is File)
                  .isEmpty
            : true,
        isTrue,
      );
    },
  );

  test('sanitizes request-external timestamp offsets', () {
    final timings = sanitizeAudioTextTimings(const [
      AudioTextTiming(text: 'Hello', startMs: 12000, endMs: 12400),
      AudioTextTiming(text: 'world', startMs: 12450, endMs: 12900),
    ], durationMs: 1000);

    expect(timings.map((timing) => timing.startMs), [0, 450]);
    expect(timings.map((timing) => timing.endMs), [400, 900]);
  });

  test('generation rejects books without generation rights', () async {
    final temp = await Directory.systemTemp.createTemp('lumina_rights_');
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final store = _TestManifestStore(temp);
    final provider = _ConcurrentTestProvider(concurrency: 1);
    const voice = TtsVoice(
      id: 'voice',
      name: 'Test voice',
      providerId: 'parallel_test',
      type: VoiceType.preset,
      providerVoiceId: 'voice',
      createdAt: 1,
    );
    addTearDown(() async {
      await database.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    await _insertBookFixture(database, rightsStatus: 'metadata_only');
    final orchestrator = GenerationOrchestrator(
      database: database,
      manifestStore: store,
    );

    await expectLater(
      orchestrator
          .generateChapter(
            bookId: 'book',
            chapterId: 'chapter',
            provider: provider,
            voice: voice,
          )
          .drain<void>(),
      throwsA(isA<StateError>()),
    );
    expect(provider.synthesisRequests, 0);
  });
}

Future<void> _insertBookFixture(
  AppDatabase database, {
  String rightsStatus = 'user_uploaded',
}) async {
  await database.upsertBook(
    Book(
      id: 'book',
      title: 'Generation Test',
      format: 'txt',
      sourcePath: '/tmp/generation-test.txt',
      chapterCount: 1,
      paragraphCount: 5,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      kind: 'book',
      rightsStatus: rightsStatus,
    ),
  );
  await database.insertParagraphs([
    for (var index = 0; index < 5; index++)
      Paragraph(
        id: 'p$index',
        chapterId: 'chapter',
        bookId: 'book',
        paragraphIndex: index,
        content: 'Paragraph $index.',
      ),
  ]);
}

class _ConcurrentTestProvider implements TtsProvider, TtsConcurrencyPolicy {
  final int concurrency;
  int activeRequests = 0;
  int maxActiveRequests = 0;
  int synthesisRequests = 0;

  _ConcurrentTestProvider({required this.concurrency});

  @override
  String get id => 'parallel_test';

  @override
  String get displayName => 'Parallel test';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: false,
    voiceDescription: false,
    maxCharsPerCall: 4000,
    streaming: false,
    outputFormats: ['mp3'],
    requiresNetwork: true,
    paid: false,
  );

  @override
  Future<int> get generationConcurrency async => concurrency;

  @override
  Future<bool> validate() async => true;

  @override
  Future<List<TtsVoice>> listPresetVoices() async => const [];

  @override
  Future<TtsChunk> synthesize({
    required String text,
    required TtsVoice voice,
    double speed = 1,
  }) async {
    synthesisRequests++;
    activeRequests++;
    if (activeRequests > maxActiveRequests) {
      maxActiveRequests = activeRequests;
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    activeRequests--;
    return TtsChunk(
      audioBytes: Uint8List.fromList([1, 2, 3]),
      durationMs: 1000,
      format: 'mp3',
    );
  }

  @override
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  }) => throw UnsupportedError('not used');

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) => throw UnsupportedError('not used');
}

class _TestManifestStore extends ManifestStore {
  final Directory root;
  ChapterManifest? saved;

  _TestManifestStore(this.root);

  @override
  Future<ChapterManifest?> load(String bookId, String chapterId) async => saved;

  @override
  Future<void> save(ChapterManifest manifest) async {
    saved = ChapterManifest.fromJson(manifest.toJson());
  }

  @override
  Future<void> deleteBook(String bookId) async {
    saved = null;
    final directory = Directory('${root.path}/$bookId');
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<String> segmentPath({
    required String bookId,
    required String chapterId,
    required String paragraphId,
    required String format,
  }) async {
    final directory = Directory('${root.path}/$bookId/$chapterId');
    await directory.create(recursive: true);
    return '${directory.path}/$paragraphId.$format';
  }

  Future<String> absolutePath(SegmentEntry segment) {
    return segmentPath(
      bookId: 'book',
      chapterId: 'chapter',
      paragraphId: segment.paragraphId,
      format: segment.format,
    );
  }
}
