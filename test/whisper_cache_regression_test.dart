import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/podcasts/podcast_repository.dart';
import 'package:lumina/services/cache_manager.dart';
import 'package:lumina/services/generation_orchestrator.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/services/podcast_transcription_service.dart';
import 'package:lumina/services/transcription_storage.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:whisper_ggml/src/models/whisper_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase database;
  late _Controller controller;
  late PodcastTranscriptionService service;
  late CacheManager cache;
  late PodcastEpisode episode;
  late _Adapter adapter;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('whisper_cache_regression_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    database = AppDatabase.forTesting(NativeDatabase.memory());
    controller = _Controller(root);
    adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    service = PodcastTranscriptionService(
      database,
      controller: controller,
      dio: dio,
      audioProbe: (_) async => 60000,
      audioExtractor:
          ({
            required sourcePath,
            required targetPath,
            required startMs,
            required durationMs,
          }) async {
            await File(targetPath).writeAsBytes([1, 2, 3]);
            return true;
          },
    );
    final manifests = ManifestStore(documentsDirectory: () async => root);
    cache = CacheManager(
      manifests,
      GenerationOrchestrator(database: database, manifestStore: manifests),
      database,
      transcriptionService: service,
    );
    await database.upsertPodcastShow(
      const PodcastShow(
        id: 'show',
        feedUrl: 'https://example.com/feed.xml',
        title: 'Show',
        description: '',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      ),
    );
    final audio = File('${root.path}/original.mp3');
    await audio.writeAsBytes(adapter.bytes);
    episode = PodcastEpisode(
      id: 'episode',
      showId: 'show',
      guid: 'guid',
      title: 'Episode',
      description: '',
      audioUrl: 'https://example.com/original.mp3',
      publishedAt: 1,
      durationMs: 60000,
      playbackPositionMs: 0,
      lastPlayedAt: 0,
      isPlayed: false,
      transcriptProgressMs: 0,
      transcriptStatus: 'none',
      localAudioPath: audio.path,
    );
    await database.upsertPodcastEpisode(episode);
  });

  tearDown(() async {
    await service.pause();
    service.dispose();
    await database.close();
    await root.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test(
    'selected model stays fixed for every chunk, even if settings change mid-run',
    () async {
      await service.selectModel(WhisperModel.small);
      controller.onTranscribe = () async =>
          service.selectModel(WhisperModel.tiny);
      await service.transcribe(episode, languageHint: 'en');
      expect(controller.models, [WhisperModel.small, WhisperModel.small]);
      final task = await database.getLatestGenerationTask(
        kind: 'whisper',
        parentId: 'show',
        scopeId: 'episode',
      );
      expect(jsonDecode(task!.configJson)['model'], 'small');
      await service.transcribe(episode, languageHint: 'en');
      expect(controller.models, [WhisperModel.small, WhisperModel.small]);
    },
  );

  test(
    'completed transcript loads without audio downloads or installed models',
    () async {
      final original = await service.transcribe(episode, languageHint: 'en');
      await cache.clearPodcastEpisodeAudio(episode.id);
      controller.allowModelLookup = false;
      final resumed = await service.transcribe(episode, languageHint: 'en');
      expect(resumed.map((s) => s.text), original.map((s) => s.text));
      expect(controller.models, hasLength(2));
      expect(adapter.downloads, 0);
      expect(
        (await database.getGenerationTasks(kind: 'whisper')),
        hasLength(1),
      );
    },
  );

  test(
    'paused prefix survives a redownload and only the remaining chunk runs',
    () async {
      Future<void>? paused;
      controller.onTranscribe = () async {
        paused ??= service.pause();
      };
      await service.transcribe(episode, languageHint: 'en');
      await paused;
      expect(
        (await database.getPodcastEpisode(episode.id))!.transcriptProgressMs,
        30000,
      );
      controller.onTranscribe = null;
      await cache.clearPodcastEpisodeAudio(episode.id);
      await service.transcribe(episode, languageHint: 'en');
      expect(controller.models, hasLength(2));
      expect(controller.audioPaths.map((p) => p.split('/').last), [
        'chunk_000000000.wav',
        'chunk_000030000.wav',
      ]);
    },
  );

  test(
    'legacy completed subtitles survive model changes without regeneration',
    () async {
      await database.updatePodcastTranscript(
        episode.id,
        status: 'complete',
        transcriptJson: '[{"text":"legacy","startMs":0,"endMs":60000}]',
        language: 'en',
        progressMs: 60000,
      );
      await service.selectModel(WhisperModel.small);
      final result = await service.transcribe(episode, languageHint: 'en');
      expect(controller.models, isEmpty);
      expect(result.single.text, 'legacy');
      expect(adapter.downloads, 0);
      expect(
        (await database.getPodcastEpisode(episode.id))!.transcriptStatus,
        'complete',
      );
    },
  );

  test(
    'completed subtitles are retained until explicit regeneration',
    () async {
      await service.transcribe(episode, languageHint: 'en');
      final file = File(episode.localAudioPath!);
      final modified = await file.lastModified();
      await file.writeAsBytes(List<int>.filled(adapter.bytes.length, 9));
      await file.setLastModified(modified);
      await service.transcribe(episode, languageHint: 'en');
      expect(controller.models, hasLength(2));
      await cache.clearPodcastEpisodeTranscript(episode.id);
      await service.transcribe(episode, languageHint: 'en');
      expect(controller.models, hasLength(4));
      expect(await database.getGenerationTasks(kind: 'whisper'), hasLength(1));
    },
  );

  test(
    'legacy partial subtitles survive changed models and chunk sizes',
    () async {
      await database.updatePodcastTranscript(
        episode.id,
        status: 'paused',
        transcriptJson: '[{"text":"Already saved","startMs":0,"endMs":29000}]',
        language: 'en',
        progressMs: 30000,
      );
      await service.selectModel(WhisperModel.small);
      await service.selectChunkSeconds(60);
      final result = await service.transcribe(episode, languageHint: 'en');
      expect(result.first.text, 'Already saved');
      expect(controller.models, [WhisperModel.small]);
      expect(controller.audioPaths.single, endsWith('chunk_000030000.wav'));
      await service.transcribe(episode, languageHint: 'en');
      expect(controller.models, hasLength(1));
    },
  );

  test(
    'reopening with a new service loads saved subtitles while offline',
    () async {
      final original = await service.transcribe(episode, languageHint: 'en');
      await cache.clearPodcastEpisodeAudio(episode.id);
      final reopenedController = _Controller(root)..allowModelLookup = false;
      final reopened = PodcastTranscriptionService(
        database,
        controller: reopenedController,
        dio: Dio()..httpClientAdapter = adapter,
        audioProbe: (_) =>
            throw StateError('cached subtitles do not probe audio'),
      );
      addTearDown(reopened.dispose);
      final result = await reopened.transcribe(episode, languageHint: 'ja');
      expect(result.map((s) => s.text), original.map((s) => s.text));
      expect(reopenedController.models, isEmpty);
      expect(adapter.downloads, 0);
    },
  );

  test(
    'completed task checkpoints restore a missing episode snapshot without ASR',
    () async {
      await service.transcribe(episode, languageHint: 'en');
      await database.updatePodcastTranscript(
        episode.id,
        status: 'running',
        transcriptJson: '[]',
        progressMs: 0,
      );
      await cache.clearPodcastEpisodeAudio(episode.id);
      controller.allowModelLookup = false;
      final restored = await service.transcribe(episode, languageHint: 'en');
      expect(restored, hasLength(2));
      expect(controller.models, hasLength(2));
      expect(adapter.downloads, 0);
      expect(
        (await database.getPodcastEpisode(episode.id))!.transcriptStatus,
        'complete',
      );
    },
  );

  test(
    'clearing waits for the native chunk, then removes transcript and task checkpoints',
    () async {
      final entered = Completer<void>();
      final finish = Completer<void>();
      controller.onTranscribe = () async {
        entered.complete();
        await finish.future;
      };
      final running = service.transcribe(episode, languageHint: 'en');
      await entered.future;
      var cleared = false;
      final clearing = cache
          .clearPodcastEpisodeTranscript(episode.id)
          .then((_) => cleared = true);
      await Future<void>.delayed(Duration.zero);
      expect(cleared, isFalse);
      finish.complete();
      await running;
      await clearing;
      final stored = (await database.getPodcastEpisode(episode.id))!;
      expect(stored.transcriptStatus, 'none');
      expect(stored.transcriptJson, isNull);
      expect(stored.transcriptProgressMs, 0);
      expect(await database.getGenerationTasks(kind: 'whisper'), isEmpty);
      expect(controller.models, hasLength(1));
    },
  );

  test('clearing immediately after starting also settles the writer', () async {
    final running = service.transcribe(episode, languageHint: 'en');
    final clearing = cache.clearPodcastEpisodeTranscript(episode.id);
    await Future.wait([running, clearing]);
    expect(
      (await database.getPodcastEpisode(episode.id))!.transcriptStatus,
      'none',
    );
    expect(await database.getGenerationTasks(kind: 'whisper'), isEmpty);
  });

  test(
    'clearing data waits for downloads and removes the finished file',
    () async {
      await database.updatePodcastLocalAudioPath(episode.id, null);
      final entered = Completer<void>();
      final finish = Completer<void>();
      adapter.beforeDownload = () async {
        entered.complete();
        await finish.future;
      };
      final download = service.downloadEpisodeAudio(episode);
      await entered.future;
      final clearing = cache.clearPodcastEpisodeData(episode.id);
      finish.complete();
      final path = await download;
      await clearing;
      expect(await File(path).exists(), isFalse);
      expect(
        (await database.getPodcastEpisode(episode.id))!.localAudioPath,
        isNull,
      );
    },
  );

  test(
    'feed refresh invalidates old audio and transcript; stale caller downloads new source',
    () async {
      await service.transcribe(episode, languageHint: 'en');
      final repository = PodcastRepository(
        database,
        dio: Dio()..httpClientAdapter = adapter,
      );
      adapter.feedAudioUrl = 'https://example.com/replacement.mp3';
      final show = (await database.getPodcastShow('show'))!;
      await repository.refresh(show);
      final updated = (await database.getPodcastEpisode(episode.id))!;
      expect(updated.localAudioPath, isNull);
      expect(updated.transcriptJson, isNull);
      expect(updated.transcriptStatus, 'none');
      // An id-only legacy file must never become the replacement source.
      final legacy = File('${root.path}/podcasts/audio/${episode.id}.mp3');
      await legacy.parent.create(recursive: true);
      await legacy.writeAsBytes([8, 8, 8]);
      adapter.bytes = [7, 7, 7, 7];
      final path = await service.downloadEpisodeAudio(episode);
      expect(await File(path).readAsBytes(), adapter.bytes);
      expect(path.endsWith(transcriptionAudioFileName(updated)), isTrue);
      expect(adapter.lastAudioUrl, adapter.feedAudioUrl);
    },
  );

  test(
    'new source download never joins an old source download in flight',
    () async {
      await database.updatePodcastLocalAudioPath(episode.id, null);
      final entered = Completer<void>();
      final finish = Completer<void>();
      adapter.beforeDownload = () async {
        entered.complete();
        await finish.future;
      };
      final oldDownload = service.downloadEpisodeAudio(episode);
      final oldFails = expectLater(
        oldDownload,
        throwsA(isA<TranscriptionSourceChanged>()),
      );
      await entered.future;
      adapter.feedAudioUrl = 'https://example.com/replacement.mp3';
      await PodcastRepository(
        database,
        dio: Dio()..httpClientAdapter = adapter,
      ).refresh((await database.getPodcastShow('show'))!);
      adapter.beforeDownload = null;
      final newPath = await service.downloadEpisodeAudio(episode);
      finish.complete();
      await oldFails;
      expect(adapter.downloads, 2);
      expect(
        (await database.getPodcastEpisode(episode.id))!.localAudioPath,
        newPath,
      );
      expect(adapter.lastAudioUrl, adapter.feedAudioUrl);
    },
  );

  test(
    'requests during cache deletion wait until the mutation finishes',
    () async {
      final entered = Completer<void>();
      final finish = Completer<void>();
      final mutation = service.runEpisodeExclusive(episode.id, () async {
        entered.complete();
        await finish.future;
      });
      await entered.future;
      final run = service.transcribe(episode, languageHint: 'en');
      var downloaded = false;
      final download = service
          .downloadEpisodeAudio(episode)
          .then((_) => downloaded = true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.models, isEmpty);
      expect(downloaded, isFalse);
      finish.complete();
      await Future.wait([mutation, run, download]);
      expect(controller.models, hasLength(2));
      expect(downloaded, isTrue);
    },
  );

  test(
    'old source versions and partial downloads remain visible and can be cleared',
    () async {
      await database.updatePodcastLocalAudioPath(episode.id, null);
      final directory = Directory('${root.path}/podcasts/audio');
      await directory.create(recursive: true);
      final old = File('${directory.path}/${episode.id}.mp3');
      final partial = File(
        '${directory.path}/${transcriptionAudioFileName(episode)}.partial',
      );
      await old.writeAsBytes([1, 2, 3]);
      await partial.writeAsBytes([4, 5]);
      final current = (await database.getPodcastEpisode(episode.id))!;
      expect((await cache.usageForPodcastEpisode(current)).bytes, 5);
      await cache.clearPodcastEpisodeAudio(episode.id);
      expect(await old.exists(), isFalse);
      expect(await partial.exists(), isFalse);
    },
  );

  test(
    'a refresh during native ASR prevents the old run from repopulating new source state',
    () async {
      final entered = Completer<void>();
      final finish = Completer<void>();
      controller.onTranscribe = () async {
        entered.complete();
        await finish.future;
      };
      final running = service.transcribe(episode, languageHint: 'en');
      final fails = expectLater(
        running,
        throwsA(isA<TranscriptionSourceChanged>()),
      );
      await entered.future;
      adapter.feedAudioUrl = 'https://example.com/replacement.mp3';
      await PodcastRepository(
        database,
        dio: Dio()..httpClientAdapter = adapter,
      ).refresh((await database.getPodcastShow('show'))!);
      finish.complete();
      await fails;
      final updated = (await database.getPodcastEpisode(episode.id))!;
      expect(updated.transcriptStatus, 'none');
      expect(updated.transcriptJson, isNull);
      expect(updated.localAudioPath, isNull);
    },
  );
}

class _Controller extends WhisperController {
  final Directory root;
  final List<WhisperModel> models = [];
  final List<String> audioPaths = [];
  Future<void> Function()? onTranscribe;
  bool allowModelLookup = true;
  _Controller(this.root);

  @override
  Future<String> getPath(WhisperModel model) async {
    if (!allowModelLookup) throw StateError('cache hit must not need model');
    final file = File('${root.path}/${model.name}.bin');
    if (!await file.exists()) {
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(asrModelOptionFor(model).expectedBytes);
      await handle.close();
    }
    return file.path;
  }

  @override
  Future<TranscribeResult?> transcribe({
    required WhisperModel model,
    required String audioPath,
    String lang = 'en',
    bool diarize = false,
    String? initialPrompt,
    bool noContext = false,
    bool suppressNonSpeechTokens = false,
    bool withSegments = false,
    bool splitOnWord = false,
    bool keepModelLoaded = false,
    void Function(int percent)? onProgress,
  }) async {
    models.add(model);
    audioPaths.add(audioPath);
    await onTranscribe?.call();
    return TranscribeResult(
      time: Duration.zero,
      transcription: WhisperTranscribeResponse(
        type: 'transcription',
        text: '${model.name} chunk ${models.length}',
        segments: const [],
      ),
    );
  }
}

class _Adapter implements HttpClientAdapter {
  List<int> bytes = [1, 2, 3, 4];
  int downloads = 0;
  String? lastAudioUrl;
  String feedAudioUrl = 'https://example.com/original.mp3';
  Future<void> Function()? beforeDownload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('feed.xml')) {
      return ResponseBody.fromString(
        '''<rss version="2.0"><channel><title>Show</title>
        <item><guid>guid</guid><title>Episode</title>
        <enclosure url="$feedAudioUrl" type="audio/mpeg" /></item>
        </channel></rss>''',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/xml'],
        },
      );
    }
    downloads++;
    lastAudioUrl = options.path;
    await beforeDownload?.call();
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
