import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../tts/providers/edge_tts_provider.dart';
import '../tts/providers/fish_audio_api_tts_provider.dart';
import '../tts/providers/fish_audio_local_tts_provider.dart';
import '../tts/providers/kokoro_local_tts_provider.dart';
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

  ProviderRegistry() {
    final kokoro = KokoroLocalTtsProvider();
    final fish = FishAudioLocalTtsProvider();
    final fishApi = FishAudioApiTtsProvider(
      storage: const FlutterSecureStorage(),
    );
    final minimax = MinimaxTtsProvider(storage: const FlutterSecureStorage());
    final edge = EdgeTtsProvider();

    _providers[kokoro.id] = kokoro;
    _providers[fish.id] = fish;
    _providers[fishApi.id] = fishApi;
    _providers[minimax.id] = minimax;
    _providers[edge.id] = edge;
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
  @override
  String build() => KokoroLocalTtsProvider.idValue;

  void set(String providerId) {
    final registry = ref.read(providerRegistryProvider);
    if (registry.get(providerId) != null) {
      state = providerId;
    }
  }
}

final activeTtsProviderIdProvider =
    NotifierProvider<ActiveTtsProviderId, String>(ActiveTtsProviderId.new);

/// 当前活跃 Provider 实例。
final activeTtsProviderProvider = Provider<TtsProvider>((ref) {
  final id = ref.watch(activeTtsProviderIdProvider);
  final registry = ref.watch(providerRegistryProvider);
  return registry.get(id) ?? registry.get(KokoroLocalTtsProvider.idValue)!;
});

/// Provider 注册表单例。
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  return ProviderRegistry();
});
