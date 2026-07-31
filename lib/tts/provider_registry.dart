import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database_provider.dart';
import 'api_key_store.dart';
import '../tts/providers/fish_audio_api_tts_provider.dart';
import '../tts/providers/minimax_tts_provider.dart';
import '../tts/tts_provider.dart';

/// Provider 注册表：统一管理所有 TTS Provider 实例。
///
/// 职责：
/// 1. 注册所有可用 Provider（内置 + 未来扩展点）
/// 2. 提供当前活跃 Provider 的访问
/// 3. 支持未来自定义 Provider / 本地模型 Provider 扩展。
class ProviderRegistry {
  final Map<String, TtsProvider> _providers = {};

  ProviderRegistry({
    TtsSettingReader? settingReader,
    TtsSettingWriter? settingWriter,
  }) {
    final apiKeyStore = ApiKeyStore();
    final fishApi = FishAudioApiTtsProvider(
      apiKeyStore: apiKeyStore,
      settingReader: settingReader,
      settingWriter: settingWriter,
    );
    final minimax = MinimaxTtsProvider(apiKeyStore: apiKeyStore);

    _providers[fishApi.id] = fishApi;
    _providers[minimax.id] = minimax;
  }

  /// 所有已注册的 Provider。
  List<TtsProvider> get all => _providers.values.toList();

  /// 按 id 获取 Provider。
  TtsProvider? get(String id) => _providers[id];

  /// 注册自定义 Provider（扩展点）。
  void register(TtsProvider provider) {
    _providers[provider.id] = provider;
  }
}

/// 当前活跃 Provider id。
class ActiveTtsProviderId extends Notifier<String> {
  bool _loaded = false;

  @override
  String build() => FishAudioApiTtsProvider.idValue;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final providerId = await ref
        .read(appDatabaseProvider)
        .getSetting('active_provider_id');
    if (providerId != null &&
        ref.read(providerRegistryProvider).get(providerId) != null) {
      state = providerId;
    }
  }

  Future<void> set(String providerId) async {
    final registry = ref.read(providerRegistryProvider);
    if (registry.get(providerId) != null) {
      state = providerId;
      await ref
          .read(appDatabaseProvider)
          .setSetting('active_provider_id', providerId);
    }
  }

  Future<void> reset() async {
    state = FishAudioApiTtsProvider.idValue;
    await ref
        .read(appDatabaseProvider)
        .setSetting('active_provider_id', FishAudioApiTtsProvider.idValue);
  }
}

final activeTtsProviderIdProvider =
    NotifierProvider<ActiveTtsProviderId, String>(ActiveTtsProviderId.new);

/// 当前活跃 Provider 实例。
final activeTtsProviderProvider = Provider<TtsProvider>((ref) {
  final id = ref.watch(activeTtsProviderIdProvider);
  final registry = ref.watch(providerRegistryProvider);
  return registry.get(id) ?? registry.get(FishAudioApiTtsProvider.idValue)!;
});

/// Provider 注册表单例。
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ProviderRegistry(
    settingReader: database.getSetting,
    settingWriter: database.setSetting,
  );
});
