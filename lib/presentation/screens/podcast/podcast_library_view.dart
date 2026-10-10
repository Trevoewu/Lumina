import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/user_facing_error.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/podcast_artwork.dart';
import 'podcast_episode_screen.dart';
import 'podcast_episode_tile.dart';
import 'podcast_latest_episodes_screen.dart';
import 'podcast_show_screen.dart';

class PodcastLibraryView extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onAddPodcast;

  const PodcastLibraryView({
    super.key,
    required this.scrollController,
    required this.onAddPodcast,
  });

  @override
  ConsumerState<PodcastLibraryView> createState() => _PodcastLibraryViewState();
}

class _PodcastLibraryViewState extends ConsumerState<PodcastLibraryView> {
  bool _refreshing = false;
  late Future<_PodcastLibraryData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_PodcastLibraryData> _loadData() async {
    final database = ref.read(appDatabaseProvider);
    final results = await Future.wait<Object>([
      database.getPodcastShows(),
      database.getRecentPodcastEpisodes(limit: 30),
    ]);
    return _PodcastLibraryData(
      shows: results[0] as List<PodcastShow>,
      episodes: results[1] as List<PodcastEpisode>,
    );
  }

  void _reloadData() {
    if (!mounted) return;
    setState(() {
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    return FutureBuilder<_PodcastLibraryData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data ?? const _PodcastLibraryData();
        final shows = data.shows;
        final episodes = data.episodes;
        if (shows.isEmpty) {
          return _PodcastEmptyState(
            scrollController: widget.scrollController,
            onAddPodcast: widget.onAddPodcast,
          );
        }

        final showsById = {for (final show in shows) show.id: show};
        final previewEpisodes = episodes.take(5);
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            key: const PageStorageKey('podcast-library-list'),
            controller: widget.scrollController,
            primary: false,
            padding: EdgeInsets.fromLTRB(
              inset,
              design.spaceMd,
              inset,
              MediaQuery.paddingOf(context).bottom + design.spaceLg,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('已订阅', 'Subscriptions', '購読中'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('刷新全部', 'Refresh all', 'すべて更新'),
                    onPressed: _refreshing ? null : _refreshAll,
                    icon: _refreshing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppIcon(AppIcons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shows.length,
                  separatorBuilder: (_, _) => SizedBox(width: design.spaceMd),
                  itemBuilder: (context, index) {
                    final show = shows[index];
                    return SizedBox(
                      width: 108,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openShow(show.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PodcastArtwork(imageUrl: show.imageUrl, size: 108),
                            const SizedBox(height: 7),
                            Text(
                              show.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.appTextPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: design.spaceXl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('最新单集', 'Latest episodes', '最新エピソード'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (episodes.length > 5)
                    TextButton(
                      key: const ValueKey('podcast-latest-see-all'),
                      onPressed: _openAllEpisodes,
                      child: Text(context.tr('查看全部', 'See all', 'すべて表示')),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                key: const ValueKey('podcast-latest-preview'),
                children: [
                  for (final episode in previewEpisodes)
                    PodcastEpisodeTile(
                      episode: episode,
                      showTitle: showsById[episode.showId]?.title,
                      onTap: () => _openEpisode(episode.id),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    var refreshed = false;
    try {
      await ref.read(podcastRepositoryProvider).refreshAll();
      refreshed = true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.tr('刷新失败', 'Could not refresh', '更新できませんでした')}: '
              '${userFacingErrorMessage(context, error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          if (refreshed) {
            _dataFuture = _loadData();
          }
        });
      }
    }
  }

  Future<void> _openShow(String showId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PodcastShowScreen(showId: showId)),
    );
    _reloadData();
  }

  Future<void> _openEpisode(String episodeId) async {
    await openPodcastEpisodePlayer(context, episodeId: episodeId);
    _reloadData();
  }

  Future<void> _openAllEpisodes() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PodcastLatestEpisodesScreen(),
      ),
    );
  }
}

class _PodcastLibraryData {
  final List<PodcastShow> shows;
  final List<PodcastEpisode> episodes;

  const _PodcastLibraryData({
    this.shows = const <PodcastShow>[],
    this.episodes = const <PodcastEpisode>[],
  });
}

class _PodcastEmptyState extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onAddPodcast;

  const _PodcastEmptyState({
    required this.scrollController,
    required this.onAddPodcast,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        controller: scrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              AppIcons.podcast,
              size: 112,
              color: context.appSurfaceHighlight,
            ),
            const SizedBox(height: 20),
            Text(
              context.tr(
                '订阅你的第一个 Podcast',
                'Add your first podcast',
                '最初のポッドキャストを購読',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                '到「搜索」标签页搜索节目，或在这里粘贴 RSS 地址；订阅后可后台播放并用本地 Whisper 生成字幕。',
                'Find shows in the Search tab, or paste an RSS feed here, then play in the background and create transcripts with local Whisper.',
                '「検索」タブで番組を探すか、ここにRSSフィードを貼り付けてください。購読後はバックグラウンド再生やローカルWhisperによる文字起こしを利用できます。',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAddPodcast,
              icon: const AppIcon(AppIcons.link01),
              label: Text(
                context.tr(
                  '粘贴 RSS 地址',
                  'Paste RSS feed URL',
                  'RSSフィードURLを貼り付け',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
