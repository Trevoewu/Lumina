import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/providers.dart';
import '../../../services/kokoro_model_manager.dart';
import '../../../tts/models/tts_capabilities.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/providers/edge_tts_provider.dart';
import '../../../tts/providers/fish_audio_local_tts_provider.dart';
import '../../../tts/providers/kokoro_local_tts_provider.dart';
import '../../../tts/providers/minimax_tts_provider.dart';
import '../../../tts/tts_provider.dart';
import 'cache_management_screen.dart';
import 'voice_library_screen.dart';

/// pubspec.yaml 中声明的应用版本号。
const String _appVersion = '1.0.0+1';

/// 设置页：TTS Provider、API Key、阅读偏好、缓存清理入口。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _minimaxKeyController = TextEditingController();

  @override
  void dispose() {
    _minimaxKeyController.dispose();
    super.dispose();
  }

  /// 为每个 Provider 返回一个图标，便于快速识别。
  IconData _providerIcon(String id) {
    switch (id) {
      case MinimaxTtsProvider.idValue:
        return Icons.auto_awesome;
      case KokoroLocalTtsProvider.idValue:
        return Icons.memory;
      case FishAudioLocalTtsProvider.idValue:
        return Icons.graphic_eq;
      case EdgeTtsProvider.idValue:
        return Icons.cloud_outlined;
      default:
        return Icons.graphic_eq;
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(providerRegistryProvider);
    final active = ref.watch(activeTtsProviderIdProvider);
    final kokoroModelManager = ref.watch(kokoroModelManagerProvider);
    final fishAudioModelManager = ref.watch(fishAudioModelManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '设置',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _sectionHeader('TTS Provider'),
          ...registry.all.map(
            (p) => _buildProviderTile(
              p,
              p.id == active,
              kokoroModelManager: kokoroModelManager,
              fishAudioModelManager: fishAudioModelManager,
            ),
          ),
          _sectionDivider(),
          _buildNavTile(
            icon: Icons.record_voice_over_outlined,
            title: '音色库',
            subtitle: '同步预置音色 / 描述生成音色 / 管理本地音色',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VoiceLibraryScreen()),
              );
            },
          ),
          _buildNavTile(
            icon: Icons.cleaning_services_outlined,
            title: '缓存清理',
            subtitle: '按书 / 按章 / 全部清理生成音频',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CacheManagementScreen(),
                ),
              );
            },
          ),
          _sectionDivider(),
          _sectionHeader('阅读偏好'),
          _buildInfoTile(
            icon: Icons.speed,
            title: '播放倍速',
            subtitle: '支持 0.5x - 3.0x',
          ),
          _buildInfoTile(
            icon: Icons.bedtime_outlined,
            title: '定时关闭',
            subtitle: '15/30/60 分钟 / 本章结束',
          ),
          _sectionDivider(),
          _buildVersionFooter(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 组件构建方法
  // ---------------------------------------------------------------------------

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sectionDivider() => const SizedBox(height: 8);

  /// TTS Provider 选择项：选中项右侧显示绿色勾号。
  Widget _buildProviderTile(
    TtsProvider p,
    bool selected, {
    required KokoroModelManager kokoroModelManager,
    required LocalTtsModelManager fishAudioModelManager,
  }) {
    final localModelManager = switch (p.id) {
      KokoroLocalTtsProvider.idValue => kokoroModelManager,
      FishAudioLocalTtsProvider.idValue => fishAudioModelManager,
      _ => null,
    };
    final isMiniMax = p.id == MinimaxTtsProvider.idValue;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: StreamBuilder<KokoroModelStatus>(
        stream: localModelManager?.statusStream,
        initialData: localModelManager?.status,
        builder: (context, snapshot) {
          final status = snapshot.data;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(
              _providerIcon(p.id),
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            title: Text(
              p.displayName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capabilityText(p.capabilities),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 6),
                    _LocalModelInlineStatus(status: status),
                  ],
                ],
              ),
            ),
            trailing: localModelManager != null
                ? _LocalModelProviderActions(
                    selected: selected,
                    manager: localModelManager,
                    status: status ?? localModelManager.status,
                    onDetails: () => _showLocalModelDetails(
                      localModelManager,
                      status ?? localModelManager.status,
                    ),
                  )
                : isMiniMax
                ? _MiniMaxProviderActions(
                    selected: selected,
                    onDetails: () => _showMiniMaxDetails(),
                  )
                : selected
                ? const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 22,
                  )
                : const Icon(
                    Icons.radio_button_unchecked,
                    color: AppColors.surfaceHighlight,
                    size: 22,
                  ),
            onTap: () async {
              ref.read(activeTtsProviderIdProvider.notifier).set(p.id);
              await ref
                  .read(appDatabaseProvider)
                  .setSetting('active_provider_id', p.id);
            },
          );
        },
      ),
    );
  }

  /// 带 chevron 箭头的导航 ListTile（iOS 设置页风格）。
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  /// 纯展示用的 ListTile（暂未实现跳转）。
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  /// 底部版本信息。
  Widget _buildVersionFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          'Lumina $_appVersion',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLocalModel(LocalTtsModelManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${manager.displayName}？'),
        content: const Text('删除后，对应的本地 TTS 需要重新下载模型才能使用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await manager.deleteModel();
    }
  }

  void _showLocalModelDetails(
    LocalTtsModelManager manager,
    KokoroModelStatus initialStatus,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return StreamBuilder<KokoroModelStatus>(
          stream: manager.statusStream,
          initialData: initialStatus,
          builder: (context, snapshot) {
            final status = snapshot.data ?? manager.status;
            final installed = status.isInstalled;
            final downloading = status.isDownloading;

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            manager.displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: downloading
                              ? '取消下载'
                              : installed
                              ? '重新下载'
                              : '下载模型',
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: downloading
                                  ? AppColors.surfaceHighlight
                                  : AppColors.primary,
                              foregroundColor: downloading
                                  ? AppColors.textPrimary
                                  : Colors.black,
                            ),
                            icon: Icon(
                              downloading
                                  ? Icons.close
                                  : Icons.download_rounded,
                            ),
                            onPressed: downloading
                                ? manager.cancel
                                : installed
                                ? () => manager.redownload()
                                : () => manager.download(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '删除模型',
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: installed
                                ? AppColors.textSecondary
                                : AppColors.surfaceHighlight,
                            onPressed: downloading || !installed
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    await _confirmDeleteLocalModel(manager);
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _LocalModelInlineStatus(status: status),
                    if (downloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: status.progress <= 0 ? null : status.progress,
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceHighlight,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(status.progress * 100).clamp(0, 100).toStringAsFixed(1)}% · '
                        '${_formatBytes(status.downloadedBytes)} / ${_formatBytes(status.totalBytes)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildModelInfoRow(
                      icon: Icons.hub_outlined,
                      label: '来源',
                      value: '${manager.sourceLabel} · ${manager.repositoryId}',
                    ),
                    _buildModelInfoRow(
                      icon: Icons.storage_outlined,
                      label: '大小',
                      value: _formatBytes(manager.downloadBytes),
                    ),
                    _buildModelInfoRow(
                      icon: Icons.folder_outlined,
                      label: '保存位置',
                      value: status.modelPath ?? '正在读取路径',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMiniMaxDetails() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'MiniMax API Key',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: '保存 API Key',
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.save_outlined),
                        onPressed: () => _saveMiniMaxApiKey(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '测试连接',
                      child: IconButton(
                        icon: const Icon(Icons.wifi_tethering_outlined),
                        color: AppColors.textSecondary,
                        onPressed: () => _testMiniMaxConnection(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '用于 MiniMax 语音合成、音频克隆和描述生成。密钥会保存在系统安全存储中。',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _minimaxKeyController,
                  obscureText: true,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    hintText: '在这里填入 MiniMax API Key',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(
                      Icons.key_outlined,
                      color: AppColors.textSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildModelInfoRow(
                  icon: Icons.lock_outline,
                  label: '存储',
                  value: 'flutter_secure_storage',
                ),
                _buildModelInfoRow(
                  icon: Icons.auto_awesome,
                  label: '能力',
                  value: '预置音色、音频克隆、描述生成',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveMiniMaxApiKey(BuildContext sheetContext) async {
    final sheetNavigator = Navigator.of(sheetContext);
    final provider = ref
        .read(providerRegistryProvider)
        .get(MinimaxTtsProvider.idValue);
    if (provider is! MinimaxTtsProvider) return;

    await provider.setApiKey(_minimaxKeyController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('MiniMax API Key 已保存到安全存储')));
    sheetNavigator.pop();
  }

  Future<void> _testMiniMaxConnection(BuildContext sheetContext) async {
    final provider = ref
        .read(providerRegistryProvider)
        .get(MinimaxTtsProvider.idValue);
    final ok = provider is MinimaxTtsProvider && await provider.validate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'MiniMax 连接正常' : 'MiniMax 连接失败')),
    );
  }

  Widget _buildModelInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _capabilityText(TtsCapabilities caps) {
    final bits = <String>[];
    if (caps.paid) {
      bits.add('按量计费');
    } else {
      bits.add('免费');
    }
    if (caps.presetVoices) bits.add('预置音色');
    if (caps.voiceCloning) bits.add('音频克隆');
    if (caps.voiceDescription) bits.add('描述生成');
    return bits.join(' · ');
  }
}

class _LocalModelInlineStatus extends StatelessWidget {
  final KokoroModelStatus status;

  const _LocalModelInlineStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.state) {
      KokoroModelInstallState.installed => AppColors.primary,
      KokoroModelInstallState.failed => Colors.redAccent,
      KokoroModelInstallState.downloading => AppColors.primary,
      _ => AppColors.textSecondary,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.isDownloading) ...[
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              value: status.progress <= 0 ? null : status.progress,
              strokeWidth: 2,
              color: color,
            ),
          ),
        ] else ...[
          Icon(
            status.isInstalled
                ? Icons.check_circle
                : status.state == KokoroModelInstallState.failed
                ? Icons.error_outline
                : Icons.download_for_offline_outlined,
            size: 14,
            color: color,
          ),
        ],
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            status.isDownloading
                ? '模型下载中 ${(status.progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                : status.message ?? '模型未安装',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _LocalModelProviderActions extends StatelessWidget {
  final bool selected;
  final LocalTtsModelManager manager;
  final KokoroModelStatus status;
  final VoidCallback onDetails;

  const _LocalModelProviderActions({
    required this.selected,
    required this.manager,
    required this.status,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.isInstalled)
          const Tooltip(
            message: '模型已安装',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.download_done, color: AppColors.primary),
            ),
          )
        else
          Tooltip(
            message: status.isDownloading ? '取消下载' : '下载模型',
            child: IconButton(
              icon: Icon(status.isDownloading ? Icons.close : Icons.download),
              color: status.isDownloading
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              onPressed: status.isDownloading
                  ? manager.cancel
                  : manager.download,
            ),
          ),
        Tooltip(
          message: '模型详情',
          child: IconButton(
            icon: const Icon(Icons.info_outline),
            color: AppColors.textSecondary,
            onPressed: onDetails,
          ),
        ),
        Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? AppColors.primary : AppColors.surfaceHighlight,
          size: 22,
        ),
      ],
    );
  }
}

class _MiniMaxProviderActions extends StatelessWidget {
  final bool selected;
  final VoidCallback onDetails;

  const _MiniMaxProviderActions({
    required this.selected,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'API Key 详情',
          child: IconButton(
            icon: const Icon(Icons.key_outlined),
            color: AppColors.textSecondary,
            onPressed: onDetails,
          ),
        ),
        Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? AppColors.primary : AppColors.surfaceHighlight,
          size: 22,
        ),
      ],
    );
  }
}
