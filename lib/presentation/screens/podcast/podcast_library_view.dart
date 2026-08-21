import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/podcasts/podcast_index_repository.dart';
import '../../widgets/podcast_artwork.dart';
import 'podcast_discovery_detail_screen.dart';
import 'podcast_episode_screen.dart';
import 'podcast_episode_tile.dart';
import 'podcast_latest_episodes_screen.dart';
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
  late Future<_PodcastLibraryData> _dataFuture;
  int _discoveryRefreshToken = 0;

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
      _discoveryRefreshToken++;
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
        final discoverSection = _PodcastDiscoverSection(
          shows: shows,
          episodes: episodes,
          preferredLanguage: Localizations.localeOf(context).languageCode,
          refreshToken: _discoveryRefreshToken,
          onSearchPodcastIndex: widget.onSearchPodcastIndex,
          onSubscribed: _reloadData,
        );
        if (shows.isEmpty) {
          return _PodcastEmptyState(
            scrollController: widget.scrollController,
            onAddPodcast: widget.onAddPodcast,
            onSearchPodcastIndex: widget.onSearchPodcastIndex,
            discoverSection: discoverSection,
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
                      'Podcast Indexで番組を探す',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      '搜索开放 Podcast 目录',
                      'Search the open podcast directory',
                      '公開ポッドキャストディレクトリを検索',
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
                      context.tr('已订阅', 'Subscriptions', '購読中'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
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
                        : const Icon(Icons.refresh),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('最新单集', 'Latest episodes', '最新エピソード'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
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
              SizedBox(height: design.spaceXl),
              discoverSection,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刷新失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          if (refreshed) {
            _dataFuture = _loadData();
            _discoveryRefreshToken++;
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

class _PodcastDiscoverSection extends ConsumerStatefulWidget {
  final List<PodcastShow> shows;
  final List<PodcastEpisode> episodes;
  final String preferredLanguage;
  final int refreshToken;
  final VoidCallback onSearchPodcastIndex;
  final VoidCallback onSubscribed;

  const _PodcastDiscoverSection({
    required this.shows,
    required this.episodes,
    required this.preferredLanguage,
    required this.refreshToken,
    required this.onSearchPodcastIndex,
    required this.onSubscribed,
  });

  @override
  ConsumerState<_PodcastDiscoverSection> createState() =>
      _PodcastDiscoverSectionState();
}

class _PodcastDiscoverSectionState
    extends ConsumerState<_PodcastDiscoverSection> {
  late Future<List<PodcastIndexRecommendation>> _recommendationsFuture;
  late String _profileFingerprint;

  @override
  void initState() {
    super.initState();
    _profileFingerprint = _fingerprint();
    _recommendationsFuture = _loadRecommendations();
  }

  @override
  void didUpdateWidget(covariant _PodcastDiscoverSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fingerprint = _fingerprint();
    if (fingerprint != _profileFingerprint) {
      _profileFingerprint = fingerprint;
      _recommendationsFuture = _loadRecommendations();
    }
  }

  String _fingerprint() {
    final shows = widget.shows
        .map((show) => '${show.id}:${show.feedUrl}:${show.language}')
        .join('|');
    final episodes = widget.episodes
        .map(
          (episode) =>
              '${episode.id}:${episode.playbackPositionMs}:'
              '${episode.lastPlayedAt}:${episode.isPlayed}',
        )
        .join('|');
    return '$shows//$episodes//${widget.preferredLanguage}//'
        '${widget.refreshToken}';
  }

  Future<List<PodcastIndexRecommendation>> _loadRecommendations() {
    return ref
        .read(podcastIndexRepositoryProvider)
        .discover(
          seeds: _buildDiscoverySeeds(widget.shows, widget.episodes),
          subscribedFeedUrls: widget.shows.map((show) => show.feedUrl).toSet(),
          preferredLanguage: _preferredPodcastLanguage(
            widget.shows,
            widget.preferredLanguage,
          ),
          limit: 10,
        );
  }

  void _refresh() {
    setState(() {
      _recommendationsFuture = _loadRecommendations();
    });
  }

  Future<void> _openDetails(PodcastIndexPodcast podcast) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastDiscoveryDetailScreen(podcast: podcast),
      ),
    );
    if (mounted) widget.onSubscribed();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('podcast-discover-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('为你发现', 'Discover for you', 'おすすめを発見'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr(
                '换一批推荐',
                'Refresh recommendations',
                'おすすめを更新',
              ),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<PodcastIndexRecommendation>>(
          future: _recommendationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 144,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final recommendations =
                snapshot.data ?? const <PodcastIndexRecommendation>[];
            if (recommendations.isEmpty) {
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.travel_explore_rounded),
                  title: Text(
                    context.tr(
                      '浏览 Podcast Index',
                      'Browse Podcast Index',
                      'Podcast Indexを閲覧',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      '搜索节目后，推荐会根据你的订阅和收听逐渐调整。',
                      'Recommendations adapt as you follow and listen.',
                      'フォローや再生履歴に応じて、おすすめが変わります。',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onSearchPodcastIndex,
                ),
              );
            }
            return SizedBox(
              height: 132,
              child: ListView.separated(
                key: const ValueKey('podcast-discover-recommendations'),
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final recommendation = recommendations[index];
                  final podcast = recommendation.podcast;
                  return SizedBox(
                    width: 286,
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('podcast-discover-card-${podcast.id}'),
                        onTap: () => _openDetails(podcast),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              PodcastArtwork(
                                imageUrl: podcast.imageUrl,
                                size: 108,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      podcast.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: context.appTextPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (podcast.author case final author?
                                        when author.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: context.appTextSecondary,
                                            ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _recommendationReason(
                                              context,
                                              recommendation,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      context.appTextSecondary,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: context.appTextSecondary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PodcastEmptyState extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onAddPodcast;
  final VoidCallback onSearchPodcastIndex;
  final Widget discoverSection;

  const _PodcastEmptyState({
    required this.scrollController,
    required this.onAddPodcast,
    required this.onSearchPodcastIndex,
    required this.discoverSection,
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
              context.tr(
                '订阅你的第一个 Podcast',
                'Add your first podcast',
                '最初のポッドキャストを購読',
              ),
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
                'Podcast Indexを検索するかRSSフィードを貼り付けると、バックグラウンド再生やローカルWhisperによる文字起こしを利用できます。',
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
                context.tr(
                  '搜索 Podcast Index',
                  'Search Podcast Index',
                  'Podcast Indexを検索',
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAddPodcast,
              icon: const Icon(Icons.add_link),
              label: Text(
                context.tr(
                  '粘贴 RSS 地址',
                  'Paste RSS feed URL',
                  'RSSフィードURLを貼り付け',
                ),
              ),
            ),
            const SizedBox(height: 36),
            discoverSection,
          ],
        ),
      ),
    );
  }
}

List<PodcastDiscoverySeed> _buildDiscoverySeeds(
  List<PodcastShow> shows,
  List<PodcastEpisode> episodes,
) {
  final episodesByShow = <String, List<PodcastEpisode>>{};
  for (final episode in episodes) {
    episodesByShow.putIfAbsent(episode.showId, () => []).add(episode);
  }
  return [
    for (final show in shows)
      PodcastDiscoverySeed(
        title: show.title,
        author: show.author,
        feedUrl: show.feedUrl,
        language: show.language,
        engagement: _showEngagement(episodesByShow[show.id] ?? const []),
      ),
  ];
}

double _showEngagement(List<PodcastEpisode> episodes) {
  var bestProgress = 0.0;
  var hasPlayed = false;
  for (final episode in episodes) {
    if (episode.lastPlayedAt > 0 || episode.playbackPositionMs > 0) {
      hasPlayed = true;
    }
    final progress = episode.isPlayed
        ? 1.0
        : episode.durationMs <= 0
        ? 0.0
        : (episode.playbackPositionMs / episode.durationMs)
              .clamp(0.0, 1.0)
              .toDouble();
    if (progress > bestProgress) bestProgress = progress;
  }
  return (bestProgress + (hasPlayed ? 0.15 : 0)).clamp(0.0, 1.0);
}

String _preferredPodcastLanguage(List<PodcastShow> shows, String fallback) {
  final counts = <String, int>{};
  for (final show in shows) {
    final language = show.language
        ?.trim()
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    if (language == null || language.isEmpty) continue;
    counts[language] = (counts[language] ?? 0) + 1;
  }
  if (counts.isEmpty) return fallback;
  final ranked = counts.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return ranked.first.key;
}

String _recommendationReason(
  BuildContext context,
  PodcastIndexRecommendation recommendation,
) {
  final detail = recommendation.reasonContext?.trim();
  return switch (recommendation.reason) {
    PodcastRecommendationReason.becauseYouListen =>
      detail == null || detail.isEmpty
          ? context.tr('根据你的收听推荐', 'Based on your listening', '視聴履歴に基づくおすすめ')
          : context.tr(
              '因为你收听 $detail',
              'Because you listen to $detail',
              '$detailを聴いているあなたへ',
            ),
    PodcastRecommendationReason.category =>
      detail == null || detail.isEmpty
          ? context.tr('符合你的兴趣', 'Matches your interests', '興味に合う番組')
          : context.tr('探索 $detail', 'Explore $detail', '$detailを探索'),
    PodcastRecommendationReason.trending => context.tr(
      '当前热门节目',
      'Trending now',
      '今話題の番組',
    ),
    PodcastRecommendationReason.explore =>
      detail == null || detail.isEmpty
          ? context.tr('为你探索', 'Something new for you', '新しい番組を発見')
          : context.tr('探索 $detail', 'Explore $detail', '$detailを探索'),
  };
}
