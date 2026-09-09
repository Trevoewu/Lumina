import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/appearance.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';
import '../../../../core/app_preferences.dart';

Future<void> showReaderAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ReaderAppearanceSheet(),
  );
}

class _ReaderAppearanceSheet extends ConsumerWidget {
  const _ReaderAppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceControllerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            context.tr('阅读排版', 'Typography & Theme', '読書設定'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 18),

          // Theme quick toggle
          Row(
            children: [
              _ThemeOptionButton(
                icon: AppIcons.sun01,
                label: context.tr('系统', 'System', '自動'),
                selected: preferences.theme == AppThemePreference.system,
                onTap: () => ref
                    .read(appPreferencesProvider.notifier)
                    .setTheme(AppThemePreference.system),
              ),
              const SizedBox(width: 10),
              _ThemeOptionButton(
                icon: AppIcons.sun03,
                label: context.tr('浅色', 'Light', 'ライト'),
                selected: preferences.theme == AppThemePreference.light,
                onTap: () => ref
                    .read(appPreferencesProvider.notifier)
                    .setTheme(AppThemePreference.light),
              ),
              const SizedBox(width: 10),
              _ThemeOptionButton(
                icon: AppIcons.moon02,
                label: context.tr('深色', 'Dark', 'ダーク'),
                selected: preferences.theme == AppThemePreference.dark,
                onTap: () => ref
                    .read(appPreferencesProvider.notifier)
                    .setTheme(AppThemePreference.dark),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Font family row
          Text(
            context.tr('字体', 'Font', 'フォント'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.appTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final font in appearanceFontOptions) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => controller.setFont(font.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: appearance.fontId == font.id
                              ? context.appAccent.withValues(alpha: 0.15)
                              : scheme.onSurface.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: appearance.fontId == font.id
                                ? context.appAccent
                                : scheme.onSurface.withValues(alpha: 0.1),
                            width: appearance.fontId == font.id ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          font.label,
                          style: TextStyle(
                            fontFamily: font.fontFamily,
                            fontWeight: appearance.fontId == font.id
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: appearance.fontId == font.id
                                ? context.appAccent
                                : context.appTextPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // Font scale row
          Text(
            context.tr('字号', 'Font Size', '文字サイズ'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.appTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const AppIcon(AppIcons.minusSignCircle),
                color: context.appTextSecondary,
                onPressed: appearance.fontScale > 0.85
                    ? () {
                        final next = (appearance.fontScale - 0.05).clamp(
                          0.85,
                          1.3,
                        );
                        controller.setFontScale(next);
                      }
                    : null,
              ),
              Expanded(
                child: Slider(
                  value: appearance.fontScale,
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  activeColor: context.appAccent,
                  label: '${(appearance.fontScale * 100).round()}%',
                  onChanged: controller.setFontScale,
                ),
              ),
              IconButton(
                icon: const AppIcon(AppIcons.addCircle),
                color: context.appTextSecondary,
                onPressed: appearance.fontScale < 1.3
                    ? () {
                        final next = (appearance.fontScale + 0.05).clamp(
                          0.85,
                          1.3,
                        );
                        controller.setFontScale(next);
                      }
                    : null,
              ),
              Text(
                '${(appearance.fontScale * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionButton extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? context.appAccent.withValues(alpha: 0.15)
                : scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? context.appAccent
                  : scheme.onSurface.withValues(alpha: 0.1),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                icon,
                size: 16,
                color: selected ? context.appAccent : context.appTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? context.appAccent : context.appTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
