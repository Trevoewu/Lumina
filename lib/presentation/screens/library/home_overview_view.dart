import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/relative_time.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/book_card_metadata.dart';
import '../../widgets/design_system/editorial_type.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/podcast_artwork.dart';
import '../podcast/podcast_episode_screen.dart';
import '../podcast/podcast_formatters.dart';

/// Number of feed rows shown before the "see all" link appears.
const int _collapsedFeedLength = 6;

class HomeOverviewView extends ConsumerStatefulWidget {
  final int reloadToken;
  final ScrollController scrollController;
  final VoidCallback onImportBook;
  final VoidCallback onAddPodcast;
  final ValueChanged<Book> onBookLongPress;
  final ValueChanged<Book> onOpenBook;

  const HomeOverviewView({
    super.key,
    required this.reloadToken,
    required this.scrollController,
    required this.onImportBook,
    required this.onAddPodcast,
    required this.onBookLongPress,
    required this.onOpenBook,
  });

  @override
  ConsumerState<HomeOverviewView> createState() => _HomeOverviewViewState();
}

class _HomeOverviewViewState extends ConsumerState<HomeOverviewView> {
  late Future<_HomeOverviewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load(ref.read(appDatabaseProvider));
  }

  @override
  void didUpdateWidget(covariant HomeOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _dataFuture = _load(ref.read(appDatabaseProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeOverviewData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _HomeOverviewContent(
          data: snapshot.data!,
          scrollController: widget.scrollController,
          onImportBook: widget.onImportBook,
          onAddPodcast: widget.onAddPodcast,
          onBookLongPress: widget.onBookLongPress,
          onOpenBook: widget.onOpenBook,
        );
      },
    );
  }

  Future<_HomeOverviewData> _load(AppDatabase database) async {
    final results = await Future.wait<Object>([
      database.getAllBooks(),
      database.getPodcastShows(),
      database.getRecentPodcastEpisodes(limit: 12),
      database.getFinishedChapterIndexesByBook(),
    ]);
    final books = results[0] as List<Book>;
    final shows = results[1] as List<PodcastShow>;
    final episodes = results[2] as List<PodcastEpisode>;
    books.sort((left, right) {
      final leftTime = left.lastReadAt > 0 ? left.lastReadAt : left.importedAt;
      final rightTime = right.lastReadAt > 0
          ? right.lastReadAt
          : right.importedAt;
      return rightTime.compareTo(leftTime);
    });
    return _HomeOverviewData(
      books: books,
      episodes: episodes,
      showsById: {for (final show in shows) show.id: show},
      finishedChapterIndexesByBook: results[3] as Map<String, Set<int>>,
    );
  }
}

class _HomeOverviewContent extends StatefulWidget {
  final _HomeOverviewData data;
  final ScrollController scrollController;
  final VoidCallback onImportBook;
  final VoidCallback onAddPodcast;
  final ValueChanged<Book> onBookLongPress;
  final ValueChanged<Book> onOpenBook;

  const _HomeOverviewContent({
    required this.data,
    required this.scrollController,
    required this.onImportBook,
    required this.onAddPodcast,
    required this.onBookLongPress,
    required this.onOpenBook,
  });

  @override
  State<_HomeOverviewContent> createState() => _HomeOverviewContentState();
}

class _HomeOverviewContentState extends State<_HomeOverviewContent> {
  bool _feedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final listGutter = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final gutter = listGutter + 6;
    final entries = _buildEntries(context);

    if (entries.isEmpty) {
      return _EmptyHome(
        scrollController: widget.scrollController,
        gutter: gutter,
        onImportBook: widget.onImportBook,
        onAddPodcast: widget.onAddPodcast,
      );
    }

    // The hero resumes whatever was touched last; if nothing has been started
    // it introduces the newest item instead.
    final heroIndex = entries.indexWhere((entry) => entry.started);
    final hero = entries[heroIndex < 0 ? 0 : heroIndex];
    final feed = [
      for (var index = 0; index < entries.length; index++)
        if (entries[index] != hero) entries[index],
    ];
    final visibleFeed = _feedExpanded
        ? feed
        : feed.take(_collapsedFeedLength).toList(growable: false);
    final hasHiddenRows = visibleFeed.length < feed.length;

    return ListView(
      key: const PageStorageKey('home-overview-list'),
      controller: widget.scrollController,
      primary: false,
      padding: EdgeInsets.only(
        top: design.spaceLg,
        // The scaffold extends the body behind the mini player and tab
        // bar, so the last row needs their height as slack.
        bottom: MediaQuery.paddingOf(context).bottom + design.spaceLg,
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: _HeroBlock(entry: hero),
        ),
        if (feed.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(listGutter, 34, listGutter, 0),
            child: const _HairlineDivider(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    context.tr('最新', 'LATEST', '最新'),
                    style: kickerTextStyle(context),
                  ),
                ),
                if (hasHiddenRows)
                  GestureDetector(
                    key: const ValueKey('home-overview-see-all'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _feedExpanded = true),
                    child: Text(
                      context.tr('全部', 'See all', 'すべて表示'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(listGutter, 6, listGutter, 0),
            child: Column(
              children: [
                for (final (index, entry) in visibleFeed.indexed)
                  _FeedRow(
                    key: ValueKey('home-overview-row-$index'),
                    entry: entry,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Merges books and podcast episodes into one recency-ordered feed.
  ///
  /// The first entry becomes the hero "continue" block, so started items are
  /// ranked ahead of untouched ones.
  List<_HomeEntry> _buildEntries(BuildContext context) {
    final data = widget.data;
    final entries = <_HomeEntry>[];

    for (final book in data.books) {
      final percent = estimatedBookReadingProgress(
        book,
        finishedChapterIndexes:
            data.finishedChapterIndexesByBook[book.id] ?? const <int>{},
      );
      final started = book.lastReadAt > 0;
      final progressLabel = context.tr(
        '进度 $percent%',
        '$percent% read',
        '$percent% 読了',
      );
      entries.add(
        _HomeEntry(
          title: book.title,
          subtitle: book.author ?? context.tr('未知作者', 'Unknown author', '著者不明'),
          meta: context.tr(
            '${book.chapterCount} 章',
            '${book.chapterCount} ch',
            '${book.chapterCount}章',
          ),
          when: progressLabel,
          heroKicker: started
              ? context.tr('继续阅读', 'CONTINUE READING', '続きを読む')
              : context.tr('开始阅读', 'START READING', '読み始める'),
          heroPosition: progressLabel,
          heroLeft: context.tr(
            '${book.chapterCount} 章',
            '${book.chapterCount} chapters',
            '${book.chapterCount}章',
          ),
          heroRight: started
              ? relativeTimeLabel(context, book.lastReadAt)
              : context.tr('未开始', 'Not started', '未開始'),
          progress: percent / 100,
          isPodcast: false,
          localCoverPath: book.coverPath,
          started: started,
          sortKey: started ? book.lastReadAt : book.importedAt,
          onTap: () => widget.onOpenBook(book),
          onLongPress: () => widget.onBookLongPress(book),
        ),
      );
    }

    for (final episode in data.episodes) {
      final show = data.showsById[episode.showId];
      final duration = Duration(milliseconds: episode.durationMs);
      final position = Duration(milliseconds: episode.playbackPositionMs);
      final started =
          episode.lastPlayedAt > 0 || episode.playbackPositionMs > 0;
      final remaining = duration - position;
      entries.add(
        _HomeEntry(
          title: episode.title,
          subtitle: show?.title ?? 'Podcast',
          meta: _durationLabel(context, episode.durationMs),
          when: relativeTimeLabel(context, episode.publishedAt),
          heroKicker: started
              ? context.tr('继续收听', 'CONTINUE LISTENING', '続きを聴く')
              : context.tr('开始收听', 'START LISTENING', '聴き始める'),
          heroPosition: episode.durationMs > 0
              ? '${formatPlaybackTime(position)} / '
                    '${formatPlaybackTime(duration)}'
              : relativeTimeLabel(context, episode.publishedAt),
          // The show name is already the hero subtitle, so the footer carries
          // the publish date instead of repeating it.
          heroLeft: relativeTimeLabel(context, episode.publishedAt),
          heroRight: episode.isPlayed
              ? context.tr('已听完', 'Finished', '聴き終わり')
              : remaining > Duration.zero
              ? context.tr(
                  '剩余 ${formatPlaybackTime(remaining)}',
                  '${formatPlaybackTime(remaining)} left',
                  '残り ${formatPlaybackTime(remaining)}',
                )
              : _durationLabel(context, episode.durationMs),
          progress: episode.durationMs <= 0
              ? 0
              : (episode.playbackPositionMs / episode.durationMs).clamp(
                  0.0,
                  1.0,
                ),
          isPodcast: true,
          remoteImageUrl: episode.imageUrl,
          started: started,
          sortKey: started && episode.lastPlayedAt > 0
              ? episode.lastPlayedAt
              : episode.publishedAt,
          onTap: () => openPodcastEpisodePlayer(context, episodeId: episode.id),
        ),
      );
    }

    entries.sort((left, right) => right.sortKey.compareTo(left.sortKey));
    return entries;
  }
}

class _HeroBlock extends ConsumerWidget {
  final _HomeEntry entry;

  const _HeroBlock({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = context.appTextPrimary;
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final handler = handlerAsync.asData?.value;
    final mediaItem = handler?.mediaItem.valueOrNull;
    final playbackState = handler?.playbackState.valueOrNull;
    final isCurrentMedia =
        mediaItem != null && (mediaItem.title == entry.title);
    final isPlaying = isCurrentMedia && (playbackState?.playing ?? false);

    void handlePlayPause() {
      if (isPlaying) {
        handler?.pause();
      } else if (isCurrentMedia) {
        handler?.play();
      } else {
        entry.onTap();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.heroKicker, style: kickerTextStyle(context)),
        const SizedBox(height: 14),
        GestureDetector(
          key: const ValueKey('home-overview-hero'),
          behavior: HitTestBehavior.opaque,
          onTap: entry.onTap,
          onLongPress: entry.onLongPress,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EntryArtwork(entry: entry, size: 104, borderRadius: 14),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.22,
                          fontWeight: FontWeight.normal,
                          letterSpacing: -0.33,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: ink.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        entry.heroPosition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: technicalTextStyle(
                          context,
                          size: 12.5,
                          alpha: 0.45,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _PlayButton(onTap: handlePlayPause, isPlaying: isPlaying),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgressTrack(
                    value: entry.progress,
                    height: 4,
                    trackAlpha: 0.14,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.heroLeft,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: technicalTextStyle(
                            context,
                            size: 12,
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        entry.heroRight,
                        maxLines: 1,
                        style: technicalTextStyle(
                          context,
                          size: 12,
                          alpha: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeedRow extends StatelessWidget {
  final _HomeEntry entry;

  const _FeedRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final meta = [
      entry.meta,
      entry.when,
    ].where((value) => value.trim().isNotEmpty).join('  ·  ');

    return InkWell(
      onTap: entry.onTap,
      onLongPress: entry.onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
        child: Row(
          children: [
            _EntryArtwork(entry: entry, size: 54, borderRadius: 12),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.3,
                      fontWeight: FontWeight.normal,
                      color: ink,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: technicalTextStyle(
                        context,
                        size: 12.5,
                        alpha: 0.42,
                        weight: FontWeight.w400,
                      ),
                    ),
                  ],
                  if (entry.progress > 0) ...[
                    const SizedBox(height: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: _ProgressTrack(
                        value: entry.progress,
                        height: 3,
                        trackAlpha: 0.10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryArtwork extends StatelessWidget {
  final _HomeEntry entry;
  final double size;
  final double borderRadius;

  const _EntryArtwork({
    required this.entry,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: size >= 90
            ? [
                BoxShadow(
                  color: const Color(0xFF141E32).withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: entry.isPodcast
          ? PodcastArtwork(
              imageUrl: entry.remoteImageUrl,
              size: size,
              borderRadius: borderRadius,
            )
          : BookCover(
              coverPath: entry.localCoverPath,
              borderRadius: borderRadius,
              iconSize: size * 0.34,
              placeholderIcon: AppIcons.bookOpen02,
            ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isPlaying;

  const _PlayButton({required this.onTap, this.isPlaying = false});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const ValueKey('home-overview-hero-play'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AppIcon(
              isPlaying ? AppIcons.pause : AppIcons.play,
              size: 34,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double value;
  final double height;
  final double trackAlpha;

  const _ProgressTrack({
    required this.value,
    required this.height,
    required this.trackAlpha,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: ink.withValues(alpha: trackAlpha),
          valueColor: AlwaysStoppedAnimation<Color>(ink),
        ),
      ),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    final line = context.appTextPrimary.withValues(alpha: 0.09);

    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, line, line, Colors.transparent],
          stops: const [0, 0.12, 0.88, 1],
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  final ScrollController scrollController;
  final double gutter;
  final VoidCallback onImportBook;
  final VoidCallback onAddPodcast;

  const _EmptyHome({
    required this.scrollController,
    required this.gutter,
    required this.onImportBook,
    required this.onAddPodcast,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;

    return ListView(
      key: const PageStorageKey('home-overview-list'),
      controller: scrollController,
      primary: false,
      padding: EdgeInsets.fromLTRB(
        gutter,
        design.spaceLg,
        gutter,
        MediaQuery.paddingOf(context).bottom + design.spaceLg,
      ),
      children: [
        Text(
          context.tr('开始收听', 'START LISTENING', '聴き始める'),
          style: kickerTextStyle(context),
        ),
        const SizedBox(height: 14),
        _StartRow(
          icon: AppIcons.bookOpen02,
          title: context.tr('导入一本书', 'Import a book', '本をインポート'),
          subtitle: context.tr(
            '支持 EPUB 和 TXT',
            'EPUB and TXT supported',
            'EPUBとTXTに対応',
          ),
          onTap: onImportBook,
        ),
        _StartRow(
          icon: AppIcons.rss,
          title: context.tr('通过 RSS 添加', 'Add with RSS', 'RSSから追加'),
          subtitle: context.tr(
            '粘贴已知的节目 Feed 地址',
            'Paste a podcast feed you already know',
            '知っているポッドキャストのフィードを貼り付け',
          ),
          onTap: onAddPodcast,
        ),
      ],
    );
  }
}

class _StartRow extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _StartRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: ink.withValues(alpha: 0.06),
              ),
              child: AppIcon(icon, size: 22, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.3,
                      fontWeight: FontWeight.normal,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: ink.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(
              AppIcons.arrowRight01,
              color: ink.withValues(alpha: 0.32),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Locale-aware episode length, matching [relativeTimeLabel] beside it.
String _durationLabel(BuildContext context, int milliseconds) {
  if (milliseconds <= 0) return '';
  if (context.usesChinese) return formatPodcastDuration(milliseconds);
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  return '${duration.inMinutes.clamp(1, 9999)} min';
}

class _HomeEntry {
  final String title;
  final String subtitle;
  final String meta;
  final String when;
  final String heroKicker;
  final String heroPosition;
  final String heroLeft;
  final String heroRight;
  final double progress;
  final bool isPodcast;
  final String? localCoverPath;
  final String? remoteImageUrl;
  final bool started;
  final int sortKey;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _HomeEntry({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.when,
    required this.heroKicker,
    required this.heroPosition,
    required this.heroLeft,
    required this.heroRight,
    required this.progress,
    required this.isPodcast,
    required this.started,
    required this.sortKey,
    required this.onTap,
    this.localCoverPath,
    this.remoteImageUrl,
    this.onLongPress,
  });
}

class _HomeOverviewData {
  final List<Book> books;
  final List<PodcastEpisode> episodes;
  final Map<String, PodcastShow> showsById;
  final Map<String, Set<int>> finishedChapterIndexesByBook;

  const _HomeOverviewData({
    required this.books,
    required this.episodes,
    required this.showsById,
    required this.finishedChapterIndexesByBook,
  });
}
