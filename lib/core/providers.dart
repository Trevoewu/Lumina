import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache_manager.dart';
import '../data/book_sources/gutendex_repository.dart';
import '../data/dictionary/dictionary_repository.dart';
import '../data/dictionary/openai_compatible_explanation_provider.dart';
import '../data/settings/provider_selection_repository.dart';
import '../services/fish_audio_model_manager.dart';
import '../services/generation_orchestrator.dart';
import '../services/kokoro_model_manager.dart';
import '../services/lumina_audio_handler.dart';
import '../services/manifest_store.dart';
import '../services/playback_progress_service.dart';
import '../services/sleep_timer_service.dart';
import 'database_provider.dart';

export 'database_provider.dart';

final gutendexRepositoryProvider = Provider<GutendexRepository>((ref) {
  return GutendexRepository();
});

final openAiCompatibleExplanationProvider =
    Provider<OpenAiCompatibleExplanationProvider>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final selections = ref.watch(providerSelectionRepositoryProvider);
      return OpenAiCompatibleExplanationProvider(
        settingReader: database.getSetting,
        settingWriter: database.setSetting,
        modelReader: selections.selectedLlmModel,
        modelWriter: selections.setSelectedLlmModel,
      );
    });

final providerSelectionRepositoryProvider =
    Provider<ProviderSelectionRepository>((ref) {
      final database = ref.watch(appDatabaseProvider);
      return ProviderSelectionRepository(
        settingReader: database.getSetting,
        settingWriter: database.setSetting,
      );
    });

final dictionaryRepositoryProvider = Provider<DictionaryRepository>((ref) {
  return DictionaryRepository(
    ref.watch(appDatabaseProvider),
    explanationProvider: ref.watch(openAiCompatibleExplanationProvider),
  );
});

/// Manifest 文件存储。
final manifestStoreProvider = Provider<ManifestStore>((ref) => ManifestStore());

/// 缓存管理。
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager(ref.watch(manifestStoreProvider));
});

/// 增量生成调度器。
final generationOrchestratorProvider = Provider<GenerationOrchestrator>((ref) {
  return GenerationOrchestrator(
    database: ref.watch(appDatabaseProvider),
    manifestStore: ref.watch(manifestStoreProvider),
  );
});

/// Kokoro 本地模型下载与安装状态。
final kokoroModelManagerProvider = Provider<KokoroModelManager>((ref) {
  final manager = KokoroModelManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Fish Audio S2 Pro 本地模型下载与安装状态。
final fishAudioModelManagerProvider = Provider<FishAudioModelManager>((ref) {
  final manager = FishAudioModelManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// AudioService 后台播放 handler。
final luminaAudioHandlerProvider = FutureProvider<LuminaAudioHandler>((
  ref,
) async {
  final handler = await initLuminaAudioHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

final playbackProgressServiceProvider = FutureProvider<PlaybackProgressService>(
  (ref) async {
    final service = PlaybackProgressService(
      database: ref.watch(appDatabaseProvider),
      audioHandler: await ref.watch(luminaAudioHandlerProvider.future),
    )..start();
    ref.onDispose(() => unawaited(service.dispose()));
    return service;
  },
);

final sleepTimerServiceProvider = Provider<SleepTimerService>((ref) {
  final service = SleepTimerService();
  ref.onDispose(service.dispose);
  return service;
});
