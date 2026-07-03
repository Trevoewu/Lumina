import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/tts/provider_registry.dart';
import 'package:lumina/tts/providers/edge_tts_provider.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';

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
        FishAudioApiTtsProvider.idValue,
      );
      await container.read(activeTtsProviderIdProvider.notifier).load();

      expect(
        container.read(activeTtsProviderIdProvider),
        FishAudioApiTtsProvider.idValue,
      );

      await container
          .read(activeTtsProviderIdProvider.notifier)
          .set(EdgeTtsProvider.idValue);

      expect(
        await database.getSetting('active_provider_id'),
        EdgeTtsProvider.idValue,
      );
    },
  );
}
