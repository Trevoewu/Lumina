import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../services/cache_manager.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: FutureBuilder<_CachePageData>(
        future: _loadData(db, cache),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data == null) {
            return const Center(child: Text('暂无缓存信息'));
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('总音频缓存'),
                    subtitle: Text(data.total.humanReadable),
                    trailing: FilledButton.tonalIcon(
                      onPressed: _clearing || data.total.bytes == 0
                          ? null
                          : () => _clearAll(cache),
                      icon: _clearing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_sweep_outlined),
                      label: const Text('清空'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('按书籍清理', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.books.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('暂无导入书籍'),
                    ),
                  )
                else
                  for (final row in data.books)
                    Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(row.book.title),
                        subtitle: Text(
                          '${row.usage.humanReadable} · ${row.book.chapterCount} 章',
                        ),
                        children: [
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: row.usage.bytes == 0 || _clearing
                                    ? null
                                    : () => _clearBook(cache, row.book),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('清理整本书音频'),
                              ),
                            ],
                          ),
                          FutureBuilder<List<drift_db.Chapter>>(
                            future: db.getChapters(row.book.id),
                            builder: (context, chapterSnapshot) {
                              final chapters =
                                  chapterSnapshot.data ??
                                  const <drift_db.Chapter>[];
                              if (chapters.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('暂无章节'),
                                );
                              }
                              return Column(
                                children: [
                                  for (final chapter in chapters)
                                    ListTile(
                                      dense: true,
                                      title: Text(chapter.title),
                                      trailing: TextButton(
                                        onPressed: _clearing
                                            ? null
                                            : () => _clearChapter(
                                                cache,
                                                row.book,
                                                chapter,
                                              ),
                                        child: const Text('清理'),
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

  Future<void> _clearAll(CacheManager cache) async {
    if (!await _confirm('清空所有音频缓存？')) return;
    setState(() => _clearing = true);
    try {
      await cache.clearAll();
      if (mounted) setState(() {});
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _clearBook(CacheManager cache, drift_db.Book book) async {
    if (!await _confirm('清理《${book.title}》的所有音频缓存？')) return;
    setState(() => _clearing = true);
    try {
      await cache.clearBook(book.id);
      if (mounted) setState(() {});
    } catch (e) {
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
    if (!await _confirm('清理《${book.title}》- ${chapter.title} 的音频缓存？')) return;
    setState(() => _clearing = true);
    try {
      await cache.clearChapter(book.id, chapter.id);
      if (mounted) setState(() {});
    } catch (e) {
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
        content: Text('缓存清理未完全完成：$error'),
      ),
    );
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清理'),
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
