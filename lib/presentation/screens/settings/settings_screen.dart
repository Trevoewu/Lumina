import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../../core/appearance.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../tts/provider_registry.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/design_system/app_surface.dart';
import '../../widgets/design_system/settings_components.dart';
import 'appearance_screen.dart';
import 'asr_service_screen.dart';
import 'cache_management_screen.dart';
import 'dictionary_explanation_service_screen.dart';
import 'logs_screen.dart';
import 'tts_service_screen.dart';

const String _appVersion = '1.0.0+1';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _languageMenuKey = GlobalKey<PopupMenuButtonState<AppLanguage>>();
  final _themeMenuKey = GlobalKey<PopupMenuButtonState<AppThemePreference>>();
  bool _fadeInEnabled = true;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _loadPlaybackSettings();
  }

  Future<void> _loadPlaybackSettings() async {
    await ref.read(appPreferencesProvider.notifier).load();
    final value = await ref
        .read(appDatabaseProvider)
        .getSetting('audio_fade_in_enabled');
    if (mounted) setState(() => _fadeInEnabled = value != 'false');
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final preferences = ref.watch(appPreferencesProvider);
    final tts = ref.watch(ttsSettingsControllerProvider);
    final asr = ref.watch(asrSettingsControllerProvider);
    final llm = ref.watch(llmSettingsControllerProvider);
    return CollapsingPageScaffold(
      title: context.tr('设置', 'Settings'),
      showBackButton: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
        children: [
          AppSectionHeader(title: context.tr('通用', 'General')),
          SettingsGroup(
            children: [
              _languageRow(preferences.language),
              _themeRow(preferences.theme),
              SettingValueRow(
                icon: Icons.text_fields,
                title: context.tr('阅读外观', 'Reading appearance'),
                subtitle: context.tr(
                  '字体、字号与阅读排版',
                  'Font, scale, and reading type',
                ),
                onTap: () => _push(const AppearanceScreen()),
              ),
            ],
          ),
          AppSectionHeader(title: context.tr('增强功能', 'Enhanced Features')),
          AppSurface(
            key: const ValueKey('enhanced-features-intro'),
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.48),
            padding: EdgeInsets.all(design.spaceLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: design.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('按需开启', 'Set up when needed'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: design.spaceXs),
                      Text(
                        context.tr(
                          '阅读与播放无需额外设置。需要时再开启字幕、AI 助手和语音朗读。',
                          'Reading and playback work now. Set up transcripts, AI, and narration only when you need them.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: design.spaceMd),
          SettingsGroup(
            children: [
              asr.when(
                loading: () => _loadingServiceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.subtitles_outlined,
                  title: context.tr('Podcast 字幕', 'Podcast Transcripts'),
                ),
                error: (error, _) => _errorServiceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.subtitles_outlined,
                  title: context.tr('Podcast 字幕', 'Podcast Transcripts'),
                  onTap: () => ref.invalidate(asrSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.subtitles_outlined,
                  title: context.tr('Podcast 字幕', 'Podcast Transcripts'),
                  provider: state.providerName,
                  selection: state.modelName,
                  readiness: state.readiness,
                  onTap: () => _push(const AsrServiceScreen()),
                ),
              ),
              llm.when(
                loading: () => _loadingServiceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.auto_awesome_outlined,
                  title: context.tr('AI 模型', 'AI Model'),
                ),
                error: (error, _) => _errorServiceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.auto_awesome_outlined,
                  title: context.tr('AI 模型', 'AI Model'),
                  onTap: () => ref.invalidate(llmSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.auto_awesome_outlined,
                  title: context.tr('AI 模型', 'AI Model'),
                  provider:
                      state.providerName ?? context.tr('未选择服务', 'No provider'),
                  selection: state.modelId ?? context.tr('未选择模型', 'No model'),
                  readiness: state.readiness,
                  onTap: () =>
                      _push(const DictionaryExplanationServiceScreen()),
                ),
              ),
              tts.when(
                loading: () => _loadingServiceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.record_voice_over_outlined,
                  title: context.tr('语音朗读', 'Voice Narration'),
                ),
                error: (error, _) => _errorServiceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.record_voice_over_outlined,
                  title: context.tr('语音朗读', 'Voice Narration'),
                  onTap: () => ref.invalidate(ttsSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.record_voice_over_outlined,
                  title: context.tr('语音朗读', 'Voice Narration'),
                  provider:
                      state.providerName ?? context.tr('未选择服务', 'No provider'),
                  selection:
                      [
                        state.modelName,
                        state.voiceName,
                      ].whereType<String>().join(' · ').isEmpty
                      ? context.tr('尚未完成设置', 'Setup incomplete')
                      : [
                          state.modelName,
                          state.voiceName,
                        ].whereType<String>().join(' · '),
                  readiness: state.readiness,
                  onTap: () => _push(const TtsServiceScreen()),
                ),
              ),
            ],
          ),
          AppSectionHeader(title: context.tr('播放', 'Playback')),
          SettingsGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: Text(context.tr('段落淡入', 'Paragraph fade-in')),
                subtitle: Text(
                  context.tr(
                    '减少段落切换时的突兀感',
                    'Smooth generated paragraph transitions',
                  ),
                ),
                value: _fadeInEnabled,
                onChanged: _setFadeInEnabled,
              ),
              SettingValueRow(
                rowKey: const ValueKey('reading-scroll-speed-settings'),
                icon: Icons.swap_vert_rounded,
                title: context.tr('文字滚动速度', 'Text scroll speed'),
                subtitle: context.tr(
                  '控制同步正文自动定位动画的快慢',
                  'Control how quickly synchronized text moves into view',
                ),
                value: _readingScrollSpeedLabel(preferences.readingScrollSpeed),
                onTap: _showReadingScrollSpeedSheet,
              ),
              SettingValueRow(
                rowKey: const ValueKey('lyric-sweep-settings'),
                icon: Icons.auto_awesome_outlined,
                title: context.tr('歌词渐进高亮', 'Lyric sweep highlight'),
                trailing: Switch(
                  value: preferences.lyricSweepEnabled,
                  onChanged: ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricSweepEnabled,
                ),
                onTap: () => ref
                    .read(appPreferencesProvider.notifier)
                    .setLyricSweepEnabled(!preferences.lyricSweepEnabled),
              ),
              StreamBuilder(
                stream: ref.watch(sleepTimerServiceProvider).stream,
                initialData: ref.watch(sleepTimerServiceProvider).state,
                builder: (context, snapshot) => SettingValueRow(
                  icon: Icons.bedtime_outlined,
                  title: context.tr('定时关闭', 'Sleep timer'),
                  value: snapshot.data?.label ?? context.tr('关闭', 'Off'),
                  onTap: _showSleepTimerSheet,
                ),
              ),
            ],
          ),
          AppSectionHeader(title: context.tr('存储', 'Storage')),
          SettingsGroup(
            children: [
              SettingValueRow(
                icon: Icons.cleaning_services_outlined,
                title: context.tr('音频缓存', 'Audio cache'),
                subtitle: context.tr(
                  '管理书籍、Podcast 音频与字幕',
                  'Manage books, podcast audio, and transcripts',
                ),
                onTap: () => _push(const CacheManagementScreen()),
              ),
            ],
          ),
          AppSectionHeader(title: context.tr('支持', 'Support')),
          SettingsGroup(
            children: [
              SettingValueRow(
                icon: Icons.receipt_long_outlined,
                title: context.tr('日志', 'Logs'),
                onTap: () => _push(const LogsScreen()),
              ),
            ],
          ),
          AppSectionHeader(title: context.tr('高级', 'Advanced')),
          SettingsGroup(
            children: [
              SettingValueRow(
                rowKey: const ValueKey('reset-app-settings'),
                icon: Icons.restart_alt,
                title: context.tr('恢复初始设置', 'Restore initial settings'),
                subtitle: context.tr(
                  '重置偏好与服务配置，保留书库、进度和下载',
                  'Reset preferences and service configuration while keeping your library, progress, and downloads',
                ),
                trailing: _resetting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _resetting ? null : _confirmResetAppSettings,
              ),
            ],
          ),
          SizedBox(height: design.spaceXl),
          Center(
            child: Text(
              'Lumina $_appVersion',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageRow(AppLanguage selected) => SettingValueRow(
    rowKey: const ValueKey('language-selector'),
    icon: Icons.language,
    title: context.tr('语言', 'Language'),
    onTap: () => _languageMenuKey.currentState?.showButtonMenu(),
    trailing: PopupMenuButton<AppLanguage>(
      key: _languageMenuKey,
      tooltip: context.tr('选择语言', 'Choose language'),
      position: PopupMenuPosition.under,
      color: Theme.of(context).colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.appDesign.radiusSmall),
      ),
      onSelected: ref.read(appPreferencesProvider.notifier).setLanguage,
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
      child: _menuValue(_languageLabel(selected)),
    ),
  );

  Widget _themeRow(AppThemePreference selected) => SettingValueRow(
    rowKey: const ValueKey('theme-selector'),
    icon: Icons.brightness_6_outlined,
    title: context.tr('主题', 'Theme'),
    onTap: () => _themeMenuKey.currentState?.showButtonMenu(),
    trailing: PopupMenuButton<AppThemePreference>(
      key: _themeMenuKey,
      tooltip: context.tr('选择主题', 'Choose theme'),
      position: PopupMenuPosition.under,
      color: Theme.of(context).colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.appDesign.radiusSmall),
      ),
      onSelected: ref.read(appPreferencesProvider.notifier).setTheme,
      itemBuilder: (_) => [
        for (final theme in AppThemePreference.values)
          PopupMenuItem(
            value: theme,
            child: _popupChoice(
              label: _themeLabel(theme),
              selected: theme == selected,
            ),
          ),
      ],
      child: _menuValue(_themeLabel(selected)),
    ),
  );

  Widget _menuValue(String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appDesign.spaceSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(width: context.appDesign.spaceXs),
          Icon(Icons.unfold_more, color: scheme.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }

  Widget _popupChoice({required String label, required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: context.appDesign.spaceXl,
          child: selected
              ? Icon(Icons.check, color: scheme.primary)
              : const SizedBox.shrink(),
        ),
        SizedBox(width: context.appDesign.spaceSm),
        Expanded(child: Text(label)),
      ],
    );
  }

  String _languageLabel(AppLanguage value) => switch (value) {
    AppLanguage.system => context.tr('跟随系统', 'System'),
    AppLanguage.zhHans => '简体中文',
    AppLanguage.english => 'English',
  };

  String _themeLabel(AppThemePreference value) => switch (value) {
    AppThemePreference.system => context.tr('跟随系统', 'System'),
    AppThemePreference.light => context.tr('浅色', 'Light'),
    AppThemePreference.dark => context.tr('深色', 'Dark'),
  };

  Widget _serviceRow({
    required Key key,
    required IconData icon,
    required String title,
    required String provider,
    required String selection,
    required ServiceReadiness readiness,
    required VoidCallback onTap,
  }) {
    final status = _readinessPresentation(readiness);
    return SettingValueRow(
      rowKey: key,
      icon: icon,
      title: title,
      subtitle: '$provider · $selection',
      value: status.label,
      valueColor: status.color,
      onTap: onTap,
    );
  }

  Widget _loadingServiceRow({
    required Key key,
    required IconData icon,
    required String title,
  }) {
    final status = _readinessPresentation(ServiceReadiness.loading);
    return SettingValueRow(
      rowKey: key,
      icon: icon,
      title: title,
      value: status.label,
      valueColor: status.color,
    );
  }

  Widget _errorServiceRow({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final status = _readinessPresentation(ServiceReadiness.error);
    return SettingValueRow(
      rowKey: key,
      icon: icon,
      title: title,
      subtitle: context.tr('点按重试', 'Tap to retry'),
      value: status.label,
      valueColor: status.color,
      onTap: onTap,
    );
  }

  ({String label, Color color}) _readinessPresentation(
    ServiceReadiness readiness,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return switch (readiness) {
      ServiceReadiness.loading => (
        label: context.tr('检查中', 'Checking'),
        color: scheme.onSurfaceVariant,
      ),
      ServiceReadiness.setupRequired => (
        label: context.tr('设置', 'Setup'),
        color: scheme.tertiary,
      ),
      ServiceReadiness.ready => (
        label: context.tr('就绪', 'Ready'),
        color: scheme.primary,
      ),
      ServiceReadiness.error => (
        label: context.tr('注意', 'Attention'),
        color: scheme.error,
      ),
    };
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    ref.invalidate(ttsSettingsControllerProvider);
    ref.invalidate(asrSettingsControllerProvider);
    ref.invalidate(llmSettingsControllerProvider);
  }

  Future<void> _setFadeInEnabled(bool enabled) async {
    await ref
        .read(appDatabaseProvider)
        .setSetting('audio_fade_in_enabled', '$enabled');
    if (mounted) setState(() => _fadeInEnabled = enabled);
  }

  String _readingScrollSpeedLabel(double speed) {
    return '${speed.toStringAsFixed(1)}×';
  }

  void _showReadingScrollSpeedSheet() {
    var value = ref.read(appPreferencesProvider).readingScrollSpeed;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final scheme = Theme.of(context).colorScheme;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.appDesign.spaceXl,
                context.appDesign.spaceXl,
                context.appDesign.spaceXl,
                context.appDesign.spaceLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('文字滚动速度', 'Text scroll speed'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: context.appDesign.spaceXs),
                  Text(
                    context.tr(
                      '速度越高，句子切换时的定位动画越快。',
                      'Higher speeds move to the next sentence faster.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: context.appDesign.spaceMd),
                  Row(
                    children: [
                      Text(
                        '0.5×',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Expanded(
                        child: Slider(
                          key: const ValueKey('reading-scroll-speed-slider'),
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          value: value,
                          label: _readingScrollSpeedLabel(value),
                          onChanged: (next) {
                            setSheetState(() => value = next);
                            ref
                                .read(appPreferencesProvider.notifier)
                                .setReadingScrollSpeed(next);
                          },
                        ),
                      ),
                      Text(
                        '2.0×',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  Center(
                    child: Text(
                      _readingScrollSpeedLabel(value),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSleepTimerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(context.appDesign.spaceXl),
          child: Wrap(
            spacing: context.appDesign.spaceSm,
            runSpacing: context.appDesign.spaceSm,
            children: [
              for (final minutes in const [15, 30, 60])
                ActionChip(
                  label: Text(context.tr('$minutes 分钟', '$minutes minutes')),
                  onPressed: () =>
                      _scheduleTimer(sheetContext, Duration(minutes: minutes)),
                ),
              ActionChip(
                label: Text(context.tr('本章结束', 'End of chapter')),
                onPressed: () async {
                  final handler = await ref.read(
                    luminaAudioHandlerProvider.future,
                  );
                  await ref
                      .read(sleepTimerServiceProvider)
                      .scheduleChapterEnd(handler);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
              ActionChip(
                label: Text(context.tr('关闭', 'Off')),
                onPressed: () async {
                  await ref.read(sleepTimerServiceProvider).cancel();
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scheduleTimer(
    BuildContext sheetContext,
    Duration duration,
  ) async {
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await ref
        .read(sleepTimerServiceProvider)
        .scheduleDuration(duration, handler);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  }

  Future<void> _confirmResetAppSettings() async {
    final continueReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('恢复初始设置？', 'Restore initial settings?')),
        content: Text(
          context.tr(
            '以下内容将恢复默认值：\n\n'
                '• 语言、主题、阅读外观和播放偏好\n'
                '• AI 与语音服务的 API Key 和 Provider 配置\n'
                '• 模型、朗读音色和字幕偏好\n\n'
                '书库、播客、阅读进度、下载内容和已下载的 Whisper 模型会保留。',
            'The following will return to their defaults:\n\n'
                '• Language, theme, reading appearance, and playback preferences\n'
                '• API keys and provider configuration for AI and voice services\n'
                '• Model, reading voice, and transcript preferences\n\n'
                'Your library, podcasts, reading progress, downloads, and downloaded Whisper model will be kept.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            key: const ValueKey('continue-reset-app-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('继续', 'Continue')),
          ),
        ],
      ),
    );
    if (continueReset != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('最后确认', 'Final confirmation')),
        content: Text(
          context.tr(
            '此操作无法撤销。重置后需要重新输入 API Key，并重新选择 Provider、AI 模型和朗读音色。\n\n'
                '确定立即恢复初始设置吗？',
            'This cannot be undone. You will need to enter API keys again and reselect providers, AI models, and reading voices.\n\n'
                'Restore the initial settings now?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('返回', 'Go back')),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset-app-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr('恢复初始设置', 'Restore settings')),
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
    );
    final failurePrefix = context.tr('恢复设置失败', 'Could not restore settings');
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
      setState(() {
        _fadeInEnabled = true;
        _resetting = false;
      });
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
