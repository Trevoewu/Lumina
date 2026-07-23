import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/podcast_artwork.dart';
import 'podcast_episode_screen.dart';
import 'podcast_episode_tile.dart';
import 'podcast_show_screen.dart';

class PodcastLibraryView extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onAddPodcast;
  final VoidCallback onSearchPodcastIndex;

  const PodcastLibraryView({
    super.key,
    required this.scrollController,
    required this.onAddPodcast,
    required this.onSearchPodcastIndex,
  });

  @override
  ConsumerState<PodcastLibraryView> createState() => _PodcastLibraryViewState();
}

class _PodcastLibraryViewState extends ConsumerState<PodcastLibraryView> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    return FutureBuilder<List<PodcastShow>>(
      future: database.getPodcastShows(),
      builder: (context, snapshot) {
        final shows = snapshot.data ?? const <PodcastShow>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (shows.isEmpty) {
          return _PodcastEmptyState(
            scrollController: widget.scrollController,
            onAddPodcast: widget.onAddPodcast,
            onSearchPodcastIndex: widget.onSearchPodcastIndex,
          );
        }

        return FutureBuilder<List<PodcastEpisode>>(
          future: database.getRecentPodcastEpisodes(limit: 30),
          builder: (context, episodeSnapshot) {
            final episodes = episodeSnapshot.data ?? const <PodcastEpisode>[];
            final showsById = {for (final show in shows) show.id: show};
            return RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                key: const PageStorageKey('podcast-library-list'),
                controller: widget.scrollController,
                primary: false,
                padding: EdgeInsets.fromLTRB(inset, design.spaceMd, inset, 120),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      key: const ValueKey('open-podcast-index-search'),
                      leading: const Icon(Icons.travel_explore_rounded),
                      title: Text(
                        context.tr(
                          '在 Podcast Index 中发现节目',
                          'Discover with Podcast Index',
                        ),
                      ),
                      subtitle: Text(
                        context.tr(
                          '搜索开放 Podcast 目录',
                          'Search the open podcast directory',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: widget.onSearchPodcastIndex,
                    ),
                  ),
                  SizedBox(height: design.spaceXl),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('已订阅', 'Subscriptions'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: context.appTextPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('刷新全部', 'Refresh all'),
                        onPressed: _refreshing ? null : _refreshAll,
                        icon: _refreshing
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 154,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shows.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(width: design.spaceMd),
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
                                PodcastArtwork(
                                  imageUrl: show.imageUrl,
                                  size: 108,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  show.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: context.appTextPrimary,
                                        fontWeight: FontWeight.w700,
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
                  Text(
                    context.tr('最新单集', 'Latest episodes'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final episode in episodes)
                    PodcastEpisodeTile(
                      episode: episode,
                      showTitle: showsById[episode.showId]?.title,
                      onTap: () => _openEpisode(episode.id),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(podcastRepositoryProvider).refreshAll();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刷新失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openShow(String showId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PodcastShowScreen(showId: showId)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openEpisode(String episodeId) async {
    await openPodcastEpisodePlayer(context, episodeId: episodeId);
    if (mounted) setState(() {});
  }
}

class _PodcastEmptyState extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onAddPodcast;
  final VoidCallback onSearchPodcastIndex;

  const _PodcastEmptyState({
    required this.scrollController,
    required this.onAddPodcast,
    required this.onSearchPodcastIndex,
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
            Icon(
              Icons.podcasts_rounded,
              size: 112,
              color: context.appSurfaceHighlight,
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('订阅你的第一个 Podcast', 'Add your first podcast'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                '从 Podcast Index 搜索，或粘贴 RSS 地址；订阅后可后台播放并用本地 Whisper 生成字幕。',
                'Search Podcast Index or paste an RSS feed, then play in the background and create transcripts with local Whisper.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              key: const ValueKey('empty-podcast-index-search'),
              onPressed: onSearchPodcastIndex,
              icon: const Icon(Icons.travel_explore_rounded),
              label: Text(
                context.tr('搜索 Podcast Index', 'Search Podcast Index'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAddPodcast,
              icon: const Icon(Icons.add_link),
              label: Text(context.tr('粘贴 RSS 地址', 'Paste RSS feed URL')),
            ),
          ],
        ),
      ),
    );
  }
}
