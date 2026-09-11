import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/appearance.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';
import '../../../../data/database/app_database.dart' as drift_db;
import '../../../widgets/dictionary_lookup_sheet.dart';

class ReaderParagraphView extends ConsumerWidget {
  final drift_db.Paragraph paragraph;
  final bool isPlaying;
  final VoidCallback? onPlayFromHere;

  const ReaderParagraphView({
    super.key,
    required this.paragraph,
    this.isPlaying = false,
    this.onPlayFromHere,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceControllerProvider);
    final accent = context.appAccent;
    final fontScale = appearance.fontScale;
    final fontFamily = appearance.fontOption.fontFamily;
    final fontFamilyFallback = appearance.fontOption.fontFamilyFallback;

    final fontSize = 17.5 * fontScale;
    final lineHeight = appearance.readerLineHeight;
    final paragraphSpacing = 16.0 * fontScale;

    final rawText = paragraph.content.trim();
    final contentText = appearance.readerIndent > 0
        ? '\u2003\u2003$rawText'
        : rawText;
    if (rawText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: paragraphSpacing),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isPlaying
              ? accent.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isPlaying
              ? Border(left: BorderSide(color: accent, width: 3.5))
              : null,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isPlaying ? 12 : 6,
          vertical: isPlaying ? 10 : 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              contentText,
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFamilyFallback,
                fontSize: fontSize,
                height: lineHeight,
                color: isPlaying
                    ? context.appTextPrimary
                    : context.appTextPrimary.withValues(alpha: 0.88),
                letterSpacing: 0.3,
                fontWeight: FontWeight.normal,
              ),
              contextMenuBuilder: (context, editableTextState) {
                final selectedText = editableTextState
                    .textEditingValue
                    .selection
                    .textInside(editableTextState.textEditingValue.text);
                final items = editableTextState.contextMenuButtonItems;

                if (selectedText.trim().isNotEmpty) {
                  items.insert(
                    0,
                    ContextMenuButtonItem(
                      label: context.tr('查词', 'Lookup', '調べる'),
                      onPressed: () {
                        ContextMenuController.removeAny();
                        showDictionaryLookupSheet(
                          context,
                          initialQuery: selectedText.trim(),
                        );
                      },
                    ),
                  );
                }

                if (onPlayFromHere != null) {
                  items.add(
                    ContextMenuButtonItem(
                      label: context.tr('从此处朗读', 'Read from here', 'ここから朗読'),
                      onPressed: () {
                        ContextMenuController.removeAny();
                        onPlayFromHere!();
                      },
                    ),
                  );
                }

                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: items,
                );
              },
            ),
            if (isPlaying) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(AppIcons.audioWave01, size: 14, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('正在朗读', 'Reading aloud', '朗読中'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
