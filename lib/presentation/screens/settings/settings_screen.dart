import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
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

  @override
  void initState() {
    super.initState();
    _loadPlaybackSettings();
  }

  Future<void> _loadPlaybackSettings() async {
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
          AppSectionHeader(title: context.tr('AI 服务', 'AI Services')),
          SettingsGroup(
            children: [
              tts.when(
                loading: () => _loadingServiceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.record_voice_over_outlined,
                  title: context.tr('文本转语音', 'Text to Speech'),
                ),
                error: (error, _) => _errorServiceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.record_voice_over_outlined,
                  title: context.tr('文本转语音', 'Text to Speech'),
                  onTap: () => ref.invalidate(ttsSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('tts-service-settings'),
                  icon: Icons.record_voice_over_outlined,
                  title: context.tr('文本转语音', 'Text to Speech'),
                  provider:
                      state.providerName ?? context.tr('未选择服务', 'No provider'),
                  selection: state.voiceName ?? context.tr('未选择音色', 'No voice'),
                  readiness: state.readiness,
                  onTap: () => _push(const TtsServiceScreen()),
                ),
              ),
              asr.when(
                loading: () => _loadingServiceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.subtitles_outlined,
                  title: context.tr('语音转文字', 'Speech to Text'),
                ),
                error: (error, _) => _errorServiceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.subtitles_outlined,
                  title: context.tr('语音转文字', 'Speech to Text'),
                  onTap: () => ref.invalidate(asrSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('asr-service-settings'),
                  icon: Icons.subtitles_outlined,
                  title: context.tr('语音转文字', 'Speech to Text'),
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
                  title: context.tr('词典解释', 'Dictionary Explanation'),
                ),
                error: (error, _) => _errorServiceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.auto_awesome_outlined,
                  title: context.tr('词典解释', 'Dictionary Explanation'),
                  onTap: () => ref.invalidate(llmSettingsControllerProvider),
                ),
                data: (state) => _serviceRow(
                  key: const ValueKey('llm-provider-settings'),
                  icon: Icons.auto_awesome_outlined,
                  title: context.tr('词典解释', 'Dictionary Explanation'),
                  provider:
                      state.providerName ?? context.tr('未选择服务', 'No provider'),
                  selection: state.modelId ?? context.tr('未选择模型', 'No model'),
                  readiness: state.readiness,
                  onTap: () =>
                      _push(const DictionaryExplanationServiceScreen()),
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
}
