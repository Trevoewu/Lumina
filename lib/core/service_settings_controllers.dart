import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as drift_db;
import '../data/dictionary/openai_compatible_explanation_provider.dart';
import '../services/podcast_transcription_service.dart';
import '../tts/models/tts_model.dart';
import '../tts/models/tts_voice.dart';
import '../tts/provider_registry.dart';
import '../tts/providers/fish_audio_api_tts_provider.dart';
import '../tts/providers/minimax_tts_provider.dart';
import '../tts/tts_provider.dart';
import 'providers.dart';

enum AiServiceKind { tts, asr, dictionaryExplanation }

enum ServiceReadiness { loading, setupRequired, ready, error }

class ServiceSettingsNotice {
  final String message;
  final String? previousProviderName;

  const ServiceSettingsNotice({
    required this.message,
    this.previousProviderName,
  });
}

class ProviderOptionViewData {
  final String id;
  final String name;
  final String subtitle;
  final ServiceReadiness readiness;
  final bool active;
  final bool editable;
  final bool removable;

  const ProviderOptionViewData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.readiness,
    required this.active,
    required this.editable,
    required this.removable,
  });
}

/// A voice provider as the settings page draws it. Only the active card
/// expands to its model chips and voice rows.
class TtsProviderCardData {
  final String id;
  final String name;
  final String tag;
  final bool active;
  final bool configured;
  final String? selectedModelId;
  final String? selectedVoiceId;
  final List<TtsModel> models;
  final List<TtsVoice> voices;

  const TtsProviderCardData({
    required this.id,
    required this.name,
    required this.tag,
    required this.active,
    required this.configured,
    this.selectedModelId,
    this.selectedVoiceId,
    this.models = const [],
    this.voices = const [],
  });
}

class TtsSettingsState {
  final String? providerId;
  final String? providerName;
  final String? modelId;
  final String? modelName;
  final String? voiceId;
  final String? voiceName;
  final ServiceReadiness readiness;
  final List<ProviderOptionViewData> providers;
  final List<TtsModel> models;
  final List<TtsVoice> voices;
  final List<TtsProviderCardData> cards;
  final int chunkChars;
  final ServiceSettingsNotice? notice;

  const TtsSettingsState({
    required this.providerId,
    required this.providerName,
    this.modelId,
    this.modelName,
    required this.voiceId,
    required this.voiceName,
    required this.readiness,
    required this.providers,
    this.models = const [],
    required this.voices,
    this.cards = const [],
    this.chunkChars = TtsSettingsController.defaultChunkChars,
    this.notice,
  }) : assert(
         (providerId == null) == (providerName == null),
         'Provider id and name must be null together.',
       );
}

/// A configured LLM provider as the settings page draws it: the card shows
/// the preset tag and a meta line, and expands to the cached model chips when
/// it is the active one.
class LlmProviderCardData {
  final LlmProviderConfiguration configuration;
  final bool active;
  final String? selectedModelId;
  final List<String> models;
  final DateTime? syncedAt;
  final bool refreshing;

  const LlmProviderCardData({
    required this.configuration,
    required this.active,
    required this.selectedModelId,
    required this.models,
    required this.syncedAt,
    this.refreshing = false,
  });

  String get id => configuration.id;
  String get name => configuration.displayName;
  String get tag => configuration.kind.displayName;
}

class LlmSettingsState {
  final String? providerId;
  final String? providerName;
  final String? modelId;
  final ServiceReadiness readiness;
  final List<ProviderOptionViewData> providers;
  final List<LlmProviderConfiguration> configurations;
  final List<LlmProviderCardData> cards;
  final ServiceSettingsNotice? notice;

  const LlmSettingsState({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.readiness,
    required this.providers,
    required this.configurations,
    this.cards = const [],
    this.notice,
  }) : assert(
         (providerId == null) == (providerName == null),
         'Provider id and name must be null together.',
       );
}

const _unsetAsrValue = Object();

/// One Whisper weight as the settings page sees it.
class AsrModelViewData {
  final String id;
  final String name;
  final int expectedBytes;
  final bool installed;
  final bool active;
  final bool downloading;
  final double? progress;

  const AsrModelViewData({
    required this.id,
    required this.name,
    required this.expectedBytes,
    required this.installed,
    required this.active,
    this.downloading = false,
    this.progress,
  });
}

class AsrSettingsState {
  final String providerName;
  final String modelName;
  final ServiceReadiness readiness;
  final bool modelInstalled;
  final String? modelPath;
  final int installedBytes;
  final int partialBytes;
  final int expectedBytes;
  final int chunkSeconds;
  final List<AsrModelViewData> models;
  final bool operationInProgress;
  final double? operationProgress;
  final String? operationMessage;
  final String? operationError;

  const AsrSettingsState({
    this.providerName = 'Local Whisper',
    this.modelName = 'whisper-base',
    required this.readiness,
    required this.modelInstalled,
    this.modelPath,
    required this.installedBytes,
    required this.partialBytes,
    required this.expectedBytes,
    required this.chunkSeconds,
    this.models = const [],
    this.operationInProgress = false,
    this.operationProgress,
    this.operationMessage,
    this.operationError,
  });

  AsrSettingsState copyWith({
    String? modelName,
    ServiceReadiness? readiness,
    bool? modelInstalled,
    Object? modelPath = _unsetAsrValue,
    int? installedBytes,
    int? partialBytes,
    int? expectedBytes,
    int? chunkSeconds,
    List<AsrModelViewData>? models,
    bool? operationInProgress,
    Object? operationProgress = _unsetAsrValue,
    Object? operationMessage = _unsetAsrValue,
    Object? operationError = _unsetAsrValue,
  }) {
    return AsrSettingsState(
      providerName: providerName,
      modelName: modelName ?? this.modelName,
      readiness: readiness ?? this.readiness,
      modelInstalled: modelInstalled ?? this.modelInstalled,
      modelPath: identical(modelPath, _unsetAsrValue)
          ? this.modelPath
          : modelPath as String?,
      installedBytes: installedBytes ?? this.installedBytes,
      partialBytes: partialBytes ?? this.partialBytes,
      expectedBytes: expectedBytes ?? this.expectedBytes,
      chunkSeconds: chunkSeconds ?? this.chunkSeconds,
      models: models ?? this.models,
      operationInProgress: operationInProgress ?? this.operationInProgress,
      operationProgress: identical(operationProgress, _unsetAsrValue)
          ? this.operationProgress
          : operationProgress as double?,
      operationMessage: identical(operationMessage, _unsetAsrValue)
          ? this.operationMessage
          : operationMessage as String?,
      operationError: identical(operationError, _unsetAsrValue)
          ? this.operationError
          : operationError as String?,
    );
  }
}

class AsrSettingsController extends AsyncNotifier<AsrSettingsState> {
  static const supportedChunkSeconds =
      PodcastTranscriptionService.supportedChunkSeconds;

  /// Which weight is downloading right now, so only its card shows a bar.
  String? _downloadingId;
  double? _downloadingProgress;

  @override
  Future<AsrSettingsState> build() => _load();

  Future<AsrSettingsState> _load() async {
    final service = ref.read(podcastTranscriptionServiceProvider);
    final chunkSeconds = await service.selectedChunkSeconds();

    try {
      final infos = await service.listModelInfos();
      final active = await service.selectedModel();
      final activeInfo = infos.firstWhere(
        (info) => info.model == active,
        orElse: () => infos.first,
      );
      return AsrSettingsState(
        modelName: activeInfo.option.name,
        readiness: activeInfo.installed
            ? ServiceReadiness.ready
            : ServiceReadiness.setupRequired,
        modelInstalled: activeInfo.installed,
        modelPath: activeInfo.path,
        installedBytes: activeInfo.installedBytes,
        partialBytes: activeInfo.partialBytes,
        expectedBytes: activeInfo.expectedBytes,
        chunkSeconds: chunkSeconds,
        models: [
          for (final info in infos)
            AsrModelViewData(
              id: info.option.id,
              name: info.option.name,
              expectedBytes: info.option.expectedBytes,
              installed: info.installed,
              active: info.model == active,
              downloading: _downloadingId == info.option.id,
              progress: _downloadingId == info.option.id
                  ? _downloadingProgress
                  : null,
            ),
        ],
      );
    } catch (error) {
      return AsrSettingsState(
        readiness: ServiceReadiness.error,
        modelInstalled: false,
        installedBytes: 0,
        partialBytes: 0,
        expectedBytes: PodcastTranscriptionService.baseModelExpectedBytes,
        chunkSeconds: chunkSeconds,
        operationError: error.toString(),
      );
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Switches the weight used for future transcriptions. Only an installed
  /// model can become active.
  Future<void> selectModel(String id) async {
    final service = ref.read(podcastTranscriptionServiceProvider);
    final option = asrModelOptions.firstWhere(
      (o) => o.id == id,
      orElse: () => asrModelOptions.first,
    );
    await service.selectModel(option.model);
    state = AsyncData(await _load());
  }

  Future<void> installModel(String id) async {
    final option = asrModelOptions.firstWhere(
      (o) => o.id == id,
      orElse: () => asrModelOptions.first,
    );
    _downloadingId = option.id;
    _downloadingProgress = 0;
    state = AsyncData(
      (state.value ?? await _load()).copyWith(
        operationInProgress: true,
        operationProgress: 0.0,
        operationError: null,
      ),
    );
    state = AsyncData(await _load());
    try {
      await ref
          .read(podcastTranscriptionServiceProvider)
          .installModel(
            model: option.model,
            onProgress: (progress, message) {
              _downloadingProgress = progress;
              final value = state.value;
              if (value == null) return;
              state = AsyncData(
                value.copyWith(
                  operationInProgress: true,
                  operationProgress: progress,
                  operationMessage: message,
                  operationError: null,
                  models: [
                    for (final m in value.models)
                      m.id == option.id
                          ? AsrModelViewData(
                              id: m.id,
                              name: m.name,
                              expectedBytes: m.expectedBytes,
                              installed: m.installed,
                              active: m.active,
                              downloading: true,
                              progress: progress,
                            )
                          : m,
                  ],
                ),
              );
            },
          );
      _downloadingId = null;
      _downloadingProgress = null;
      // A freshly downloaded weight becomes the one that gets used.
      await ref
          .read(podcastTranscriptionServiceProvider)
          .selectModel(option.model);
      state = AsyncData(await _load());
    } catch (error) {
      _downloadingId = null;
      _downloadingProgress = null;
      final reloaded = await _load();
      state = AsyncData(
        reloaded.copyWith(
          operationInProgress: false,
          operationProgress: null,
          operationMessage: null,
          operationError: error.toString(),
        ),
      );
    }
  }

  Future<void> deleteModel(String id) async {
    final option = asrModelOptions.firstWhere(
      (o) => o.id == id,
      orElse: () => asrModelOptions.first,
    );
    try {
      await ref
          .read(podcastTranscriptionServiceProvider)
          .deleteModel(model: option.model);
      state = AsyncData(await _load());
    } catch (error) {
      final value = state.value ?? await _load();
      state = AsyncData(value.copyWith(operationError: error.toString()));
    }
  }

  Future<void> setChunkSeconds(int seconds) async {
    if (!supportedChunkSeconds.contains(seconds)) {
      throw ArgumentError.value(seconds, 'seconds');
    }
    await ref
        .read(podcastTranscriptionServiceProvider)
        .selectChunkSeconds(seconds);
    final current = state.requireValue;
    state = AsyncData(current.copyWith(chunkSeconds: seconds));
  }
}

class TtsSettingsController extends AsyncNotifier<TtsSettingsState> {
  /// Text slice length in characters, as offered by the settings spec. The
  /// provider's own per-call ceiling still applies on top of this.
  static const defaultChunkChars = 500;
  static const supportedChunkChars = <int>[200, 500, 1000, 2000];
  static const chunkCharsSettingKey = 'tts_chunk_chars';

  ServiceSettingsNotice? _notice;

  /// Reads the user's slice length, clamped to the offered options.
  static Future<int> readChunkChars(drift_db.AppDatabase database) async {
    final stored = int.tryParse(
      await database.getSetting(chunkCharsSettingKey) ?? '',
    );
    return supportedChunkChars.contains(stored) ? stored! : defaultChunkChars;
  }

  @override
  Future<TtsSettingsState> build() async {
    await ref.read(activeTtsProviderIdProvider.notifier).load();
    final activeId = ref.watch(activeTtsProviderIdProvider);
    final registry = ref.watch(providerRegistryProvider);
    final storedId = await ref
        .read(appDatabaseProvider)
        .getSetting('active_provider_id');
    if (storedId != null && registry.get(storedId) == null) {
      _notice = ServiceSettingsNotice(
        message: 'The previous voice provider is no longer available.',
        previousProviderName: storedId,
      );
      await ref.read(activeTtsProviderIdProvider.notifier).set(activeId);
    }
    final provider = registry.get(activeId);
    if (provider == null) {
      return TtsSettingsState(
        providerId: null,
        providerName: null,
        voiceId: null,
        voiceName: null,
        readiness: ServiceReadiness.setupRequired,
        providers: [
          for (final item in registry.all)
            ProviderOptionViewData(
              id: item.id,
              name: item.displayName,
              subtitle: _ttsSubtitle(item.capabilities.requiresNetwork),
              readiness: ServiceReadiness.setupRequired,
              active: false,
              editable: true,
              removable: true,
            ),
        ],
        voices: const [],
        cards: [
          for (final item in registry.all)
            TtsProviderCardData(
              id: item.id,
              name: item.displayName,
              tag: _ttsSubtitle(item.capabilities.requiresNetwork),
              active: false,
              configured: false,
            ),
        ],
        chunkChars: await readChunkChars(ref.read(appDatabaseProvider)),
        notice: _notice,
      );
    }

    final voices = await _voicesFor(provider.id);
    final models = switch (provider) {
      TtsModelCatalog catalog => await catalog.listModels(),
      _ => const <TtsModel>[],
    };
    final selections = ref.watch(providerSelectionRepositoryProvider);
    await selections.migrateLegacyTtsVoice(
      activeTtsProviderId: provider.id,
      voiceBelongsToProvider: (providerId, voiceId) async => voices.any(
        (voice) =>
            voice.providerId == providerId &&
            (voice.id == voiceId || voice.providerVoiceId == voiceId),
      ),
    );
    final selectedId = await selections.selectedVoice(provider.id);
    final selectedVoice = _findVoice(voices, selectedId);
    final selectedModelId = await selections.selectedTtsModel(provider.id);
    final selectedModel = _findModel(models, selectedModelId);
    var readiness = ServiceReadiness.setupRequired;
    try {
      if (selectedModelId != null &&
          selectedVoice != null &&
          await provider.validate()) {
        readiness = ServiceReadiness.ready;
      }
    } catch (_) {
      readiness = ServiceReadiness.error;
    }

    return TtsSettingsState(
      providerId: provider.id,
      providerName: provider.displayName,
      modelId: selectedModelId,
      modelName: selectedModel?.name ?? selectedModelId,
      voiceId: selectedVoice?.id,
      voiceName: selectedVoice?.name,
      readiness: readiness,
      providers: [
        for (final item in registry.all)
          ProviderOptionViewData(
            id: item.id,
            name: item.displayName,
            subtitle: _ttsSubtitle(item.capabilities.requiresNetwork),
            readiness: item.id == provider.id
                ? readiness
                : ServiceReadiness.setupRequired,
            active: item.id == provider.id,
            editable: true,
            removable: true,
          ),
      ],
      models: models,
      voices: voices,
      cards: [
        for (final item in registry.all)
          TtsProviderCardData(
            id: item.id,
            name: item.displayName,
            tag: _ttsSubtitle(item.capabilities.requiresNetwork),
            active: item.id == provider.id,
            configured: (await _apiKeyFor(item))?.isNotEmpty == true,
            selectedModelId: item.id == provider.id ? selectedModelId : null,
            selectedVoiceId: item.id == provider.id ? selectedVoice?.id : null,
            models: item.id == provider.id ? models : const [],
            voices: item.id == provider.id ? voices : const [],
          ),
      ],
      chunkChars: await readChunkChars(ref.read(appDatabaseProvider)),
      notice: _notice,
    );
  }

  Future<void> reload() async => ref.invalidateSelf();

  Future<String?> _apiKeyFor(TtsProvider provider) async {
    return switch (provider) {
      FishAudioApiTtsProvider value => await value.apiKey,
      MinimaxTtsProvider value => await value.apiKey,
      _ => null,
    };
  }

  /// The stored key for a provider, so the editor sheet can prefill it.
  Future<String?> apiKeyFor(String providerId) async {
    final provider = ref.read(providerRegistryProvider).get(providerId);
    return provider == null ? null : _apiKeyFor(provider);
  }

  /// Saves a provider's key. An empty value clears it.
  Future<void> setApiKey(String providerId, String key) async {
    final provider = ref.read(providerRegistryProvider).get(providerId);
    final trimmed = key.trim();
    switch (provider) {
      case FishAudioApiTtsProvider value:
        trimmed.isEmpty
            ? await value.clearApiKey()
            : await value.setApiKey(trimmed);
      case MinimaxTtsProvider value:
        trimmed.isEmpty
            ? await value.clearApiKey()
            : await value.setApiKey(trimmed);
      default:
        return;
    }
    ref.invalidate(ttsProviderConfigurationStatusProvider);
    ref.invalidateSelf();
  }

  Future<void> setChunkChars(int chars) async {
    if (!supportedChunkChars.contains(chars)) {
      throw ArgumentError.value(chars, 'chars');
    }
    await ref
        .read(appDatabaseProvider)
        .setSetting(chunkCharsSettingKey, '$chars');
    ref.invalidateSelf();
  }

  Future<void> selectProvider(String providerId) async {
    final registry = ref.read(providerRegistryProvider);
    final provider = registry.get(providerId);
    if (provider == null) return;
    if (!await provider.validate()) {
      throw StateError('Provider must be configured before activation.');
    }
    await ref.read(activeTtsProviderIdProvider.notifier).set(providerId);
    _notice = null;
    ref.invalidateSelf();
  }

  Future<void> removeProvider(String providerId) async {
    final registry = ref.read(providerRegistryProvider);
    final provider = registry.get(providerId);
    if (provider == null) return;

    switch (provider) {
      case FishAudioApiTtsProvider value:
        await value.clearApiKey();
      case MinimaxTtsProvider value:
        await value.clearApiKey();
      default:
        throw UnsupportedError('Provider cannot be removed.');
    }

    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedTtsModel(providerId, null);
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedVoice(providerId, null);
    await ref.read(appDatabaseProvider).deleteVoicesByProvider(providerId);

    final activeProviderId = ref.read(activeTtsProviderIdProvider);
    if (activeProviderId == providerId) {
      for (final candidate in registry.all) {
        if (candidate.id == providerId) continue;
        if (await _isTtsProviderConfigured(candidate)) {
          await ref
              .read(activeTtsProviderIdProvider.notifier)
              .set(candidate.id);
          break;
        }
      }
    }

    _notice = null;
    ref.invalidate(ttsProviderConfigurationStatusProvider);
    ref.invalidateSelf();
  }

  Future<void> selectVoice(String voiceId) async {
    final current = state.requireValue;
    final providerId = current.providerId;
    if (providerId == null ||
        !current.voices.any(
          (voice) => voice.providerId == providerId && voice.id == voiceId,
        )) {
      throw ArgumentError('Voice does not belong to the active provider.');
    }
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedVoice(providerId, voiceId);
    ref.invalidateSelf();
  }

  Future<void> selectModel(String modelId) async {
    final current = state.requireValue;
    final providerId = current.providerId;
    if (providerId == null ||
        !current.models.any((model) => model.id == modelId)) {
      throw ArgumentError('Model does not belong to the active provider.');
    }
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedTtsModel(providerId, modelId);
    ref.invalidateSelf();
  }

  Future<bool> testProvider() async {
    final providerId = state.requireValue.providerId;
    if (providerId == null) return false;
    try {
      return await ref
          .read(providerRegistryProvider)
          .get(providerId)!
          .validate();
    } finally {
      ref.invalidateSelf();
    }
  }

  Future<List<TtsVoice>> _voicesFor(String providerId) async {
    final database = ref.read(appDatabaseProvider);
    final provider = ref.read(providerRegistryProvider).get(providerId)!;
    final stored = await database.getVoicesByProvider(providerId);
    final voices = <TtsVoice>[
      for (final voice in stored) _voiceFromDb(voice),
      ...await provider.listPresetVoices(),
    ];
    final seen = <String>{};
    return [
      for (final voice in voices)
        if (seen.add(voice.id)) voice,
    ];
  }

  TtsVoice? _findVoice(List<TtsVoice> voices, String? selectedId) {
    if (selectedId == null) return null;
    for (final voice in voices) {
      if (voice.id == selectedId || voice.providerVoiceId == selectedId) {
        return voice;
      }
    }
    return null;
  }

  TtsModel? _findModel(List<TtsModel> models, String? selectedId) {
    if (selectedId == null) return null;
    for (final model in models) {
      if (model.id == selectedId) return model;
    }
    return null;
  }

  TtsVoice _voiceFromDb(drift_db.Voice voice) => TtsVoice(
    id: voice.id,
    name: voice.name,
    providerId: voice.providerId,
    type: VoiceType.values.byName(voice.type),
    providerVoiceId: voice.providerVoiceId,
    samplePath: voice.samplePath,
    description: voice.description,
    presetDescription: voice.presetDescription,
    previewUrl: voice.previewUrl,
    coverUrl: voice.coverUrl,
    languages: voice.languagesJson == null
        ? const []
        : (jsonDecode(voice.languagesJson!) as List<dynamic>)
              .whereType<String>()
              .toList(),
    sampleCount: voice.sampleCount ?? 0,
    createdAt: voice.createdAt,
  );

  String _ttsSubtitle(bool requiresNetwork) =>
      requiresNetwork ? 'Cloud service' : 'On-device service';
}

final ttsProviderConfigurationStatusProvider =
    FutureProvider<Map<String, bool>>((ref) async {
      final providers = ref.watch(providerRegistryProvider).all;
      final entries = await Future.wait(
        providers.map(
          (provider) async =>
              MapEntry(provider.id, await _isTtsProviderConfigured(provider)),
        ),
      );
      return Map.fromEntries(entries);
    });

Future<bool> _isTtsProviderConfigured(TtsProvider provider) async {
  try {
    return await _readTtsProviderConfiguration(provider);
  } catch (_) {
    return false;
  }
}

Future<bool> _readTtsProviderConfiguration(TtsProvider provider) async {
  if (provider is FishAudioApiTtsProvider) {
    return (await provider.apiKey)?.trim().isNotEmpty == true;
  }
  if (provider is MinimaxTtsProvider) {
    return (await provider.apiKey)?.trim().isNotEmpty == true;
  }
  return provider.validate();
}

class LlmSettingsController extends AsyncNotifier<LlmSettingsState> {
  ServiceSettingsNotice? _notice;
  String? _refreshingProviderId;

  @override
  Future<LlmSettingsState> build() async {
    final service = ref.watch(openAiCompatibleExplanationProvider);
    final configurations = await service.configurations;
    final storedId = await ref
        .read(appDatabaseProvider)
        .getSetting(
          OpenAiCompatibleExplanationProvider.activeProviderSettingKey,
        );
    LlmProviderConfiguration? active;
    for (final provider in configurations) {
      if (provider.id == storedId) active = provider;
    }
    final selections = ref.watch(providerSelectionRepositoryProvider);
    await selections.migrateLegacyLlmModel(
      activeLlmProviderId: active?.id,
      llmProviderExists: (providerId) async =>
          configurations.any((provider) => provider.id == providerId),
    );
    final modelId = active == null
        ? null
        : await selections.selectedLlmModel(active.id);
    var readiness = ServiceReadiness.setupRequired;
    if (active != null) {
      final uri = Uri.tryParse(active.baseUrl);
      final hasValidUrl = uri != null && uri.hasScheme && uri.host.isNotEmpty;
      final hasKey = (await service.apiKeyFor(active.id))?.isNotEmpty == true;
      if (hasValidUrl && hasKey && modelId != null) {
        readiness = ServiceReadiness.ready;
      }
    }
    final options = <ProviderOptionViewData>[];
    for (final provider in configurations) {
      final hasKey = (await service.apiKeyFor(provider.id))?.isNotEmpty == true;
      options.add(
        ProviderOptionViewData(
          id: provider.id,
          name: provider.displayName,
          subtitle: provider.hostLabel,
          readiness: hasKey
              ? ServiceReadiness.setupRequired
              : ServiceReadiness.error,
          active: provider.id == active?.id,
          editable: true,
          removable: true,
        ),
      );
    }
    final cards = <LlmProviderCardData>[];
    for (final provider in configurations) {
      final cache = await service.cachedModels(provider.id);
      cards.add(
        LlmProviderCardData(
          configuration: provider,
          active: provider.id == active?.id,
          selectedModelId: await selections.selectedLlmModel(provider.id),
          models: cache?.models ?? const [],
          syncedAt: cache?.syncedAt,
          refreshing: _refreshingProviderId == provider.id,
        ),
      );
    }
    return LlmSettingsState(
      providerId: active?.id,
      providerName: active?.displayName,
      modelId: modelId,
      readiness: readiness,
      providers: options,
      configurations: configurations,
      cards: cards,
      notice: _notice,
    );
  }

  /// Pulls the model list for one provider and caches it.
  Future<Object?> refreshModels(String providerId) async {
    final current = state.value;
    final provider = current?.configurations
        .where((item) => item.id == providerId)
        .firstOrNull;
    if (provider == null) return null;
    _refreshingProviderId = providerId;
    ref.invalidateSelf();
    try {
      final result = await ref
          .read(openAiCompatibleExplanationProvider)
          .refreshModels(provider);
      return result.error;
    } finally {
      _refreshingProviderId = null;
      ref.invalidateSelf();
    }
  }

  /// Chooses a model for a provider that is not necessarily the active one.
  Future<void> selectModelFor(String providerId, String modelId) async {
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedLlmModel(providerId, modelId);
    ref.invalidateSelf();
  }

  Future<void> reload() async => ref.invalidateSelf();

  Future<void> selectProvider(String providerId) async {
    final current = state.requireValue;
    if (!current.configurations.any((provider) => provider.id == providerId)) {
      throw ArgumentError('Unknown LLM provider.');
    }
    final provider = current.configurations.firstWhere(
      (item) => item.id == providerId,
    );
    if (!await ref
        .read(openAiCompatibleExplanationProvider)
        .validateProvider(provider)) {
      throw StateError(
        'Provider must pass its connection test before activation.',
      );
    }
    await ref
        .read(appDatabaseProvider)
        .setSetting(
          OpenAiCompatibleExplanationProvider.activeProviderSettingKey,
          providerId,
        );
    final selections = ref.read(providerSelectionRepositoryProvider);
    final selectedModel = await selections.selectedLlmModel(providerId);
    await selections.setSelectedLlmModel(providerId, selectedModel);
    _notice = null;
    ref.invalidateSelf();
  }

  Future<void> selectModel(String modelId) async {
    final providerId = state.requireValue.providerId;
    if (providerId == null) {
      throw StateError('Select a provider before selecting a model.');
    }
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedLlmModel(providerId, modelId);
    ref.invalidateSelf();
  }

  Future<bool> testProvider() async {
    final current = state.requireValue;
    final providerId = current.providerId;
    if (providerId == null) return false;
    final provider = current.configurations.firstWhere(
      (item) => item.id == providerId,
    );
    final result = await ref
        .read(openAiCompatibleExplanationProvider)
        .validateProvider(provider);
    ref.invalidateSelf();
    return result;
  }

  Future<LlmProviderConfiguration> addProvider({
    required LlmProviderKind kind,
    required String apiKey,
    String? displayName,
    String? baseUrl,
  }) async {
    final provider = await ref
        .read(openAiCompatibleExplanationProvider)
        .addProvider(
          kind: kind,
          apiKey: apiKey,
          displayName: displayName,
          baseUrl: baseUrl,
        );
    ref.invalidateSelf();
    return provider;
  }

  Future<void> updateProvider({
    required LlmProviderConfiguration provider,
    String? apiKey,
  }) async {
    await ref
        .read(openAiCompatibleExplanationProvider)
        .updateProvider(provider: provider, apiKey: apiKey);
    ref.invalidateSelf();
  }

  Future<void> removeProvider(String providerId) async {
    final current = state.requireValue;
    String? previousName;
    for (final provider in current.configurations) {
      if (provider.id == providerId) previousName = provider.displayName;
    }
    await ref
        .read(openAiCompatibleExplanationProvider)
        .removeProvider(providerId);
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedLlmModel(providerId, null);
    _notice = ServiceSettingsNotice(
      message: 'Provider removed',
      previousProviderName: previousName,
    );
    ref.invalidateSelf();
  }
}

final ttsSettingsControllerProvider =
    AsyncNotifierProvider<TtsSettingsController, TtsSettingsState>(
      TtsSettingsController.new,
    );

final asrSettingsControllerProvider =
    AsyncNotifierProvider<AsrSettingsController, AsrSettingsState>(
      AsrSettingsController.new,
    );

final llmSettingsControllerProvider =
    AsyncNotifierProvider<LlmSettingsController, LlmSettingsState>(
      LlmSettingsController.new,
    );
