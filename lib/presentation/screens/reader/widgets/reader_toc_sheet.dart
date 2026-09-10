import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';
import '../../../../data/database/app_database.dart' as drift_db;

class ReaderTocItem {
  final String id;
  final String title;
  final String? href;
  final int index;
  final drift_db.Chapter? dbChapter;

  const ReaderTocItem({
    required this.id,
    required this.title,
    this.href,
    required this.index,
    this.dbChapter,
  });
}

Future<ReaderTocItem?> showReaderTocSheet({
  required BuildContext context,
  required String bookTitle,
  List<drift_db.Chapter>? chapters,
  List<ReaderTocItem>? items,
  required String currentChapterId,
}) {
  final resolvedItems = items ??
      (chapters ?? const [])
          .map(
            (c) => ReaderTocItem(
              id: c.id,
              title: c.title,
              index: c.chapterIndex,
              dbChapter: c,
            ),
          )
          .toList(growable: false);

  return showModalBottomSheet<ReaderTocItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ReaderTocSheet(
      bookTitle: bookTitle,
      items: resolvedItems,
      currentChapterId: currentChapterId,
    ),
  );
}

class _ReaderTocSheet extends StatefulWidget {
  final String bookTitle;
  final List<ReaderTocItem> items;
  final String currentChapterId;

  const _ReaderTocSheet({
    required this.bookTitle,
    required this.items,
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
      final index = widget.items.indexWhere(
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
                        '${widget.bookTitle} · ${context.tr('共 ${widget.items.length} 项', '${widget.items.length} items', '全 ${widget.items.length} 項目')}',
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
              itemCount: widget.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isCurrent = item.id == widget.currentChapterId;

                return InkWell(
                  onTap: () => Navigator.of(context).pop(item),
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
                          '${item.index + 1}',
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
                            item.title,
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
