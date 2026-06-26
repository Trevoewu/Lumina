import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../services/cache_manager.dart';
import '../services/fish_audio_model_manager.dart';
import '../services/generation_orchestrator.dart';
import '../services/kokoro_model_manager.dart';
import '../services/lumina_audio_handler.dart';
import '../services/manifest_store.dart';

/// Drift 数据库单例。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Manifest 文件存储。
final manifestStoreProvider = Provider<ManifestStore>((ref) => ManifestStore());

/// 缓存管理。
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager(ref.watch(manifestStoreProvider));
});

/// 增量生成调度器。
final generationOrchestratorProvider = Provider<GenerationOrchestrator>((ref) {
  return GenerationOrchestrator(
    database: ref.watch(appDatabaseProvider),
    manifestStore: ref.watch(manifestStoreProvider),
  );
});

/// Kokoro 本地模型下载与安装状态。
final kokoroModelManagerProvider = Provider<KokoroModelManager>((ref) {
  final manager = KokoroModelManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Fish Audio S2 Pro 本地模型下载与安装状态。
final fishAudioModelManagerProvider = Provider<FishAudioModelManager>((ref) {
  final manager = FishAudioModelManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// AudioService 后台播放 handler。
final luminaAudioHandlerProvider = FutureProvider<LuminaAudioHandler>((
  ref,
) async {
  final handler = await initLuminaAudioHandler();
  ref.onDispose(handler.dispose);
  return handler;
});
