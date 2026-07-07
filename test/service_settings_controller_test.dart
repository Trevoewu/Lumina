import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/tts/api_key_store.dart';

void main() {
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
