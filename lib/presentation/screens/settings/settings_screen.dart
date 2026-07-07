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
          tts.when(
            loading: () => _loadingServiceCard(
              key: const ValueKey('tts-service-settings'),
              icon: Icons.record_voice_over_outlined,
              title: context.tr('文本转语音', 'Text to Speech'),
            ),
            error: (error, _) => _errorServiceCard(
              key: const ValueKey('tts-service-settings'),
              icon: Icons.record_voice_over_outlined,
              title: context.tr('文本转语音', 'Text to Speech'),
              error: error,
              onTap: () => ref.invalidate(ttsSettingsControllerProvider),
            ),
            data: (state) => ServiceStatusCard(
              cardKey: const ValueKey('tts-service-settings'),
              icon: Icons.record_voice_over_outlined,
              title: context.tr('文本转语音', 'Text to Speech'),
              provider:
                  state.providerName ?? context.tr('未选择服务', 'No provider'),
              selection: state.voiceName ?? context.tr('未选择音色', 'No voice'),
              readiness: state.readiness,
              onTap: () => _push(const TtsServiceScreen()),
            ),
          ),
          SizedBox(height: design.spaceMd),
          llm.when(
            loading: () => _loadingServiceCard(
              key: const ValueKey('llm-provider-settings'),
              icon: Icons.auto_awesome_outlined,
              title: context.tr('词典解释', 'Dictionary Explanation'),
            ),
            error: (error, _) => _errorServiceCard(
              key: const ValueKey('llm-provider-settings'),
              icon: Icons.auto_awesome_outlined,
              title: context.tr('词典解释', 'Dictionary Explanation'),
              error: error,
              onTap: () => ref.invalidate(llmSettingsControllerProvider),
            ),
            data: (state) => ServiceStatusCard(
              cardKey: const ValueKey('llm-provider-settings'),
              icon: Icons.auto_awesome_outlined,
              title: context.tr('词典解释', 'Dictionary Explanation'),
              provider:
                  state.providerName ?? context.tr('未选择服务', 'No provider'),
              selection: state.modelId ?? context.tr('未选择模型', 'No model'),
              readiness: state.readiness,
              onTap: () => _push(const DictionaryExplanationServiceScreen()),
            ),
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
                  '按书、章节或全部清理',
                  'Clear by book, chapter, or all',
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

  Widget _languageRow(AppLanguage selected) => PopupMenuButton<AppLanguage>(
    key: const ValueKey('language-selector'),
    onSelected: ref.read(appPreferencesProvider.notifier).setLanguage,
    itemBuilder: (_) => [
      for (final language in AppLanguage.values)
        PopupMenuItem(value: language, child: Text(_languageLabel(language))),
    ],
    child: SettingValueRow(
      icon: Icons.language,
      title: context.tr('语言', 'Language'),
      value: _languageLabel(selected),
    ),
  );

  Widget _themeRow(AppThemePreference selected) =>
      PopupMenuButton<AppThemePreference>(
        key: const ValueKey('theme-selector'),
        onSelected: ref.read(appPreferencesProvider.notifier).setTheme,
        itemBuilder: (_) => [
          for (final theme in AppThemePreference.values)
            PopupMenuItem(value: theme, child: Text(_themeLabel(theme))),
        ],
        child: SettingValueRow(
          icon: Icons.brightness_6_outlined,
          title: context.tr('主题', 'Theme'),
          value: _themeLabel(selected),
        ),
      );

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

  Widget _loadingServiceCard({
    required Key key,
    required IconData icon,
    required String title,
  }) => ServiceStatusCard(
    cardKey: key,
    icon: icon,
    title: title,
    provider: context.tr('读取中', 'Loading'),
    selection: '',
    readiness: ServiceReadiness.loading,
    onTap: () {},
  );

  Widget _errorServiceCard({
    required Key key,
    required IconData icon,
    required String title,
    required Object error,
    required VoidCallback onTap,
  }) => ServiceStatusCard(
    cardKey: key,
    icon: icon,
    title: title,
    provider: context.tr('读取失败', 'Failed to load'),
    selection: '$error',
    readiness: ServiceReadiness.error,
    onTap: onTap,
  );

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    ref.invalidate(ttsSettingsControllerProvider);
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
