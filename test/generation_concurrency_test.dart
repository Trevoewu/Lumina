import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
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
}

class _ConcurrentTestProvider implements TtsProvider, TtsConcurrencyPolicy {
  final int concurrency;
  int activeRequests = 0;
  int maxActiveRequests = 0;

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
