import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/book_card_metadata.dart';
import '../../widgets/book_list_card.dart';
import '../podcast/podcast_episode_screen.dart';
import '../podcast/podcast_episode_tile.dart';

class HomeOverviewView extends ConsumerStatefulWidget {
  final int reloadToken;
  final ScrollController scrollController;
  final VoidCallback onImportBook;
  final VoidCallback onAddPodcast;
  final VoidCallback onSearchPodcastIndex;
  final ValueChanged<Book> onBookLongPress;
  final ValueChanged<Book> onOpenBook;

  const HomeOverviewView({
    super.key,
    required this.reloadToken,
    required this.scrollController,
    required this.onImportBook,
    required this.onAddPodcast,
    required this.onSearchPodcastIndex,
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
          onSearchPodcastIndex: widget.onSearchPodcastIndex,
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
      database.getRecentPodcastEpisodes(limit: 8),
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

class _HomeOverviewContent extends StatelessWidget {
  final _HomeOverviewData data;
  final ScrollController scrollController;
  final VoidCallback onImportBook;
  final VoidCallback onAddPodcast;
  final VoidCallback onSearchPodcastIndex;
  final ValueChanged<Book> onBookLongPress;
  final ValueChanged<Book> onOpenBook;

  const _HomeOverviewContent({
    required this.data,
    required this.scrollController,
    required this.onImportBook,
    required this.onAddPodcast,
    required this.onSearchPodcastIndex,
    required this.onBookLongPress,
    required this.onOpenBook,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final recentBooks = data.books.take(5).toList(growable: false);

    return ListView(
      key: const PageStorageKey('home-overview-list'),
      controller: scrollController,
      primary: false,
      padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
      children: [
        if (data.books.isEmpty && data.episodes.isEmpty) ...[
          Text(
            context.tr('开始收听', 'Start listening'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: design.spaceMd),
          _StartCard(
            icon: Icons.auto_stories_rounded,
            title: context.tr('导入一本书', 'Import a book'),
            subtitle: context.tr('支持 EPUB 和 TXT', 'EPUB and TXT supported'),
            onTap: onImportBook,
          ),
          SizedBox(height: design.spaceMd),
          _StartCard(
            icon: Icons.travel_explore_rounded,
            title: context.tr('发现 Podcast', 'Discover podcasts'),
            subtitle: context.tr(
              '通过 Podcast Index 搜索开放目录',
              'Search the open directory with Podcast Index',
            ),
            onTap: onSearchPodcastIndex,
          ),
          SizedBox(height: design.spaceMd),
          _StartCard(
            icon: Icons.rss_feed,
            title: context.tr('通过 RSS 添加', 'Add with RSS'),
            subtitle: context.tr(
              '粘贴已知的节目 Feed 地址',
              'Paste a podcast feed you already know',
            ),
            onTap: onAddPodcast,
          ),
        ],
        if (recentBooks.isNotEmpty) ...[
          Text(
            context.tr('继续阅读', 'Continue reading'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final book in recentBooks)
            BookListCard(
              title: book.title,
              subtitle: book.author ?? context.tr('未知作者', 'Unknown author'),
              localCoverPath: book.coverPath,
              metadata: [
                BookListCardMeta(
                  icon: Icons.trending_up_outlined,
                  label: bookReadingProgressLabel(
                    context,
                    book,
                    finishedChapterIndexes:
                        data.finishedChapterIndexesByBook[book.id] ??
                        const <int>{},
                  ),
                ),
                BookListCardMeta(
                  icon: Icons.library_books_outlined,
                  label: context.tr(
                    '${book.chapterCount} 章',
                    '${book.chapterCount} chapters',
                  ),
                ),
              ],
              onTap: () => onOpenBook(book),
              onLongPress: () => onBookLongPress(book),
            ),
        ],
        if (data.episodes.isNotEmpty) ...[
          SizedBox(height: recentBooks.isEmpty ? 0 : design.spaceXl),
          Text(
            context.tr('Podcast 最新单集', 'Latest podcast episodes'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final episode in data.episodes)
            PodcastEpisodeTile(
              episode: episode,
              showTitle: data.showsById[episode.showId]?.title,
              onTap: () =>
                  openPodcastEpisodePlayer(context, episodeId: episode.id),
            ),
        ],
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _StartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
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
