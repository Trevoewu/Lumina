import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../../core/appearance.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../services/cache_manager.dart';
import '../../../tts/provider_registry.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';
import 'appearance_screen.dart';
import 'asr_service_screen.dart';
import 'cache_management_screen.dart';
import 'dictionary_explanation_service_screen.dart';
import 'logs_screen.dart';
import 'language_settings_screen.dart';
import 'tts_service_screen.dart';

const String _appVersion = '1.0.0+1';

/// Total on-disk audio cache, surfaced as the badge on the cache row.
final settingsCacheUsageProvider = FutureProvider.autoDispose<CacheUsage>((
  ref,
) async {
  return ref.watch(cacheManagerProvider).totalUsage();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    // The screen is reachable directly (deep link, tests), so it loads the
    // stores it reads rather than assuming the app shell already did.
    ref.read(appPreferencesProvider.notifier).load();
    ref.read(appearanceControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final scheme = Theme.of(context).colorScheme;
    final preferences = ref.watch(appPreferencesProvider);
    final tts = ref.watch(ttsSettingsControllerProvider);
    final asr = ref.watch(asrSettingsControllerProvider);
    final llm = ref.watch(llmSettingsControllerProvider);

    return CollapsingPageScaffold(
      title: context.tr('设置', 'Settings', '設定'),
      showBackButton: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 22),
            child: Text(
              context.tr(
                '语言、外观与模型',
                'Language, appearance, and models',
                '言語、外観、モデル',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          SegmentedChoiceRow<AppThemePreference>(
            options: AppThemePreference.values,
            selected: preferences.theme,
            onSelected: ref.read(appPreferencesProvider.notifier).setTheme,
            labelBuilder: _themeLabel,
            iconBuilder: (theme) => switch (theme) {
              AppThemePreference.system => Icons.phone_iphone_rounded,
              AppThemePreference.light => Icons.light_mode_outlined,
              AppThemePreference.dark => Icons.dark_mode_outlined,
            },
          ),

          SettingsSectionLabel(
            title: context.tr('模型与服务', 'Models & Services', 'モデルとサービス'),
          ),
          SettingsGroup(
            children: [
              asr.when(
                loading: () => _serviceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.mic_none_rounded,
                  title: _asrTitle,
                  readiness: ServiceReadiness.loading,
                ),
                error: (error, _) => _serviceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.mic_none_rounded,
                  title: _asrTitle,
                  subtitle: _retryHint,
                  readiness: ServiceReadiness.error,
                  onTap: () => ref.invalidate(asrSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.mic_none_rounded,
                  title: _asrTitle,
                  subtitle:
                      '${context.tr('播客转录', 'Podcast transcripts', 'Podcast文字起こし')} · ${state.modelName}',
                  readiness: state.readiness,
                  onTap: () => _push(const AsrServiceScreen()),
                ),
              ),
              llm.when(
                loading: () => _serviceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.science_outlined,
                  title: _aiTitle,
                  readiness: ServiceReadiness.loading,
                ),
                error: (error, _) => _serviceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.science_outlined,
                  title: _aiTitle,
                  subtitle: _retryHint,
                  readiness: ServiceReadiness.error,
                  onTap: () => ref.invalidate(llmSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.science_outlined,
                  title: _aiTitle,
                  subtitle: _joinDetail([state.providerName, state.modelId]),
                  readiness: state.readiness,
                  onTap: () =>
                      _push(const DictionaryExplanationServiceScreen()),
                ),
              ),
              tts.when(
                loading: () => _serviceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.graphic_eq_rounded,
                  title: _ttsTitle,
                  readiness: ServiceReadiness.loading,
                ),
                error: (error, _) => _serviceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.graphic_eq_rounded,
                  title: _ttsTitle,
                  subtitle: _retryHint,
                  readiness: ServiceReadiness.error,
                  onTap: () => ref.invalidate(ttsSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.graphic_eq_rounded,
                  title: _ttsTitle,
                  subtitle: _joinDetail([
                    state.providerName,
                    state.voiceName ?? state.modelName,
                  ]),
                  readiness: state.readiness,
                  onTap: () => _push(const TtsServiceScreen()),
                ),
              ),
            ],
          ),

          SettingsSectionLabel(
            title: context.tr('存储与诊断', 'Storage & Diagnostics', 'ストレージと診断'),
          ),
          SettingsGroup(
            children: [
              SettingValueRow(
                rowKey: const ValueKey('cache-settings'),
                icon: Icons.storage_rounded,
                title: context.tr('缓存管理', 'Cache Management', 'キャッシュ管理'),
                subtitle: context.tr(
                  '按书籍与播客分别清理',
                  'Clear by book or podcast',
                  '書籍とPodcastごとに整理',
                ),
                badge: ref
                    .watch(settingsCacheUsageProvider)
                    .maybeWhen(
                      data: (usage) => usage.humanReadable,
                      orElse: () => null,
                    ),
                onTap: () async {
                  await _push(const CacheManagementScreen());
                  ref.invalidate(settingsCacheUsageProvider);
                },
              ),
              SettingValueRow(
                rowKey: const ValueKey('logs-settings'),
                icon: Icons.article_outlined,
                title: context.tr('日志', 'Logs', 'ログ'),
                subtitle: context.tr(
                  '转录、合成与请求记录',
                  'Transcription, synthesis, and request records',
                  '文字起こし・合成・リクエストの記録',
                ),
                onTap: () => _push(const LogsScreen()),
              ),
            ],
          ),

          SettingsSectionLabel(title: context.tr('更多', 'More', 'その他')),
          SettingsGroup(
            children: [
              SettingValueRow(
                rowKey: const ValueKey('appearance-settings'),
                icon: Icons.palette_outlined,
                title: context.tr('外观细节', 'Appearance', '外観の詳細'),
                subtitle: _appearanceSummary(),
                onTap: () => _push(const AppearanceScreen()),
              ),
              SettingValueRow(
                rowKey: const ValueKey('language-selector'),
                icon: Icons.language,
                title: context.tr('语言', 'Language', '言語'),
                subtitle: context.tr(
                  '分别设置 UI 与 AI 服务语言',
                  'Set UI and AI service languages separately',
                  'UIとAIサービスの言語を個別に設定',
                ),
                onTap: () => _push(const LanguageSettingsScreen()),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: SettingsDangerButton(
              key: const ValueKey('reset-app-settings'),
              label: context.tr(
                '恢复默认设置',
                'Restore initial settings',
                '初期設定に戻す',
              ),
              busy: _resetting,
              onPressed: _confirmResetAppSettings,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Lumina $_appVersion · ${context.tr('设备端处理', 'On-device processing', '端末内で処理')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _asrTitle =>
      context.tr('语音识别 (ASR)', 'Speech Recognition (ASR)', '音声認識 (ASR)');

  String get _aiTitle => context.tr('AI 模型', 'AI Model', 'AIモデル');

  String get _ttsTitle =>
      context.tr('语音合成 (TTS)', 'Voice Synthesis (TTS)', '音声合成 (TTS)');

  String get _retryHint => context.tr('点按重试', 'Tap to retry', 'タップして再試行');

  /// Joins the provider/selection detail line, falling back to a "not set up"
  /// hint when a service has not been configured yet.
  String _joinDetail(List<String?> parts) {
    final detail = parts
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();
    if (detail.isEmpty) {
      return context.tr('未配置', 'Not set up', '未設定');
    }
    return detail.join(' · ');
  }

  Widget _serviceRow({
    required Key key,
    required IconData icon,
    required String title,
    String? subtitle,
    required ServiceReadiness readiness,
    VoidCallback? onTap,
  }) {
    return SettingValueRow(
      rowKey: key,
      icon: icon,
      title: title,
      subtitle: subtitle,
      badge: _readinessLabel(readiness),
      badgeTinted: readiness == ServiceReadiness.ready,
      onTap: onTap,
    );
  }

  String _readinessLabel(ServiceReadiness readiness) => switch (readiness) {
    ServiceReadiness.loading => context.tr('检查中', 'Checking', '確認中'),
    ServiceReadiness.setupRequired => context.tr('设置', 'Setup', '設定'),
    ServiceReadiness.ready => context.tr('就绪', 'Ready', '準備完了'),
    ServiceReadiness.error => context.tr('注意', 'Attention', '注意'),
  };

  String _appearanceSummary() {
    final appearance = ref.watch(appearanceControllerProvider);
    final percent = (appearance.fontScale * 100).round();
    final icon = context.tr('图标', 'Icon', 'アイコン');
    return '${appearance.fontOption.label} · $percent% · $icon';
  }

  String _themeLabel(AppThemePreference value) => switch (value) {
    AppThemePreference.system => context.tr('系统', 'System', 'システム'),
    AppThemePreference.light => context.tr('浅色', 'Light', 'ライト'),
    AppThemePreference.dark => context.tr('深色', 'Dark', 'ダーク'),
  };

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    ref.invalidate(ttsSettingsControllerProvider);
    ref.invalidate(asrSettingsControllerProvider);
    ref.invalidate(llmSettingsControllerProvider);
  }

  Future<void> _confirmResetAppSettings() async {
    final continueReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr('恢复初始设置？', 'Restore initial settings?', '初期設定に戻しますか？'),
        ),
        content: Text(
          context.tr(
            '以下内容将恢复默认值：\n\n'
                '• UI 与 AI 服务语言、主题和阅读外观\n'
                '• AI 与语音服务的 API Key 和 Provider 配置\n'
                '• 模型、朗读音色和字幕偏好\n\n'
                '书库、播客、阅读进度、下载内容和已下载的 Whisper 模型会保留。',
            'The following will return to their defaults:\n\n'
                '• UI and AI service languages, theme, and reading appearance\n'
                '• API keys and provider configuration for AI and voice services\n'
                '• Model, reading voice, and transcript preferences\n\n'
                'Your library, podcasts, reading progress, downloads, and downloaded Whisper model will be kept.',
            '次の設定がデフォルトに戻ります：\n\n• UI・AIサービス言語、テーマ、読書表示\n• AI・音声サービスのAPIキーとプロバイダー設定\n• モデル、読み上げ音声、文字起こし設定\n\nライブラリ、Podcast、読書進捗、ダウンロード、Whisperモデルは保持されます。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('continue-reset-app-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('继续', 'Continue', '続行')),
          ),
        ],
      ),
    );
    if (continueReset != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('最后确认', 'Final confirmation', '最終確認')),
        content: Text(
          context.tr(
            '此操作无法撤销。重置后需要重新输入 API Key，并重新选择 Provider、AI 模型和朗读音色。\n\n'
                '确定立即恢复初始设置吗？',
            'This cannot be undone. You will need to enter API keys again and reselect providers, AI models, and reading voices.\n\n'
                'Restore the initial settings now?',
            'この操作は取り消せません。リセット後はAPIキーを入力し、プロバイダー、AIモデル、読み上げ音声を再選択してください。\n\n今すぐ初期設定に戻しますか？',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('返回', 'Go back', '戻る')),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset-app-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr('恢复初始设置', 'Restore settings', '初期設定に戻す')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _resetAppSettings();
  }

  Future<void> _resetAppSettings() async {
    final successMessage = context.tr(
      '已恢复初始设置。书库、进度和下载内容已保留。',
      'Initial settings restored. Your library, progress, and downloads were kept.',
      '初期設定に戻しました。ライブラリ、進捗、ダウンロードは保持されています。',
    );
    final failurePrefix = context.tr(
      '恢复设置失败',
      'Could not restore settings',
      '設定を戻せませんでした',
    );
    setState(() => _resetting = true);
    try {
      await ref.read(appSettingsResetServiceProvider).reset();
      await ref.read(activeTtsProviderIdProvider.notifier).reset();
      await ref.read(appPreferencesProvider.notifier).reset();
      await ref.read(appearanceControllerProvider.notifier).reset();
      await ref.read(sleepTimerServiceProvider).cancel();
      ref.invalidate(ttsProviderConfigurationStatusProvider);
      ref.invalidate(ttsSettingsControllerProvider);
      ref.invalidate(asrSettingsControllerProvider);
      ref.invalidate(llmSettingsControllerProvider);
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failurePrefix: $error')));
    }
  }
}
