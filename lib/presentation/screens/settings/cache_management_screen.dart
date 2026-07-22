import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../services/app_log_service.dart';
import '../../../services/cache_manager.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class CacheManagementScreen extends ConsumerStatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  ConsumerState<CacheManagementScreen> createState() =>
      _CacheManagementScreenState();
}

class _CacheManagementScreenState extends ConsumerState<CacheManagementScreen> {
  bool _clearing = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final cache = ref.watch(cacheManagerProvider);

    return CollapsingPageScaffold(
      title: context.tr('缓存管理', 'Audio Cache'),
      showBackButton: true,
      body: FutureBuilder<_CachePageData>(
        future: _loadData(db, cache),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data == null) {
            return Center(
              child: Text(context.tr('暂无缓存信息', 'No cache information')),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SurfaceTile(
                  child: ListTile(
                    leading: Icon(
                      Icons.storage_outlined,
                      color: context.appTextSecondary,
                    ),
                    title: Text(
                      context.tr('总音频缓存', 'Total audio cache'),
                      style: TextStyle(color: context.appTextPrimary),
                    ),
                    subtitle: Text(data.total.humanReadable),
                    trailing: IconButton(
                      tooltip: context.tr('清空', 'Clear all'),
                      onPressed: _clearing || data.total.bytes == 0
                          ? null
                          : () => _clearAll(cache),
                      icon: _clearing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.delete_sweep_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    context.tr('按书籍清理', 'Clear by book'),
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (data.books.isEmpty)
                  _SurfaceTile(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.tr('暂无导入书籍', 'No imported books')),
                    ),
                  )
                else
                  for (final row in data.books)
                    _SurfaceTile(
                      child: ExpansionTile(
                        collapsedIconColor: context.appTextSecondary,
                        iconColor: context.appTextSecondary,
                        leading: Icon(
                          Icons.menu_book_outlined,
                          color: context.appTextSecondary,
                        ),
                        title: Text(
                          row.book.title,
                          style: TextStyle(color: context.appTextPrimary),
                        ),
                        subtitle: Text(
                          '${row.usage.humanReadable} · ${row.book.chapterCount} ${context.tr('章', 'chapters')}',
                          style: TextStyle(color: context.appTextSecondary),
                        ),
                        children: [
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: context.tr(
                                  '清理整本书音频',
                                  'Clear audio for this book',
                                ),
                                onPressed: row.usage.bytes == 0 || _clearing
                                    ? null
                                    : () => _clearBook(cache, row.book),
                                icon: Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          FutureBuilder<List<_ChapterCacheRow>>(
                            future: _loadChapterRows(db, cache, row.book.id),
                            builder: (context, chapterSnapshot) {
                              final chaptersRows =
                                  chapterSnapshot.data ??
                                  const <_ChapterCacheRow>[];
                              if (chaptersRows.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    context.tr('暂无章节', 'No chapters'),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  for (final chapterRow in chaptersRows)
                                    ListTile(
                                      dense: true,
                                      title: Text(
                                        chapterRow.chapter.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        chapterRow.usage.humanReadable,
                                        style: TextStyle(
                                          color: context.appTextSecondary,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        tooltip: context.tr(
                                          '清理章节音频',
                                          'Clear chapter audio',
                                        ),
                                        onPressed: _clearing
                                            ? null
                                            : () => _clearChapter(
                                                cache,
                                                row.book,
                                                chapterRow.chapter,
                                              ),
                                        icon: Icon(Icons.delete_outline),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_CachePageData> _loadData(
    drift_db.AppDatabase db,
    CacheManager cache,
  ) async {
    final books = await db.getAllBooks();
    final rows = <_BookCacheRow>[];
    for (final book in books) {
      rows.add(
        _BookCacheRow(book: book, usage: await cache.usageForBook(book.id)),
      );
    }
    return _CachePageData(total: await cache.totalUsage(), books: rows);
  }

  Future<List<_ChapterCacheRow>> _loadChapterRows(
    drift_db.AppDatabase db,
    CacheManager cache,
    String bookId,
  ) async {
    final chapters = await db.getChapters(bookId);
    final rows = <_ChapterCacheRow>[];
    for (final chapter in chapters) {
      rows.add(
        _ChapterCacheRow(
          chapter: chapter,
          usage: await cache.usageForChapter(bookId, chapter.id),
        ),
      );
    }
    return rows;
  }

  Future<void> _clearAll(CacheManager cache) async {
    if (!await _confirm(context.tr('清空所有音频缓存？', 'Clear all audio cache?'))) {
      return;
    }
    setState(() => _clearing = true);
    try {
      await cache.clearAll();
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      AppLogger.error('Cache', '清理全部缓存失败', error: e, stackTrace: stackTrace);
      _showError(e);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _clearBook(CacheManager cache, drift_db.Book book) async {
    if (!await _confirm(
      context.tr(
        '清理《${book.title}》的所有音频缓存？',
        'Clear all cached audio for "${book.title}"?',
      ),
    )) {
      return;
    }
    setState(() => _clearing = true);
    try {
      await cache.clearBook(book.id);
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      AppLogger.error(
        'Cache',
        '清理书籍缓存失败 book=${book.id}',
        error: e,
        stackTrace: stackTrace,
      );
      _showError(e);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _clearChapter(
    CacheManager cache,
    drift_db.Book book,
    drift_db.Chapter chapter,
  ) async {
    if (!await _confirm(
      context.tr(
        '清理《${book.title}》- ${chapter.title} 的音频缓存？',
        'Clear cached audio for "${book.title}" — ${chapter.title}?',
      ),
    )) {
      return;
    }
    setState(() => _clearing = true);
    try {
      await cache.clearChapter(book.id, chapter.id);
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      AppLogger.error(
        'Cache',
        '清理章节缓存失败 chapter=${chapter.id}',
        error: e,
        stackTrace: stackTrace,
      );
      _showError(e);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          context.tr(
            '缓存清理未完全完成，请稍后重试。',
            'The cache could not be fully cleared. Please try again.',
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('确认清理', 'Confirm clearing')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('清理', 'Clear')),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _CachePageData {
  final CacheUsage total;
  final List<_BookCacheRow> books;

  const _CachePageData({required this.total, required this.books});
}

class _BookCacheRow {
  final drift_db.Book book;
  final CacheUsage usage;

  const _BookCacheRow({required this.book, required this.usage});
}

class _ChapterCacheRow {
  final drift_db.Chapter chapter;
  final CacheUsage usage;

  const _ChapterCacheRow({required this.chapter, required this.usage});
}

class _SurfaceTile extends StatelessWidget {
  final Widget child;

  const _SurfaceTile({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}
