import 'package:flutter/material.dart';
import '../../../widgets/reading_adjustment_slider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/appearance.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';
import '../../../widgets/app_glass_controls.dart';

Future<void> showReaderAppearanceSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) =>
          const SafeArea(top: false, child: ReaderAppearancePanel()),
    );

/// Inline overlay: changing visibility never changes the EPUB viewport.
class ReaderAppearancePanel extends ConsumerWidget {
  const ReaderAppearancePanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appearanceControllerProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);
    return Container(
      key: const Key('reader-appearance-panel'),
      height: 230,
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 14),
      child: Column(
        children: [
          ReadingAdjustmentSlider(
            sliderKey: const Key('reader-font-slider'),
            label: context.tr('字号', 'Font Size', '文字サイズ'),
            thumb: '${(24 * settings.fontScale).round()}',
            leading: 'A',
            trailing: 'A',
            fontEnds: true,
            value: settings.fontScale.clamp(16 / 24, 40 / 24),
            min: 16 / 24,
            max: 40 / 24,
            divisions: 24,
            onChanged: controller.setFontScale,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: ReadingAdjustmentSlider(
                  sliderKey: const Key('reader-margin-slider'),
                  label: context.tr('边距', 'Margins', '余白'),
                  thumb: context.tr('边距', 'Margin', '余白'),
                  leading: context.tr('小', 'S', '小'),
                  trailing: context.tr('大', 'L', '大'),
                  value: settings.readerMargin.clamp(0.0, 24.0),
                  min: 0,
                  max: 24,
                  divisions: 6,
                  onChanged: (v) => controller.setReaderLayout(margin: v),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ReadingAdjustmentSlider(
                  sliderKey: const Key('reader-line-slider'),
                  label: context.tr('行距', 'Line Spacing', '行间'),
                  thumb: context.tr('行距', 'Spacing', '行间'),
                  leading: context.tr('紧', 'T', '狭'),
                  trailing: context.tr('松', 'L', '広'),
                  value: settings.readerLineHeight.clamp(1.2, 1.8),
                  min: 1.2,
                  max: 1.8,
                  divisions: 6,
                  onChanged: (v) => controller.setReaderLayout(lineHeight: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _ReaderMenu<String>(
                  menuKey: const Key('reader-font-menu'),
                  label: settings.fontOption.label,
                  value: settings.fontId,
                  options: {
                    for (final font in appearanceFontOptions)
                      font.id: font.label,
                  },
                  onSelected: controller.setFont,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReaderMenu<double>(
                  menuKey: const Key('reader-indent-menu'),
                  label: context.tr('首行缩进', 'Indent', '字下げ'),
                  value: settings.readerIndent,
                  options: {
                    -1: context.tr('保留原书', 'Publisher', '原書'),
                    0: context.tr('无缩进', 'None', 'なし'),
                    2: context.tr('缩进两字', 'Two characters', '2文字'),
                  },
                  onSelected: (v) => controller.setReaderLayout(indent: v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReaderMenu<bool>(
                  menuKey: const Key('reader-flow-menu'),
                  label: context.tr('翻页方式', 'Page Mode', 'ページ送り'),
                  value: settings.readerScrolled,
                  options: {
                    false: context.tr('左右翻页', 'Paginated', '横ページ送り'),
                    true: context.tr('上下滚动', 'Scroll', '縦スクロール'),
                  },
                  onSelected: (v) => controller.setReaderLayout(scrolled: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReaderMenu<T> extends StatelessWidget {
  final Key menuKey;
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;
  const _ReaderMenu({
    required this.menuKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    if (usesNativeMenus) {
      return SizedBox(
        key: menuKey,
        height: 36,
        child: Center(
          child: AppNativeChoiceMenu<T>(
            choices: options,
            selected: value,
            color: context.appTextPrimary,
            // This menu sits in the appearance sheet.
            insideModal: true,
            onSelected: onSelected,
          ),
        ),
      );
    }
    return _buildFlutter(context);
  }

  Widget _buildFlutter(BuildContext context) => PopupMenuButton<T>(
    key: menuKey,
    tooltip: label,
    initialValue: value,
    onSelected: onSelected,
    itemBuilder: (context) => options.entries
        .map(
          (e) => CheckedPopupMenuItem<T>(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
        )
        .toList(),
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.appTextPrimary.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: context.appTextSecondary),
        ],
      ),
    ),
  );
}
