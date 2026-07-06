import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../../core/providers.dart';
import '../../../services/app_log_service.dart';
import '../../../services/kokoro_model_manager.dart';
import '../../../tts/models/tts_capabilities.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/providers/edge_tts_provider.dart';
import '../../../tts/providers/fish_audio_api_tts_provider.dart';
import '../../../tts/providers/fish_audio_local_tts_provider.dart';
import '../../../tts/providers/kokoro_local_tts_provider.dart';
import '../../../tts/providers/minimax_tts_provider.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import 'appearance_screen.dart';
import 'cache_management_screen.dart';
import 'llm_model_screen.dart';
import 'llm_provider_screen.dart';
import 'logs_screen.dart';
import 'voice_library_screen.dart';

/// pubspec.yaml 中声明的应用版本号。
const String _appVersion = '1.0.0+1';

enum _ThemeMenuAction { system, light, dark, customize }

/// 设置页：TTS Provider、API Key、阅读偏好、缓存清理入口。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _minimaxKeyController = TextEditingController();
  final _fishApiKeyController = TextEditingController();
  bool _fadeInEnabled = true;
  bool? _miniMaxApiKeyConfigured;
  bool? _fishApiKeyConfigured;
  int? _llmProviderCount;
  String? _llmProviderName;
  String? _llmModel;
  FishAudioGenerationProfile _fishGenerationProfile =
      FishAudioGenerationProfile.fast;

  @override
  void initState() {
    super.initState();
    _loadAudioPreferences();
  }

  @override
  void dispose() {
    _minimaxKeyController.dispose();
    _fishApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadAudioPreferences() async {
    final value = await ref
        .read(appDatabaseProvider)
        .getSetting('audio_fade_in_enabled');
    final fishProvider = ref
        .read(providerRegistryProvider)
        .get(FishAudioApiTtsProvider.idValue);
    final fishProfile = fishProvider is FishAudioApiTtsProvider
        ? await fishProvider.generationProfile
        : FishAudioGenerationProfile.fast;
    final miniMaxProvider = ref
        .read(providerRegistryProvider)
        .get(MinimaxTtsProvider.idValue);
    final explanationProvider = ref.read(openAiCompatibleExplanationProvider);
    bool? miniMaxConfigured;
    bool? fishConfigured;
    var llmProviderCount = 0;
    String? llmProviderName;
    String? llmModel;
    try {
      if (miniMaxProvider is MinimaxTtsProvider) {
        miniMaxConfigured = (await miniMaxProvider.apiKey)?.isNotEmpty == true;
      }
      if (fishProvider is FishAudioApiTtsProvider) {
        fishConfigured = (await fishProvider.apiKey)?.isNotEmpty == true;
      }
      final providers = await explanationProvider.configurations;
      final activeProvider = await explanationProvider.activeProvider;
      llmProviderCount = providers.length;
      llmProviderName = activeProvider?.displayName;
      if (activeProvider != null) {
        final configuredModel = await explanationProvider.model;
        if (configuredModel.isNotEmpty) llmModel = configuredModel;
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Settings',
        '读取 API Key 状态失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() {
      _fadeInEnabled = value != 'false';
      _fishGenerationProfile = fishProfile;
      _miniMaxApiKeyConfigured = miniMaxConfigured;
      _fishApiKeyConfigured = fishConfigured;
      _llmProviderCount = llmProviderCount;
      _llmProviderName = llmProviderName;
      _llmModel = llmModel;
    });
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
      case FishAudioApiTtsProvider.idValue:
        return Icons.waves_outlined;
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
    final preferences = ref.watch(appPreferencesProvider);
    final kokoroModelManager = ref.watch(kokoroModelManagerProvider);
    final fishAudioModelManager = ref.watch(fishAudioModelManagerProvider);

    return CollapsingPageScaffold(
      title: context.tr('设置', 'Settings'),
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _sectionHeader(context.tr('通用', 'GENERAL')),
          _buildGeneralGroup(preferences),
          _sectionDivider(),
          _sectionHeader(context.tr('语音引擎', 'TTS PROVIDER')),
          _buildProviderGroup(
            registry.all,
            active,
            kokoroModelManager: kokoroModelManager,
            fishAudioModelManager: fishAudioModelManager,
          ),
          _sectionDivider(),
          _buildNavTile(
            icon: Icons.record_voice_over_outlined,
            title: context.tr('音色库', 'Voice Library'),
            subtitle: context.tr(
              '同步预置音色 / 描述生成音色 / 管理本地音色',
              'Sync presets, create voices, and manage local voices',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VoiceLibraryScreen()),
              );
            },
          ),
          _buildNavTile(
            icon: Icons.cleaning_services_outlined,
            title: context.tr('缓存清理', 'Audio Cache'),
            subtitle: context.tr(
              '按书 / 按章 / 全部清理生成音频',
              'Clear generated audio by book or chapter',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CacheManagementScreen(),
                ),
              );
            },
          ),
          _sectionDivider(),
          _sectionHeader(context.tr('词典解释', 'DICTIONARY EXPLANATION')),
          _buildLlmProviderGroup(),
          _sectionDivider(),
          _sectionHeader(context.tr('播放', 'PLAYBACK')),
          _buildSwitchTile(
            icon: Icons.volume_up_outlined,
            title: context.tr('段落淡入', 'Paragraph Fade-in'),
            subtitle: context.tr(
              '新生成的段落音频在开头淡入，减少切换突兀感',
              'Fade in generated segments for smoother transitions',
            ),
            value: _fadeInEnabled,
            onChanged: _setFadeInEnabled,
          ),
          StreamBuilder(
            stream: ref.watch(sleepTimerServiceProvider).stream,
            initialData: ref.watch(sleepTimerServiceProvider).state,
            builder: (context, snapshot) {
              return _buildInfoTile(
                icon: Icons.bedtime_outlined,
                title: context.tr('定时关闭', 'Sleep Timer'),
                subtitle: snapshot.data?.label ?? context.tr('关闭', 'Off'),
                onTap: _showSleepTimerSheet,
              );
            },
          ),
          _sectionDivider(),
          _sectionHeader(context.tr('辅助', 'SUPPORT')),
          _buildNavTile(
            icon: Icons.receipt_long_outlined,
            title: context.tr('日志', 'Logs'),
            subtitle: context.tr(
              '查看、复制和清理运行日志',
              'View, copy, and clear runtime logs',
            ),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LogsScreen()));
            },
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

  Widget _buildGeneralGroup(AppPreferences preferences) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageSelector(preferences.language),
          Divider(height: 1, indent: 56, color: context.appSurfaceHighlight),
          _buildThemeSelector(preferences.theme),
        ],
      ),
    );
  }

  Widget _buildGeneralRow({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    Key? key,
    String? subtitle,
    bool showSelector = true,
  }) {
    return ListTile(
      key: key,
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: context.appTextPrimary, size: 26),
      title: Text(
        title,
        style: TextStyle(
          color: context.appTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appTextSecondary, fontSize: 16),
            ),
          ),
          if (showSelector) ...[
            const SizedBox(width: 6),
            Icon(Icons.unfold_more, color: context.appTextSecondary, size: 20),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  String _languageLabel(AppLanguage language) {
    return switch (language) {
      AppLanguage.system => context.tr('跟随系统', 'System'),
      AppLanguage.zhHans => '简体中文',
      AppLanguage.english => 'English',
    };
  }

  String _themeLabel(AppThemePreference theme) {
    return switch (theme) {
      AppThemePreference.system => context.tr('跟随系统', 'System'),
      AppThemePreference.light => context.tr('浅色', 'Light'),
      AppThemePreference.dark => context.tr('深色', 'Dark'),
    };
  }

  Widget _buildLanguageSelector(AppLanguage selected) {
    return PopupMenuButton<AppLanguage>(
      key: const ValueKey('language-selector'),
      tooltip: context.tr('选择语言', 'Choose language'),
      position: PopupMenuPosition.under,
      color: context.appSurface,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (language) {
        ref.read(appPreferencesProvider.notifier).setLanguage(language);
      },
      itemBuilder: (_) => [
        for (final language in AppLanguage.values)
          PopupMenuItem(
            value: language,
            child: _popupChoice(
              label: _languageLabel(language),
              selected: language == selected,
            ),
          ),
      ],
      child: _buildGeneralRow(
        icon: Icons.language,
        title: context.tr('语言', 'Language'),
        value: _languageLabel(selected),
      ),
    );
  }

  Widget _buildThemeSelector(AppThemePreference selected) {
    return PopupMenuButton<_ThemeMenuAction>(
      key: const ValueKey('theme-selector'),
      tooltip: context.tr('选择主题', 'Choose theme'),
      position: PopupMenuPosition.under,
      color: context.appSurface,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 340),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (action) {
        final theme = switch (action) {
          _ThemeMenuAction.system => AppThemePreference.system,
          _ThemeMenuAction.light => AppThemePreference.light,
          _ThemeMenuAction.dark => AppThemePreference.dark,
          _ThemeMenuAction.customize => null,
        };
        if (theme != null) {
          ref.read(appPreferencesProvider.notifier).setTheme(theme);
          return;
        }
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AppearanceScreen()));
      },
      itemBuilder: (_) => [
        for (final entry in const [
          (action: _ThemeMenuAction.system, theme: AppThemePreference.system),
          (action: _ThemeMenuAction.light, theme: AppThemePreference.light),
          (action: _ThemeMenuAction.dark, theme: AppThemePreference.dark),
        ])
          PopupMenuItem(
            value: entry.action,
            child: _popupChoice(
              label: _themeLabel(entry.theme),
              selected: entry.theme == selected,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ThemeMenuAction.customize,
          child: Row(
            children: [
              Icon(Icons.text_fields, color: context.appTextSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(context.tr('字体、字号与主题色', 'Fonts, size, and accent')),
              ),
              Icon(Icons.chevron_right, color: context.appTextSecondary),
            ],
          ),
        ),
      ],
      child: _buildGeneralRow(
        icon: Icons.contrast,
        title: context.tr('外观', 'Appearance'),
        value: _themeLabel(selected),
      ),
    );
  }

  Widget _popupChoice({required String label, required bool selected}) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: selected
              ? Icon(Icons.check, color: context.appTextPrimary, size: 22)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: context.appTextPrimary, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          color: context.appTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sectionDivider() => const SizedBox(height: 8);

  Widget _buildProviderGroup(
    List<TtsProvider> providers,
    String activeId, {
    required KokoroModelManager kokoroModelManager,
    required LocalTtsModelManager fishAudioModelManager,
  }) {
    final activeProvider = providers.firstWhere(
      (provider) => provider.id == activeId,
      orElse: () => providers.first,
    );
    final localModelManager = switch (activeProvider.id) {
      KokoroLocalTtsProvider.idValue => kokoroModelManager,
      FishAudioLocalTtsProvider.idValue => fishAudioModelManager,
      _ => null,
    };
    final isMiniMax = activeProvider.id == MinimaxTtsProvider.idValue;
    final isFishApi = activeProvider.id == FishAudioApiTtsProvider.idValue;

    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<KokoroModelStatus>(
        stream: localModelManager?.statusStream,
        initialData: localModelManager?.status,
        builder: (context, snapshot) {
          final status = snapshot.data ?? localModelManager?.status;
          final managementRow = localModelManager != null && status != null
              ? _buildProviderManagementRow(
                  key: ValueKey('provider-details-${activeProvider.id}'),
                  icon: Icons.download_for_offline_outlined,
                  title: context.tr('模型管理', 'Model Management'),
                  value: _modelStatusLabel(status),
                  onTap: () =>
                      _showLocalModelDetails(localModelManager, status),
                )
              : isMiniMax || isFishApi
              ? _buildProviderManagementRow(
                  key: ValueKey('provider-details-${activeProvider.id}'),
                  icon: Icons.key_outlined,
                  title: 'API Key',
                  value: _apiKeyStatusLabel(
                    isMiniMax
                        ? _miniMaxApiKeyConfigured
                        : _fishApiKeyConfigured,
                  ),
                  onTap: isMiniMax ? _showMiniMaxDetails : _showFishApiDetails,
                )
              : null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                key: const ValueKey('tts-provider-selector'),
                tooltip: context.tr('选择语音引擎', 'Choose TTS provider'),
                position: PopupMenuPosition.under,
                color: context.appSurface,
                surfaceTintColor: Colors.transparent,
                constraints: const BoxConstraints(minWidth: 300, maxWidth: 420),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (providerId) {
                  ref
                      .read(activeTtsProviderIdProvider.notifier)
                      .set(providerId);
                },
                itemBuilder: (_) => [
                  for (final provider in providers)
                    PopupMenuItem(
                      value: provider.id,
                      child: Row(
                        children: [
                          Icon(
                            _providerIcon(provider.id),
                            color: context.appTextSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              provider.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (provider.id == activeProvider.id)
                            Icon(
                              Icons.check,
                              color: context.appTextPrimary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                ],
                child: _buildGeneralRow(
                  icon: _providerIcon(activeProvider.id),
                  title: context.tr('语音引擎', 'TTS Provider'),
                  value: activeProvider.displayName,
                  subtitle: _capabilityText(activeProvider.capabilities),
                ),
              ),
              if (managementRow != null) ...[
                Divider(
                  height: 1,
                  indent: 56,
                  color: context.appSurfaceHighlight,
                ),
                managementRow,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildProviderManagementRow({
    required Key key,
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: context.appTextSecondary, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: context.appTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: context.appTextSecondary, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: context.appTextSecondary),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildLlmProviderGroup() {
    final count = _llmProviderCount;
    final providerValue = count == null
        ? context.tr('读取中', 'Loading')
        : count == 0
        ? context.tr('未配置', 'Not configured')
        : context.tr('$count 个', '$count configured');
    final modelValue = _llmModel ?? context.tr('未选择', 'Not selected');
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGeneralRow(
            key: const ValueKey('llm-provider-settings'),
            icon: Icons.hub_outlined,
            title: 'LLM Provider',
            value: providerValue,
            subtitle: context.tr(
              'DeepSeek、Z.AI 或自定义 OpenAI 兼容接口',
              'DeepSeek, Z.AI, or a custom OpenAI-compatible API',
            ),
            showSelector: false,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LlmProviderScreen()),
              );
              await _loadAudioPreferences();
            },
          ),
          Divider(height: 1, indent: 56, color: context.appSurfaceHighlight),
          _buildGeneralRow(
            key: const ValueKey('llm-model-settings'),
            icon: Icons.psychology_outlined,
            title: context.tr('模型', 'Model'),
            value: modelValue,
            subtitle: _llmProviderName,
            showSelector: false,
            onTap: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LlmModelScreen()));
              await _loadAudioPreferences();
            },
          ),
        ],
      ),
    );
  }

  String _modelStatusLabel(KokoroModelStatus status) {
    return switch (status.state) {
      KokoroModelInstallState.installed => context.tr('已安装', 'Installed'),
      KokoroModelInstallState.downloading =>
        '${(status.progress * 100).round()}%',
      KokoroModelInstallState.failed => context.tr('下载失败', 'Failed'),
      _ =>
        status.downloadedBytes > 0
            ? context.tr(
                '可继续 ${(status.progress * 100).round()}%',
                'Resume ${(status.progress * 100).round()}%',
              )
            : context.tr('未安装', 'Not installed'),
    };
  }

  String _apiKeyStatusLabel(bool? configured) {
    return switch (configured) {
      true => context.tr('已保存', 'Saved'),
      false => context.tr('未配置', 'Not configured'),
      null => context.tr('检查中', 'Checking'),
    };
  }

  /// 带 chevron 箭头的导航 ListTile（iOS 设置页风格）。
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: context.appTextSecondary),
        title: Text(
          title,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: context.appTextSecondary),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: context.appTextSecondary),
        title: Text(
          title,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ),
        trailing: onTap == null
            ? null
            : Icon(Icons.chevron_right, color: context.appTextSecondary),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Icon(icon, color: context.appTextSecondary),
        title: Text(
          title,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ),
        activeThumbColor: accent,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _setFadeInEnabled(bool enabled) async {
    await ref
        .read(appDatabaseProvider)
        .setSetting('audio_fade_in_enabled', enabled.toString());
    if (!mounted) return;
    setState(() => _fadeInEnabled = enabled);
  }

  void _showSleepTimerSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.appSurface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '定时关闭',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final minutes in const [15, 30, 60])
                      ActionChip(
                        avatar: Icon(Icons.timer_outlined, size: 18),
                        label: Text('$minutes 分钟'),
                        onPressed: () => _scheduleSleepDuration(
                          context,
                          Duration(minutes: minutes),
                        ),
                      ),
                    ActionChip(
                      avatar: Icon(Icons.flag_outlined, size: 18),
                      label: Text('本章结束'),
                      onPressed: () => _scheduleSleepChapterEnd(context),
                    ),
                    ActionChip(
                      avatar: Icon(Icons.close, size: 18),
                      label: Text('关闭'),
                      onPressed: () => _cancelSleepTimer(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scheduleSleepDuration(
    BuildContext sheetContext,
    Duration duration,
  ) async {
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await ref
        .read(sleepTimerServiceProvider)
        .scheduleDuration(duration, handler);
    if (!mounted) return;
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
  }

  Future<void> _scheduleSleepChapterEnd(BuildContext sheetContext) async {
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await ref.read(sleepTimerServiceProvider).scheduleChapterEnd(handler);
    if (!mounted) return;
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
  }

  Future<void> _cancelSleepTimer(BuildContext sheetContext) async {
    await ref.read(sleepTimerServiceProvider).cancel();
    if (!mounted) return;
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
  }

  /// 底部版本信息。
  Widget _buildVersionFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          'Lumina $_appVersion',
          style: TextStyle(color: context.appTextSecondary, fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLocalModel(LocalTtsModelManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${manager.displayName}？'),
        content: Text('删除后，对应的本地 TTS 需要重新下载模型才能使用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('删除'),
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
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.appSurface,
      builder: (context) {
        final accent = Theme.of(context).colorScheme.primary;
        return StreamBuilder<KokoroModelStatus>(
          stream: manager.statusStream,
          initialData: initialStatus,
          builder: (context, snapshot) {
            final status = snapshot.data ?? manager.status;
            final installed = status.isInstalled;
            final downloading = status.isDownloading;
            final hasPartialDownload = !installed && status.downloadedBytes > 0;

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
                            style: TextStyle(
                              color: context.appTextPrimary,
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
                              : hasPartialDownload
                              ? '继续下载'
                              : '下载模型',
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: downloading
                                  ? context.appSurfaceHighlight
                                  : accent,
                              foregroundColor: downloading
                                  ? context.appTextPrimary
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
                            icon: Icon(Icons.delete_outline),
                            color: installed
                                ? context.appTextSecondary
                                : hasPartialDownload
                                ? context.appTextSecondary
                                : context.appSurfaceHighlight,
                            onPressed:
                                downloading ||
                                    (!installed && !hasPartialDownload)
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
                    if (downloading || hasPartialDownload) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: status.progress <= 0 ? null : status.progress,
                        minHeight: 4,
                        backgroundColor: context.appSurfaceHighlight,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(status.progress * 100).clamp(0, 100).toStringAsFixed(1)}% · '
                        '${_formatBytes(status.downloadedBytes)} / ${_formatBytes(status.totalBytes)}',
                        style: TextStyle(
                          color: context.appTextSecondary,
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
    final provider = ref
        .read(providerRegistryProvider)
        .get(MinimaxTtsProvider.idValue);
    if (provider is! MinimaxTtsProvider) return;
    _minimaxKeyController.clear();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (_) => _ApiKeyDetailsSheet(
        title: 'MiniMax API Key',
        description: '用于 MiniMax 语音合成、音频克隆和描述生成。密钥会保存在系统安全存储中。',
        controller: _minimaxKeyController,
        configured: _miniMaxApiKeyConfigured ?? false,
        capability: '预置音色、音频克隆、描述生成',
        onSave: provider.setApiKey,
        onTest: provider.validate,
        onConfiguredChanged: (value) {
          if (mounted) setState(() => _miniMaxApiKeyConfigured = value);
        },
      ),
    );
  }

  void _showFishApiDetails() {
    final provider = ref
        .read(providerRegistryProvider)
        .get(FishAudioApiTtsProvider.idValue);
    if (provider is! FishAudioApiTtsProvider) return;
    _fishApiKeyController.clear();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (_) => _ApiKeyDetailsSheet(
        title: 'Fish Audio API Key',
        description: '用于 Fish Audio 云端 TTS。密钥会保存在系统安全存储中。',
        controller: _fishApiKeyController,
        configured: _fishApiKeyConfigured ?? false,
        capability: '默认声音 / 已训练 Fish voice model',
        model: FishAudioApiTtsProvider.model,
        generationProfile: _fishGenerationProfile,
        onGenerationProfileChanged: _setFishGenerationProfile,
        onSave: provider.setApiKey,
        onTest: provider.validate,
        onConfiguredChanged: (value) {
          if (mounted) setState(() => _fishApiKeyConfigured = value);
        },
      ),
    );
  }

  Future<void> _setFishGenerationProfile(
    FishAudioGenerationProfile profile,
  ) async {
    final provider = ref
        .read(providerRegistryProvider)
        .get(FishAudioApiTtsProvider.idValue);
    if (provider is! FishAudioApiTtsProvider) return;
    await provider.setGenerationProfile(profile);
    if (!mounted) return;
    setState(() => _fishGenerationProfile = profile);
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
          Icon(icon, size: 20, color: context.appTextSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.appTextPrimary, fontSize: 13),
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

class _ApiKeyDetailsSheet extends StatefulWidget {
  final String title;
  final String description;
  final TextEditingController controller;
  final bool configured;
  final String capability;
  final String? model;
  final FishAudioGenerationProfile? generationProfile;
  final Future<void> Function(FishAudioGenerationProfile)?
  onGenerationProfileChanged;
  final Future<void> Function(String) onSave;
  final Future<bool> Function() onTest;
  final ValueChanged<bool> onConfiguredChanged;

  const _ApiKeyDetailsSheet({
    required this.title,
    required this.description,
    required this.controller,
    required this.configured,
    required this.capability,
    required this.onSave,
    required this.onTest,
    required this.onConfiguredChanged,
    this.model,
    this.generationProfile,
    this.onGenerationProfileChanged,
  });

  @override
  State<_ApiKeyDetailsSheet> createState() => _ApiKeyDetailsSheetState();
}

class _ApiKeyDetailsSheetState extends State<_ApiKeyDetailsSheet> {
  late bool _configured;
  late FishAudioGenerationProfile? _generationProfile;
  String? _feedback;
  bool _feedbackIsError = false;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _configured = widget.configured;
    _generationProfile = widget.generationProfile;
  }

  Future<void> _save() async {
    final key = widget.controller.text.trim();
    if (key.isEmpty && !_configured) {
      _setFeedback('请输入 API Key。', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (key.isNotEmpty) {
        await widget.onSave(key);
        widget.controller.clear();
        _configured = true;
        widget.onConfiguredChanged(true);
      }
      _setFeedback(key.isEmpty ? '配置已保存。' : 'API Key 和配置已保存。');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Settings',
        '保存 ${widget.title} 失败',
        error: error,
        stackTrace: stackTrace,
      );
      _setFeedback('保存失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (!_configured) {
      _setFeedback('请先保存 API Key。', isError: true);
      return;
    }
    setState(() => _testing = true);
    try {
      final connected = await widget.onTest();
      _setFeedback(connected ? '连接正常。' : '连接失败，请检查密钥和网络。', isError: !connected);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Settings',
        '测试 ${widget.title} 连接失败',
        error: error,
        stackTrace: stackTrace,
      );
      _setFeedback('连接失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _setFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _feedbackIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final statusColor = _configured ? accent : context.appTextSecondary;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
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
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '保存 API Key',
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.save_outlined),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '测试连接',
                    child: IconButton(
                      onPressed: _testing ? null : _test,
                      icon: _testing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.wifi_tethering_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    _configured ? Icons.check_circle : Icons.info_outline,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _configured ? 'API Key 已配置' : 'API Key 未配置',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: widget.controller,
                obscureText: true,
                style: TextStyle(color: context.appTextPrimary, fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.appBackground,
                  hintText: _configured ? '输入新密钥以替换当前密钥' : '在这里填入 API Key',
                  prefixIcon: Icon(Icons.key_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 12),
                _InlineFeedback(message: _feedback!, isError: _feedbackIsError),
              ],
              if (_generationProfile != null) ...[
                const SizedBox(height: 18),
                Text(
                  '生成模式',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<FishAudioGenerationProfile>(
                    segments: const [
                      ButtonSegment(
                        value: FishAudioGenerationProfile.fast,
                        icon: Icon(Icons.bolt_outlined),
                        label: Text('快速'),
                      ),
                      ButtonSegment(
                        value: FishAudioGenerationProfile.quality,
                        icon: Icon(Icons.high_quality_outlined),
                        label: Text('高质量'),
                      ),
                    ],
                    selected: {_generationProfile!},
                    onSelectionChanged: (selection) async {
                      final profile = selection.first;
                      setState(() => _generationProfile = profile);
                      await widget.onGenerationProfileChanged?.call(profile);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _generationProfile == FishAudioGenerationProfile.fast
                      ? '3 个并发请求 · 24 kHz · 低延迟'
                      : '单请求生成 · 44.1 kHz · 平衡质量',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (widget.model != null)
                _InfoRow(
                  icon: Icons.psychology_outlined,
                  label: '模型',
                  value: widget.model!,
                ),
              const _InfoRow(
                icon: Icons.lock_outline,
                label: '存储',
                value: 'Keychain / 本地回退',
              ),
              _InfoRow(
                icon: Icons.auto_awesome,
                label: '能力',
                value: widget.capability,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineFeedback extends StatelessWidget {
  final String message;
  final bool isError;

  const _InlineFeedback({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = isError ? Colors.redAccent : accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.appTextSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.appTextPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalModelInlineStatus extends StatelessWidget {
  final KokoroModelStatus status;

  const _LocalModelInlineStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = switch (status.state) {
      KokoroModelInstallState.installed => accent,
      KokoroModelInstallState.failed => Colors.redAccent,
      KokoroModelInstallState.downloading => accent,
      _ => context.appTextSecondary,
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
