import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_assistant_service.dart';
import '../ai/ai_models.dart';
import '../ai/ai_thread_repository.dart';
import '../ai/transcript_tool.dart';
import '../services/cache_manager.dart';
import '../data/book_sources/gutendex_repository.dart';
import '../data/dictionary/dictionary_repository.dart';
import '../data/dictionary/openai_compatible_explanation_provider.dart';
import '../data/podcasts/podcast_index_repository.dart';
import '../data/podcasts/podcast_repository.dart';
import '../data/settings/provider_selection_repository.dart';
import '../services/app_settings_reset_service.dart';
import '../services/app_icon_service.dart';
import '../services/generation_orchestrator.dart';
import '../services/lumina_audio_handler.dart';
import '../services/manifest_store.dart';
import '../services/podcast_transcription_service.dart';
import '../services/playback_progress_service.dart';
import '../services/sleep_timer_service.dart';
import '../tts/provider_registry.dart';
import 'database_provider.dart';
import 'app_preferences.dart';

export 'database_provider.dart';

final gutendexRepositoryProvider = Provider<GutendexRepository>((ref) {
  return GutendexRepository();
});

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  return PodcastRepository(ref.watch(appDatabaseProvider));
});

final podcastIndexRepositoryProvider = Provider<PodcastIndexRepository>((ref) {
  return PodcastIndexRepository();
});

final podcastTranscriptionServiceProvider =
    Provider<PodcastTranscriptionService>((ref) {
      final service = PodcastTranscriptionService(
        ref.watch(appDatabaseProvider),
      );
      ref.onDispose(service.dispose);
      return service;
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

final appSettingsResetServiceProvider = Provider<AppSettingsResetService>((
  ref,
) {
  return AppSettingsResetService(
    database: ref.watch(appDatabaseProvider),
    ttsProviders: ref.watch(providerRegistryProvider),
    llmProvider: ref.watch(openAiCompatibleExplanationProvider),
  );
});

final appIconGatewayProvider = Provider<AppIconGateway>((ref) {
  return const MethodChannelAppIconGateway();
});

final aiTranscriptToolsProvider = Provider<AiTranscriptTools>((ref) {
  return AiTranscriptTools(ref.watch(appDatabaseProvider));
});

final aiThreadRepositoryProvider = Provider<AiThreadRepository>((ref) {
  return AiThreadRepository(ref.watch(appDatabaseProvider));
});

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  final providerService = ref.watch(openAiCompatibleExplanationProvider);
  final selections = ref.watch(providerSelectionRepositoryProvider);
  return AiAssistantService(
    transcriptTools: ref.watch(aiTranscriptToolsProvider),
    threads: ref.watch(aiThreadRepositoryProvider),
    configurationLoader: () async {
      final provider = await providerService.activeProvider;
      if (provider == null) {
        throw const AiAssistantConfigurationException(
          'Configure and select an LLM provider in Settings first.',
        );
      }
      final apiKey = await providerService.apiKeyFor(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        throw AiAssistantConfigurationException(
          'The selected ${provider.displayName} provider has no API key.',
        );
      }
      final selectedModel = await selections.selectedLlmModel(provider.id);
      final defaultModel = switch (provider.kind) {
        LlmProviderKind.openAi =>
          OpenAiCompatibleExplanationProvider.openAiDefaultModel,
        LlmProviderKind.deepSeek =>
          OpenAiCompatibleExplanationProvider.defaultModel,
        _ => null,
      };
      final modelId = selectedModel ?? defaultModel;
      if (modelId == null || modelId.isEmpty) {
        throw AiAssistantConfigurationException(
          'Select a model for ${provider.displayName} in Settings first.',
        );
      }
      return AiServiceConfiguration(
        baseUrl: provider.baseUrl,
        apiKey: apiKey,
        modelId: modelId,
        protocol: provider.kind == LlmProviderKind.openAi
            ? AiApiProtocol.responses
            : AiApiProtocol.chatCompletions,
        disableThinking: provider.kind == LlmProviderKind.deepSeek,
      );
    },
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
  final preferences = ref.watch(appPreferencesProvider);
  return DictionaryRepository(
    ref.watch(appDatabaseProvider),
    explanationProvider: ref.watch(openAiCompatibleExplanationProvider),
    outputLanguageCode: preferences.resolvedLanguageCode(
      PlatformDispatcher.instance.locale,
    ),
  );
});

/// Manifest 文件存储。
final manifestStoreProvider = Provider<ManifestStore>((ref) => ManifestStore());

/// 缓存管理。
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager(
    ref.watch(manifestStoreProvider),
    ref.watch(generationOrchestratorProvider),
    ref.watch(appDatabaseProvider),
  );
});

/// 增量生成调度器。
final generationOrchestratorProvider = Provider<GenerationOrchestrator>((ref) {
  return GenerationOrchestrator(
    database: ref.watch(appDatabaseProvider),
    manifestStore: ref.watch(manifestStoreProvider),
  );
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
