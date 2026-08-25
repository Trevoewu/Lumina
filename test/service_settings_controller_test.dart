import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/services/podcast_transcription_service.dart';
import 'package:lumina/tts/api_key_store.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

void main() {
  test('ASR settings manage Whisper weights and persist the slice length', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final service = _FakePodcastTranscriptionService(database);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        podcastTranscriptionServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    var state = await container.read(asrSettingsControllerProvider.future);
    expect(state.readiness, ServiceReadiness.setupRequired);
    expect(state.modelInstalled, isFalse);
    expect(state.chunkSeconds, PodcastTranscriptionService.defaultChunkSeconds);
    expect(state.models, hasLength(asrModelOptions.length));
    expect(state.models.every((m) => !m.installed), isTrue);

    final controller = container.read(asrSettingsControllerProvider.notifier);
    await controller.setChunkSeconds(15);
    await controller.installModel('base');

    state = container.read(asrSettingsControllerProvider).requireValue;
    expect(state.readiness, ServiceReadiness.ready);
    expect(state.modelInstalled, isTrue);
    expect(state.chunkSeconds, 15);
    expect(
      await database.getSetting(
        PodcastTranscriptionService.chunkSecondsSettingKey,
      ),
      '15',
    );

    // A newly downloaded weight takes over as the active one.
    await controller.installModel('small');
    state = container.read(asrSettingsControllerProvider).requireValue;
    expect(state.modelName, 'whisper-small');
    expect(
      state.models.firstWhere((m) => m.id == 'small').active,
      isTrue,
    );

    // Switching back only works for a weight that is already on disk.
    await controller.selectModel('base');
    state = container.read(asrSettingsControllerProvider).requireValue;
    expect(state.modelName, 'whisper-base');

    await controller.deleteModel('small');
    state = container.read(asrSettingsControllerProvider).requireValue;
    expect(state.models.firstWhere((m) => m.id == 'small').installed, isFalse);
    expect(state.modelInstalled, isTrue);
  });

  test('LLM model selection remains scoped to the active provider', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final keyStore = _MemoryApiKeyStore();
    final service = OpenAiCompatibleExplanationProvider(
      apiKeyStore: keyStore,
      settingReader: database.getSetting,
      settingWriter: database.setSetting,
    );
    final configurations = [
      const LlmProviderConfiguration(
        id: 'provider-a',
        kind: LlmProviderKind.custom,
        displayName: 'Provider A',
        baseUrl: 'https://a.example.com',
      ),
      const LlmProviderConfiguration(
        id: 'provider-b',
        kind: LlmProviderKind.custom,
        displayName: 'Provider B',
        baseUrl: 'https://b.example.com',
      ),
    ];
    await database.setSetting(
      OpenAiCompatibleExplanationProvider.providerConfigurationsSettingKey,
      jsonEncode(configurations.map((item) => item.toJson()).toList()),
    );
    await database.setSetting(
      OpenAiCompatibleExplanationProvider.activeProviderSettingKey,
      'provider-a',
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        openAiCompatibleExplanationProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await container.read(llmSettingsControllerProvider.future);
    await container
        .read(llmSettingsControllerProvider.notifier)
        .selectModel('model-a');
    await container.read(llmSettingsControllerProvider.future);

    expect(
      await database.getSetting(
        OpenAiCompatibleExplanationProvider.activeProviderSettingKey,
      ),
      'provider-a',
    );
    expect(
      await container
          .read(providerSelectionRepositoryProvider)
          .selectedLlmModel('provider-a'),
      'model-a',
    );
    expect(
      await container
          .read(providerSelectionRepositoryProvider)
          .selectedLlmModel('provider-b'),
      isNull,
    );
  });

  test(
    'unconfigured LLM provider cannot replace the active provider',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final service = OpenAiCompatibleExplanationProvider(
        apiKeyStore: _MemoryApiKeyStore(),
        settingReader: database.getSetting,
        settingWriter: database.setSetting,
      );
      final configurations = [
        const LlmProviderConfiguration(
          id: 'provider-a',
          kind: LlmProviderKind.custom,
          displayName: 'Provider A',
          baseUrl: 'https://a.example.com',
        ),
        const LlmProviderConfiguration(
          id: 'provider-b',
          kind: LlmProviderKind.custom,
          displayName: 'Provider B',
          baseUrl: 'https://b.example.com',
        ),
      ];
      await database.setSetting(
        OpenAiCompatibleExplanationProvider.providerConfigurationsSettingKey,
        jsonEncode(configurations.map((item) => item.toJson()).toList()),
      );
      await database.setSetting(
        OpenAiCompatibleExplanationProvider.activeProviderSettingKey,
        'provider-a',
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          openAiCompatibleExplanationProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);
      await container.read(llmSettingsControllerProvider.future);

      await expectLater(
        container
            .read(llmSettingsControllerProvider.notifier)
            .selectProvider('provider-b'),
        throwsStateError,
      );
      expect(
        await database.getSetting(
          OpenAiCompatibleExplanationProvider.activeProviderSettingKey,
        ),
        'provider-a',
      );
    },
  );
}

class _MemoryApiKeyStore extends ApiKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakePodcastTranscriptionService extends PodcastTranscriptionService {
  /// Ids of the weights that are present on disk.
  final Set<String> installedIds = {};

  _FakePodcastTranscriptionService(super.database);

  bool get installed => installedIds.contains(_selected.id);

  AsrModelOption _selectedOption = asrModelOptionFor(
    PodcastTranscriptionService.defaultModel,
  );

  AsrModelOption get _selected => _selectedOption;

  @override
  Future<WhisperModel> selectedModel() async => _selectedOption.model;

  @override
  Future<void> selectModel(WhisperModel model) async {
    _selectedOption = asrModelOptionFor(model);
  }

  @override
  Future<PodcastAsrModelInfo> getModelInfo({WhisperModel? model}) async {
    final option = asrModelOptionFor(model ?? _selectedOption.model);
    final present = installedIds.contains(option.id);
    return PodcastAsrModelInfo(
      model: option.model,
      installed: present,
      path: '/tmp/${option.name}.bin',
      installedBytes: present ? option.expectedBytes : 0,
      partialBytes: 0,
      expectedBytes: option.expectedBytes,
    );
  }

  @override
  Future<void> installModel({
    WhisperModel? model,
    void Function(double? progress, String message)? onProgress,
  }) async {
    final option = asrModelOptionFor(model ?? _selectedOption.model);
    onProgress?.call(0.5, 'Downloading ${option.name}');
    installedIds.add(option.id);
    onProgress?.call(1, '${option.name} is ready');
  }

  @override
  Future<void> deleteModel({WhisperModel? model}) async {
    installedIds.remove(asrModelOptionFor(model ?? _selectedOption.model).id);
  }
}
