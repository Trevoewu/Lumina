import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/services/app_settings_reset_service.dart';
import 'package:lumina/tts/api_key_store.dart';
import 'package:lumina/tts/provider_registry.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';
import 'package:lumina/tts/providers/minimax_tts_provider.dart';

void main() {
  test(
    'reset clears settings and credentials but preserves library data',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final fish = _ResettableFishAudioProvider();
      final minimax = _ResettableMinimaxProvider();
      final registry = ProviderRegistry()
        ..register(fish)
        ..register(minimax);
      final keyStore = _MemoryApiKeyStore();
      final llmProvider = OpenAiCompatibleExplanationProvider(
        apiKeyStore: keyStore,
        settingReader: database.getSetting,
        settingWriter: database.setSetting,
      );

      await database.upsertBook(
        const Book(
          id: 'book',
          title: 'Book',
          format: 'epub',
          sourcePath: '/book.epub',
          chapterCount: 1,
          paragraphCount: 1,
          currentParagraphIndex: 0,
          playbackOffsetMs: 1200,
          voiceId: 'voice',
          importedAt: 1,
          lastReadAt: 2,
          isRead: false,
          kind: 'book',
          rightsStatus: 'user_uploaded',
        ),
      );
      await database.insertChapters([
        const Chapter(
          id: 'chapter',
          bookId: 'book',
          chapterIndex: 0,
          title: 'Chapter',
          textOffset: 0,
          voiceId: 'voice',
          isHidden: false,
        ),
      ]);
      await database.upsertVoice(
        const Voice(
          id: 'voice',
          name: 'Narrator',
          providerId: FishAudioApiTtsProvider.idValue,
          type: 'preset',
          providerVoiceId: 'narrator',
          createdAt: 1,
        ),
      );
      await database.setSetting('general_theme_mode', 'dark');
      await llmProvider.addProvider(
        kind: LlmProviderKind.deepSeek,
        apiKey: 'llm-secret',
      );

      await AppSettingsResetService(
        database: database,
        ttsProviders: registry,
        llmProvider: llmProvider,
      ).reset();

      expect(fish.apiKeyCleared, isTrue);
      expect(minimax.apiKeyCleared, isTrue);
      expect(keyStore.values, isEmpty);
      expect(await database.getSetting('general_theme_mode'), isNull);
      expect(await database.getAllVoices(), isEmpty);
      expect((await database.getBook('book'))?.voiceId, isNull);
      expect((await database.getBook('book'))?.playbackOffsetMs, 1200);
      expect((await database.getChapters('book')).single.voiceId, isNull);
      expect(await llmProvider.configurations, isEmpty);
    },
  );
}

class _MemoryApiKeyStore extends ApiKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _ResettableFishAudioProvider extends FishAudioApiTtsProvider {
  bool apiKeyCleared = false;

  @override
  Future<void> clearApiKey() async {
    apiKeyCleared = true;
  }
}

class _ResettableMinimaxProvider extends MinimaxTtsProvider {
  bool apiKeyCleared = false;

  @override
  Future<void> clearApiKey() async {
    apiKeyCleared = true;
  }
}
