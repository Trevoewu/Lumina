import '../data/database/app_database.dart';
import '../data/dictionary/openai_compatible_explanation_provider.dart';
import '../tts/provider_registry.dart';
import '../tts/providers/fish_audio_api_tts_provider.dart';
import '../tts/providers/gpt_sovits_tts_provider.dart';
import '../tts/providers/minimax_tts_provider.dart';

class AppSettingsResetService {
  final AppDatabase database;
  final ProviderRegistry ttsProviders;
  final OpenAiCompatibleExplanationProvider llmProvider;

  const AppSettingsResetService({
    required this.database,
    required this.ttsProviders,
    required this.llmProvider,
  });

  Future<void> reset() async {
    for (final provider in ttsProviders.all) {
      switch (provider) {
        case FishAudioApiTtsProvider value:
          await value.clearApiKey();
        case MinimaxTtsProvider value:
          await value.clearApiKey();
        case GptSovitsTtsProvider value:
          await value.clearEndpoint();
      }
    }
    await llmProvider.clearAllConfiguration();
    await database.clearVoiceSettings();
    await database.clearSettings();
  }
}
