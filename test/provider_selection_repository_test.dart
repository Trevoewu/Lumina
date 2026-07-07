import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/settings/provider_selection_repository.dart';

void main() {
  late Map<String, String> settings;
  late ProviderSelectionRepository repository;

  setUp(() {
    settings = {};
    repository = ProviderSelectionRepository(
      settingReader: (key) async => settings[key],
      settingWriter: (key, value) async => settings[key] = value,
    );
  });

  test('migrates compatible legacy selections into provider maps', () async {
    settings[ProviderSelectionRepository.legacyTtsVoiceKey] = 'voice-a';
    settings[ProviderSelectionRepository.legacyLlmModelKey] = 'model-a';

    final result = await repository.migrateLegacySelections(
      activeTtsProviderId: 'tts-a',
      activeLlmProviderId: 'llm-a',
      voiceBelongsToProvider: (providerId, voiceId) async =>
          providerId == 'tts-a' && voiceId == 'voice-a',
      llmProviderExists: (providerId) async => providerId == 'llm-a',
    );

    expect(result.ttsVoice, SelectionMigrationStatus.migrated);
    expect(result.llmModel, SelectionMigrationStatus.migrated);
    expect(await repository.selectedVoice('tts-a'), 'voice-a');
    expect(await repository.selectedLlmModel('llm-a'), 'model-a');
    expect(
      settings[ProviderSelectionRepository.schemaVersionKey],
      ProviderSelectionRepository.currentSchemaVersion,
    );
  });

  test('rejects cross-provider or dangling legacy selections', () async {
    settings[ProviderSelectionRepository.legacyTtsVoiceKey] = 'voice-b';
    settings[ProviderSelectionRepository.legacyLlmModelKey] = 'model-b';

    final result = await repository.migrateLegacySelections(
      activeTtsProviderId: 'tts-a',
      activeLlmProviderId: 'removed-llm',
      voiceBelongsToProvider: (_, _) async => false,
      llmProviderExists: (_) async => false,
    );

    expect(result.ttsVoice, SelectionMigrationStatus.setupRequired);
    expect(result.llmModel, SelectionMigrationStatus.setupRequired);
    expect(await repository.selectedVoice('tts-a'), isNull);
    expect(await repository.selectedLlmModel('removed-llm'), isNull);
    expect(
      jsonDecode(settings[ProviderSelectionRepository.ttsVoiceMapKey]!),
      isEmpty,
    );
    expect(
      jsonDecode(settings[ProviderSelectionRepository.llmModelMapKey]!),
      isEmpty,
    );
  });

  test(
    'migration is idempotent and never reimports changed legacy data',
    () async {
      settings[ProviderSelectionRepository.legacyTtsVoiceKey] = 'voice-a';
      settings[ProviderSelectionRepository.legacyLlmModelKey] = 'model-a';
      Future<ProviderSelectionMigrationResult> migrate() =>
          repository.migrateLegacySelections(
            activeTtsProviderId: 'tts-a',
            activeLlmProviderId: 'llm-a',
            voiceBelongsToProvider: (_, _) async => true,
            llmProviderExists: (_) async => true,
          );

      await migrate();
      settings[ProviderSelectionRepository.legacyTtsVoiceKey] = 'voice-new';
      settings[ProviderSelectionRepository.legacyLlmModelKey] = 'model-new';
      final second = await migrate();

      expect(second.ttsVoice, SelectionMigrationStatus.alreadyMigrated);
      expect(second.llmModel, SelectionMigrationStatus.alreadyMigrated);
      expect(await repository.selectedVoice('tts-a'), 'voice-a');
      expect(await repository.selectedLlmModel('llm-a'), 'model-a');
    },
  );

  test('new selections are provider-scoped and mirror legacy keys', () async {
    await repository.setSelectedVoice('tts-a', 'voice-a');
    await repository.setSelectedVoice('tts-b', 'voice-b');
    await repository.setSelectedLlmModel('llm-a', 'model-a');
    await repository.setSelectedLlmModel('llm-b', 'model-b');

    expect(await repository.selectedVoice('tts-a'), 'voice-a');
    expect(await repository.selectedVoice('tts-b'), 'voice-b');
    expect(await repository.selectedLlmModel('llm-a'), 'model-a');
    expect(await repository.selectedLlmModel('llm-b'), 'model-b');
    expect(settings[ProviderSelectionRepository.legacyTtsVoiceKey], 'voice-b');
    expect(settings[ProviderSelectionRepository.legacyLlmModelKey], 'model-b');
  });
}
