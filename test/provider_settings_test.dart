import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/tts/models/tts_voice.dart';
import 'package:lumina/tts/provider_registry.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';
import 'package:lumina/tts/providers/minimax_tts_provider.dart';

void main() {
  test(
    'active TTS provider restores and persists through one controller',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await database.setSetting(
        'active_provider_id',
        MinimaxTtsProvider.idValue,
      );
      await container.read(activeTtsProviderIdProvider.notifier).load();

      expect(
        container.read(activeTtsProviderIdProvider),
        MinimaxTtsProvider.idValue,
      );

      await container
          .read(activeTtsProviderIdProvider.notifier)
          .set(FishAudioApiTtsProvider.idValue);

      expect(
        await database.getSetting('active_provider_id'),
        FishAudioApiTtsProvider.idValue,
      );
    },
  );

  test('stale TTS provider keeps the default and is not rewritten', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await database.setSetting('active_provider_id', 'removed-provider');
    await container.read(activeTtsProviderIdProvider.notifier).load();

    expect(
      container.read(activeTtsProviderIdProvider),
      FishAudioApiTtsProvider.idValue,
    );
    expect(await database.getSetting('active_provider_id'), 'removed-provider');

    await container
        .read(activeTtsProviderIdProvider.notifier)
        .set('unknown-provider');

    expect(
      container.read(activeTtsProviderIdProvider),
      FishAudioApiTtsProvider.idValue,
    );
    expect(await database.getSetting('active_provider_id'), 'removed-provider');
  });

  test(
    'removing a TTS provider clears local configuration and switches provider',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final fish = _RemovableFishAudioProvider();
      final minimax = _ConfiguredMinimaxProvider();
      final registry = ProviderRegistry()
        ..register(fish)
        ..register(minimax);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          providerRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await database.upsertVoice(
        const Voice(
          id: 'fish-voice',
          name: 'Fish Voice',
          providerId: FishAudioApiTtsProvider.idValue,
          type: 'preset',
          providerVoiceId: 'fish-voice-id',
          createdAt: 1,
        ),
      );
      await container
          .read(providerSelectionRepositoryProvider)
          .setSelectedVoice(FishAudioApiTtsProvider.idValue, 'fish-voice');
      await container
          .read(providerSelectionRepositoryProvider)
          .setSelectedTtsModel(FishAudioApiTtsProvider.idValue, 's2-pro');
      await container.read(ttsSettingsControllerProvider.future);

      await container
          .read(ttsSettingsControllerProvider.notifier)
          .removeProvider(FishAudioApiTtsProvider.idValue);

      expect(fish.apiKeyCleared, isTrue);
      expect(
        await database.getVoicesByProvider(FishAudioApiTtsProvider.idValue),
        isEmpty,
      );
      expect(
        await container
            .read(providerSelectionRepositoryProvider)
            .selectedVoice(FishAudioApiTtsProvider.idValue),
        isNull,
      );
      expect(
        await container
            .read(providerSelectionRepositoryProvider)
            .selectedTtsModel(FishAudioApiTtsProvider.idValue),
        isNull,
      );
      expect(
        container.read(activeTtsProviderIdProvider),
        MinimaxTtsProvider.idValue,
      );
    },
  );
}

class _RemovableFishAudioProvider extends FishAudioApiTtsProvider {
  String? _apiKey = 'fish-key';
  bool apiKeyCleared = false;

  @override
  Future<String?> get apiKey async => _apiKey;

  @override
  Future<void> clearApiKey() async {
    _apiKey = null;
    apiKeyCleared = true;
  }

  @override
  Future<bool> validate() async => _apiKey != null;

  @override
  Future<List<TtsVoice>> listPresetVoices() async => const [];
}

class _ConfiguredMinimaxProvider extends MinimaxTtsProvider {
  @override
  Future<String?> get apiKey async => 'minimax-key';

  @override
  Future<bool> validate() async => true;

  @override
  Future<List<TtsVoice>> listPresetVoices() async => const [];
}
