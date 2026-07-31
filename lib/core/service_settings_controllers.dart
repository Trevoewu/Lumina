import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart' as drift_db;
import '../data/dictionary/openai_compatible_explanation_provider.dart';
import '../services/podcast_transcription_service.dart';
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

class TtsSettingsState {
  final String? providerId;
  final String? providerName;
  final String? voiceId;
  final String? voiceName;
  final ServiceReadiness readiness;
  final List<ProviderOptionViewData> providers;
  final List<TtsVoice> voices;
  final ServiceSettingsNotice? notice;

  const TtsSettingsState({
    required this.providerId,
    required this.providerName,
    required this.voiceId,
    required this.voiceName,
    required this.readiness,
    required this.providers,
    required this.voices,
    this.notice,
  }) : assert(
         (providerId == null) == (providerName == null),
         'Provider id and name must be null together.',
       );
}

class LlmSettingsState {
  final String? providerId;
  final String? providerName;
  final String? modelId;
  final ServiceReadiness readiness;
  final List<ProviderOptionViewData> providers;
  final List<LlmProviderConfiguration> configurations;
  final ServiceSettingsNotice? notice;

  const LlmSettingsState({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.readiness,
    required this.providers,
    required this.configurations,
    this.notice,
  }) : assert(
         (providerId == null) == (providerName == null),
         'Provider id and name must be null together.',
       );
}

const _unsetAsrValue = Object();

class AsrSettingsState {
  final String providerName;
  final String modelName;
  final ServiceReadiness readiness;
  final bool modelInstalled;
  final String? modelPath;
  final int installedBytes;
  final int partialBytes;
  final int expectedBytes;
  final int chunkMinutes;
  final String languagePreference;
  final bool operationInProgress;
  final double? operationProgress;
  final String? operationMessage;
  final String? operationError;

  const AsrSettingsState({
    this.providerName = 'Local Whisper',
    this.modelName = 'Whisper Base',
    required this.readiness,
    required this.modelInstalled,
    this.modelPath,
    required this.installedBytes,
    required this.partialBytes,
    required this.expectedBytes,
    required this.chunkMinutes,
    required this.languagePreference,
    this.operationInProgress = false,
    this.operationProgress,
    this.operationMessage,
    this.operationError,
  });

  AsrSettingsState copyWith({
    ServiceReadiness? readiness,
    bool? modelInstalled,
    Object? modelPath = _unsetAsrValue,
    int? installedBytes,
    int? partialBytes,
    int? expectedBytes,
    int? chunkMinutes,
    String? languagePreference,
    bool? operationInProgress,
    Object? operationProgress = _unsetAsrValue,
    Object? operationMessage = _unsetAsrValue,
    Object? operationError = _unsetAsrValue,
  }) {
    return AsrSettingsState(
      providerName: providerName,
      modelName: modelName,
      readiness: readiness ?? this.readiness,
      modelInstalled: modelInstalled ?? this.modelInstalled,
      modelPath: identical(modelPath, _unsetAsrValue)
          ? this.modelPath
          : modelPath as String?,
      installedBytes: installedBytes ?? this.installedBytes,
      partialBytes: partialBytes ?? this.partialBytes,
      expectedBytes: expectedBytes ?? this.expectedBytes,
      chunkMinutes: chunkMinutes ?? this.chunkMinutes,
      languagePreference: languagePreference ?? this.languagePreference,
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
  static const supportedChunkMinutes = <int>[1, 3, 5];

  @override
  Future<AsrSettingsState> build() => _load();

  Future<AsrSettingsState> _load() async {
    final database = ref.read(appDatabaseProvider);
    final storedChunkMinutes = int.tryParse(
      await database.getSetting(
            PodcastTranscriptionService.chunkMinutesSettingKey,
          ) ??
          '',
    );
    final chunkMinutes = supportedChunkMinutes.contains(storedChunkMinutes)
        ? storedChunkMinutes!
        : PodcastTranscriptionService.defaultChunkMinutes;
    final storedLanguage = await database.getSetting(
      PodcastTranscriptionService.languagePreferenceSettingKey,
    );
    final languagePreference =
        storedLanguage ==
            PodcastTranscriptionService.automaticLanguagePreference
        ? PodcastTranscriptionService.automaticLanguagePreference
        : PodcastTranscriptionService.podcastLanguagePreference;

    try {
      final info = await ref
          .read(podcastTranscriptionServiceProvider)
          .getModelInfo();
      return AsrSettingsState(
        readiness: info.installed
            ? ServiceReadiness.ready
            : ServiceReadiness.setupRequired,
        modelInstalled: info.installed,
        modelPath: info.path,
        installedBytes: info.installedBytes,
        partialBytes: info.partialBytes,
        expectedBytes: info.expectedBytes,
        chunkMinutes: chunkMinutes,
        languagePreference: languagePreference,
      );
    } catch (error) {
      return AsrSettingsState(
        readiness: ServiceReadiness.error,
        modelInstalled: false,
        installedBytes: 0,
        partialBytes: 0,
        expectedBytes: PodcastTranscriptionService.baseModelExpectedBytes,
        chunkMinutes: chunkMinutes,
        languagePreference: languagePreference,
        operationError: error.toString(),
      );
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> installModel() async {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        operationInProgress: true,
        operationProgress: current.partialBytes > 0
            ? (current.partialBytes / current.expectedBytes).clamp(0, 1)
            : 0.0,
        operationMessage: 'Preparing Whisper Base download',
        operationError: null,
      ),
    );
    try {
      await ref
          .read(podcastTranscriptionServiceProvider)
          .installModel(
            onProgress: (progress, message) {
              final value = state.value;
              if (value == null) return;
              state = AsyncData(
                value.copyWith(
                  operationInProgress: true,
                  operationProgress: progress,
                  operationMessage: message,
                  operationError: null,
                ),
              );
            },
          );
      state = AsyncData(await _load());
    } catch (error) {
      final value = state.value ?? current;
      state = AsyncData(
        value.copyWith(
          readiness: ServiceReadiness.error,
          operationInProgress: false,
          operationProgress: null,
          operationMessage: null,
          operationError: error.toString(),
        ),
      );
    }
  }

  Future<void> deleteModel() async {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        operationInProgress: true,
        operationProgress: null,
        operationMessage: 'Removing Whisper Base',
        operationError: null,
      ),
    );
    try {
      await ref.read(podcastTranscriptionServiceProvider).deleteModel();
      state = AsyncData(await _load());
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          readiness: ServiceReadiness.error,
          operationInProgress: false,
          operationMessage: null,
          operationError: error.toString(),
        ),
      );
    }
  }

  Future<void> setChunkMinutes(int minutes) async {
    if (!supportedChunkMinutes.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    await ref
        .read(appDatabaseProvider)
        .setSetting(
          PodcastTranscriptionService.chunkMinutesSettingKey,
          '$minutes',
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(chunkMinutes: minutes));
  }

  Future<void> setLanguagePreference(String preference) async {
    const supported = {
      PodcastTranscriptionService.podcastLanguagePreference,
      PodcastTranscriptionService.automaticLanguagePreference,
    };
    if (!supported.contains(preference)) {
      throw ArgumentError.value(preference, 'preference');
    }
    await ref
        .read(appDatabaseProvider)
        .setSetting(
          PodcastTranscriptionService.languagePreferenceSettingKey,
          preference,
        );
    final current = state.requireValue;
    state = AsyncData(current.copyWith(languagePreference: preference));
  }
}

class TtsSettingsController extends AsyncNotifier<TtsSettingsState> {
  ServiceSettingsNotice? _notice;

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
        notice: _notice,
      );
    }

    final voices = await _voicesFor(provider.id);
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
    var readiness = ServiceReadiness.setupRequired;
    try {
      if (selectedVoice != null && await provider.validate()) {
        readiness = ServiceReadiness.ready;
      }
    } catch (_) {
      readiness = ServiceReadiness.error;
    }

    return TtsSettingsState(
      providerId: provider.id,
      providerName: provider.displayName,
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
      voices: voices,
      notice: _notice,
    );
  }

  Future<void> reload() async => ref.invalidateSelf();

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
    return LlmSettingsState(
      providerId: active?.id,
      providerName: active?.displayName,
      modelId: modelId,
      readiness: readiness,
      providers: options,
      configurations: configurations,
      notice: _notice,
    );
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
