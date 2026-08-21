import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../services/app_log_service.dart';
import '../../../services/cache_manager.dart';
import '../../widgets/collapsing_page_scaffold.dart';

const _cacheExpansionShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

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
      title: context.tr('缓存管理', 'Audio Cache', '音声キャッシュ'),
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
              child: Text(
                context.tr('暂无缓存信息', 'No cache information', 'キャッシュ情報はありません'),
              ),
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
                      context.tr('总音频缓存', 'Total audio cache', '音声キャッシュ合計'),
                      style: TextStyle(color: context.appTextPrimary),
                    ),
                    subtitle: Text(
                      '${data.total.humanReadable} · '
                      '${context.tr('书籍', 'Books', '書籍')} '
                      '${data.bookAudio.humanReadable} · Podcast '
                      '${data.podcastAudio.humanReadable}',
                    ),
                    trailing: IconButton(
                      tooltip: context.tr('清空', 'Clear all', 'すべてクリア'),
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
                    context.tr('书籍', 'Books', '書籍'),
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
                      child: Text(
                        context.tr(
                          '暂无导入书籍',
                          'No imported books',
                          'インポートした書籍はありません',
                        ),
                      ),
                    ),
                  )
                else
                  for (final row in data.books)
                    _SurfaceTile(
                      child: ExpansionTile(
                        shape: _cacheExpansionShape,
                        collapsedShape: _cacheExpansionShape,
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
                          '${row.usage.humanReadable} · ${row.book.chapterCount} ${context.tr('章', 'chapters', '章')}',
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
                                  'この書籍の音声をクリア',
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
                                    context.tr(
                                      '暂无章节',
                                      'No chapters',
                                      '章はありません',
                                    ),
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
                                          '章の音声をクリア',
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Podcast',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (data.podcasts.isEmpty)
                  _SurfaceTile(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr(
                          '暂无 Podcast 音频或字幕缓存',
                          'No cached podcast audio or transcripts',
                          'Podcastの音声・文字起こしキャッシュはありません',
                        ),
                      ),
                    ),
                  )
                else
                  for (final row in data.podcasts)
                    _SurfaceTile(
                      child: ExpansionTile(
                        key: ValueKey('podcast-cache-${row.show.id}'),
                        shape: _cacheExpansionShape,
                        collapsedShape: _cacheExpansionShape,
                        collapsedIconColor: context.appTextSecondary,
                        iconColor: context.appTextSecondary,
                        leading: Icon(
                          Icons.podcasts_rounded,
                          color: context.appTextSecondary,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.show.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.appTextPrimary),
                              ),
                            ),
                            _podcastDeleteButton(
                              key: ValueKey(
                                'podcast-delete-show-${row.show.id}',
                              ),
                              hasAudio: row.usage.bytes > 0,
                              hasTranscript: row.transcriptCount > 0,
                              onDelete: (action) =>
                                  _clearPodcastShow(cache, row, action),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          _podcastSummary(row.usage, row.transcriptCount),
                          style: TextStyle(color: context.appTextSecondary),
                        ),
                        children: [
                          for (final episode in row.episodes)
                            ListTile(
                              dense: true,
                              key: ValueKey(
                                'podcast-cache-episode-${episode.episode.id}',
                              ),
                              title: Text(
                                episode.episode.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.appTextPrimary),
                              ),
                              subtitle: Text(
                                _podcastSummary(
                                  episode.usage,
                                  episode.hasTranscript ? 1 : 0,
                                ),
                                style: TextStyle(
                                  color: context.appTextSecondary,
                                ),
                              ),
                              trailing: _podcastDeleteButton(
                                key: ValueKey(
                                  'podcast-delete-episode-'
                                  '${episode.episode.id}',
                                ),
                                hasAudio: episode.usage.bytes > 0,
                                hasTranscript: episode.hasTranscript,
                                onDelete: (action) => _clearPodcastEpisode(
                                  cache,
                                  episode,
                                  action,
                                ),
                              ),
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
    final bookRows = <_BookCacheRow>[];
    for (final book in books) {
      bookRows.add(
        _BookCacheRow(book: book, usage: await cache.usageForBook(book.id)),
      );
    }

    final podcastRows = <_PodcastCacheRow>[];
    for (final show in await db.getAllPodcastShows()) {
      final episodeRows = <_PodcastEpisodeCacheRow>[];
      var showBytes = 0;
      var transcriptCount = 0;
      for (final episode in await db.getPodcastEpisodes(show.id)) {
        final usage = await cache.usageForPodcastEpisode(episode);
        final hasTranscript =
            episode.transcriptJson?.trim().isNotEmpty ?? false;
        if (usage.bytes == 0 && !hasTranscript) continue;
        showBytes += usage.bytes;
        if (hasTranscript) transcriptCount++;
        episodeRows.add(
          _PodcastEpisodeCacheRow(
            episode: episode,
            usage: usage,
            hasTranscript: hasTranscript,
          ),
        );
      }
      if (episodeRows.isEmpty) continue;
      podcastRows.add(
        _PodcastCacheRow(
          show: show,
          usage: CacheUsage(showBytes),
          transcriptCount: transcriptCount,
          episodes: episodeRows,
        ),
      );
    }

    final bookAudio = await cache.bookAudioUsage();
    final podcastAudio = await cache.podcastAudioUsage();
    return _CachePageData(
      total: CacheUsage(bookAudio.bytes + podcastAudio.bytes),
      bookAudio: bookAudio,
      podcastAudio: podcastAudio,
      books: bookRows,
      podcasts: podcastRows,
    );
  }

  String _podcastSummary(CacheUsage usage, int transcriptCount) {
    return [
      context.tr(
        '音频 ${usage.humanReadable}',
        'Audio ${usage.humanReadable}',
        '音声 ${usage.humanReadable}',
      ),
      context.tr(
        '$transcriptCount 份 Transcript',
        '$transcriptCount transcript${transcriptCount == 1 ? '' : 's'}',
        '$transcriptCount件の文字起こし${transcriptCount == 1 ? '' : ''}',
      ),
    ].join(' · ');
  }

  Widget _podcastDeleteButton({
    required Key key,
    required bool hasAudio,
    required bool hasTranscript,
    required Future<void> Function(_PodcastClearAction action) onDelete,
  }) {
    return IconButton(
      key: key,
      tooltip: context.tr('删除缓存', 'Delete cache', 'キャッシュを削除'),
      onPressed: _clearing
          ? null
          : () async {
              final action = await _selectPodcastDeleteAction(
                hasAudio: hasAudio,
                hasTranscript: hasTranscript,
              );
              if (action != null) await onDelete(action);
            },
      icon: const Icon(Icons.delete_outline_rounded),
    );
  }

  Future<_PodcastClearAction?> _selectPodcastDeleteAction({
    required bool hasAudio,
    required bool hasTranscript,
  }) async {
    if (hasAudio && !hasTranscript) return _PodcastClearAction.audio;
    if (!hasAudio && hasTranscript) return _PodcastClearAction.transcript;
    if (!hasAudio && !hasTranscript) return null;

    return showDialog<_PodcastClearAction>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          context.tr('删除哪些缓存？', 'Delete which cache?', 'どのキャッシュを削除しますか？'),
        ),
        children: [
          SimpleDialogOption(
            key: const ValueKey('podcast-delete-choice-audio'),
            onPressed: () =>
                Navigator.of(context).pop(_PodcastClearAction.audio),
            child: Row(
              children: [
                const Icon(Icons.audio_file_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(context.tr('删除音频', 'Delete audio', '音声を削除')),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            key: const ValueKey('podcast-delete-choice-transcript'),
            onPressed: () =>
                Navigator.of(context).pop(_PodcastClearAction.transcript),
            child: Row(
              children: [
                const Icon(Icons.subtitles_off_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(
                      '删除 Transcript',
                      'Delete transcript',
                      '文字起こしを削除',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            key: const ValueKey('podcast-delete-choice-all'),
            onPressed: () => Navigator.of(context).pop(_PodcastClearAction.all),
            child: Row(
              children: [
                const Icon(Icons.delete_sweep_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(
                      '删除音频和 Transcript',
                      'Delete audio and transcript',
                      '音声と文字起こしを削除',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    if (!await _confirm(
      context.tr('清空所有音频缓存？', 'Clear all audio cache?', 'すべての音声キャッシュをクリアしますか？'),
    )) {
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
        '「${book.title}」の音声キャッシュをすべてクリアしますか？',
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
        '「${book.title}」- ${chapter.title}の音声キャッシュをクリアしますか？',
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

  Future<void> _clearPodcastShow(
    CacheManager cache,
    _PodcastCacheRow row,
    _PodcastClearAction action,
  ) {
    return _runPodcastClear(
      _podcastClearConfirmation(row.show.title, action),
      () async {
        switch (action) {
          case _PodcastClearAction.audio:
            await cache.clearPodcastShowAudio(row.show.id);
            break;
          case _PodcastClearAction.transcript:
            await cache.clearPodcastShowTranscripts(row.show.id);
            break;
          case _PodcastClearAction.all:
            await cache.clearPodcastShowData(row.show.id);
            break;
        }
      },
    );
  }

  Future<void> _clearPodcastEpisode(
    CacheManager cache,
    _PodcastEpisodeCacheRow row,
    _PodcastClearAction action,
  ) {
    return _runPodcastClear(
      _podcastClearConfirmation(row.episode.title, action),
      () async {
        switch (action) {
          case _PodcastClearAction.audio:
            await cache.clearPodcastEpisodeAudio(row.episode.id);
            break;
          case _PodcastClearAction.transcript:
            await cache.clearPodcastEpisodeTranscript(row.episode.id);
            break;
          case _PodcastClearAction.all:
            await cache.clearPodcastEpisodeData(row.episode.id);
            break;
        }
      },
    );
  }

  String _podcastClearConfirmation(String title, _PodcastClearAction action) {
    return switch (action) {
      _PodcastClearAction.audio => context.tr(
        '清理“$title”的本地音频？字幕会保留。',
        'Clear local audio for "$title"? Transcripts will be kept.',
        '「$title」のローカル音声をクリアしますか？文字起こしは保持されます。',
      ),
      _PodcastClearAction.transcript => context.tr(
        '清理“$title”的字幕？本地音频会保留。',
        'Clear transcripts for "$title"? Local audio will be kept.',
        '「$title」の文字起こしをクリアしますか？ローカル音声は保持されます。',
      ),
      _PodcastClearAction.all => context.tr(
        '清理“$title”的本地音频和字幕？',
        'Clear local audio and transcripts for "$title"?',
        '「$title」のローカル音声と文字起こしをクリアしますか？',
      ),
    };
  }

  Future<void> _runPodcastClear(
    String confirmation,
    Future<void> Function() action,
  ) async {
    if (!await _confirm(confirmation)) return;
    setState(() => _clearing = true);
    try {
      await action();
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      AppLogger.error(
        'Cache',
        '清理 Podcast 缓存失败',
        error: error,
        stackTrace: stackTrace,
      );
      _showError(error);
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
            'キャッシュを完全にクリアできませんでした。後でもう一度お試しください。',
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('确认清理', 'Confirm clearing', 'クリアを確認')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('清理', 'Clear', 'クリア')),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _CachePageData {
  final CacheUsage total;
  final CacheUsage bookAudio;
  final CacheUsage podcastAudio;
  final List<_BookCacheRow> books;
  final List<_PodcastCacheRow> podcasts;

  const _CachePageData({
    required this.total,
    required this.bookAudio,
    required this.podcastAudio,
    required this.books,
    required this.podcasts,
  });
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

enum _PodcastClearAction { audio, transcript, all }

class _PodcastCacheRow {
  final drift_db.PodcastShow show;
  final CacheUsage usage;
  final int transcriptCount;
  final List<_PodcastEpisodeCacheRow> episodes;

  const _PodcastCacheRow({
    required this.show,
    required this.usage,
    required this.transcriptCount,
    required this.episodes,
  });
}

class _PodcastEpisodeCacheRow {
  final drift_db.PodcastEpisode episode;
  final CacheUsage usage;
  final bool hasTranscript;

  const _PodcastEpisodeCacheRow({
    required this.episode,
    required this.usage,
    required this.hasTranscript,
  });
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
