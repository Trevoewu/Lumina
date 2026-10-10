import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';
import '../../widgets/app_glass_controls.dart';

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  final _uiLanguageMenuKey = GlobalKey<PopupMenuButtonState<AppLanguage>>();
  final _aiLanguageMenuKey = GlobalKey<PopupMenuButtonState<AppLanguage>>();

  @override
  void initState() {
    super.initState();
    ref.read(appPreferencesProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final scheme = Theme.of(context).colorScheme;
    final preferences = ref.watch(appPreferencesProvider);

    return CollapsingPageScaffold(
      title: context.tr('语言', 'Language', '言語'),
      showBackButton: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 22),
            child: Text(
              context.tr(
                '分别设置界面文字与 AI 生成内容的语言。',
                'Choose languages for the interface and AI-generated content separately.',
                '画面表示とAI生成コンテンツの言語を個別に設定します。',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          SettingsSectionLabel(
            title: context.tr('界面', 'Interface', 'インターフェース'),
          ),
          SettingsGroup(
            children: [
              _languageRow(
                rowKey: const ValueKey('ui-language-selector'),
                menuKey: _uiLanguageMenuKey,
                icon: AppIcons.translation,
                title: context.tr('UI 语言', 'UI Language', 'UI言語'),
                subtitle: context.tr(
                  '仅影响应用菜单、按钮与提示文字',
                  'Controls menus, buttons, and interface text only',
                  'メニュー、ボタン、案内表示にのみ使用します',
                ),
                selected: preferences.language,
                onSelected: ref
                    .read(appPreferencesProvider.notifier)
                    .setLanguage,
              ),
            ],
          ),
          SettingsSectionLabel(
            title: context.tr('AI 服务', 'AI Services', 'AIサービス'),
          ),
          SettingsGroup(
            children: [
              _languageRow(
                rowKey: const ValueKey('ai-language-selector'),
                menuKey: _aiLanguageMenuKey,
                icon: AppIcons.aiMagic,
                title: context.tr('AI 服务语言', 'AI Service Language', 'AIサービス言語'),
                subtitle: context.tr(
                  '用于 AI Summary、Ask AI 与 AI 释义的回复',
                  'Used for AI Summary, Ask AI, and AI explanations',
                  'AI Summary、Ask AI、AI解説の回答に使用します',
                ),
                selected: preferences.aiLanguage,
                onSelected: ref
                    .read(appPreferencesProvider.notifier)
                    .setAiLanguage,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 18, 6, 0),
            child: Text(
              context.tr(
                '“跟随系统”使用设备语言；不支持的设备语言将使用 English。',
                'System uses the device language; unsupported device languages fall back to English.',
                '「システムに従う」は端末の言語を使用し、未対応の言語ではEnglishになります。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageRow({
    required Key rowKey,
    required GlobalKey<PopupMenuButtonState<AppLanguage>> menuKey,
    required AppIconData icon,
    required String title,
    required String subtitle,
    required AppLanguage selected,
    required ValueChanged<AppLanguage> onSelected,
  }) {
    return SettingValueRow(
      rowKey: rowKey,
      icon: icon,
      title: title,
      subtitle: subtitle,
      // A native menu opens from its own button only.
      onTap: usesNativeMenus
          ? null
          : () => menuKey.currentState?.showButtonMenu(),
      trailing: usesNativeMenus
          ? AppNativeChoiceMenu<AppLanguage>(
              choices: {
                for (final language in AppLanguage.values)
                  language: _languageLabel(language),
              },
              selected: selected,
              onSelected: onSelected,
            )
          : PopupMenuButton<AppLanguage>(
        key: menuKey,
        tooltip: context.tr('选择语言', 'Choose language', '言語を選択'),
        position: PopupMenuPosition.under,
        color: Theme.of(context).colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.appDesign.radiusSmall),
        ),
        onSelected: onSelected,
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
  }

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
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(width: context.appDesign.spaceXs),
          AppIcon(
            AppIcons.arrowUpDown,
            color: scheme.onSurfaceVariant,
            size: 18,
          ),
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
              ? AppIcon(AppIcons.tick02, color: scheme.primary)
              : const SizedBox.shrink(),
        ),
        SizedBox(width: context.appDesign.spaceSm),
        Expanded(child: Text(label)),
      ],
    );
  }

  String _languageLabel(AppLanguage value) => switch (value) {
    AppLanguage.system => context.tr('跟随系统', 'System', 'システムに従う'),
    AppLanguage.zhHans => '简体中文',
    AppLanguage.english => 'English',
    AppLanguage.japanese => '日本語',
  };
}
