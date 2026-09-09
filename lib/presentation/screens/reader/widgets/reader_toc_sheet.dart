import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';
import '../../../../data/database/app_database.dart' as drift_db;

Future<drift_db.Chapter?> showReaderTocSheet({
  required BuildContext context,
  required String bookTitle,
  required List<drift_db.Chapter> chapters,
  required String currentChapterId,
}) {
  return showModalBottomSheet<drift_db.Chapter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ReaderTocSheet(
      bookTitle: bookTitle,
      chapters: chapters,
      currentChapterId: currentChapterId,
    ),
  );
}

class _ReaderTocSheet extends StatefulWidget {
  final String bookTitle;
  final List<drift_db.Chapter> chapters;
  final String currentChapterId;

  const _ReaderTocSheet({
    required this.bookTitle,
    required this.chapters,
    required this.currentChapterId,
  });

  @override
  State<_ReaderTocSheet> createState() => _ReaderTocSheetState();
}

class _ReaderTocSheetState extends State<_ReaderTocSheet> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = widget.chapters.indexWhere(
        (c) => c.id == widget.currentChapterId,
      );
      if (index > 0 && _scrollController.hasClients) {
        final targetOffset = (index * 56.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(targetOffset);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('目录', 'Table of Contents', '目次'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.bookTitle} · ${context.tr('共 ${widget.chapters.length} 章', '${widget.chapters.length} chapters', '全 ${widget.chapters.length} 章')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const AppIcon(AppIcons.cancel01),
                  color: context.appTextSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 16),
              itemCount: widget.chapters.length,
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final chapter = widget.chapters[index];
                final isCurrent = chapter.id == widget.currentChapterId;

                return InkWell(
                  onTap: () => Navigator.of(context).pop(chapter),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? context.appAccent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${chapter.chapterIndex + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: isCurrent
                                ? context.appAccent
                                : context.appTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            chapter.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                              color: isCurrent
                                  ? context.appAccent
                                  : context.appTextPrimary,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          AppIcon(
                            AppIcons.bookmarkCheck01,
                            size: 18,
                            color: context.appAccent,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
