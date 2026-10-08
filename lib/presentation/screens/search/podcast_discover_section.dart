import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/podcasts/podcast_index_repository.dart';
import '../../widgets/podcast_artwork.dart';
import '../podcast/podcast_discovery_detail_screen.dart';

class PodcastDiscoverSection extends ConsumerStatefulWidget {
  final List<PodcastShow> shows;
  final List<PodcastEpisode> episodes;
  final String preferredLanguage;
  final int refreshToken;
  final VoidCallback onSubscribed;

  const PodcastDiscoverSection({
    super.key,
    required this.shows,
    required this.episodes,
    required this.preferredLanguage,
    required this.refreshToken,
    required this.onSubscribed,
  });

  @override
  ConsumerState<PodcastDiscoverSection> createState() =>
      PodcastDiscoverSectionState();
}

class PodcastDiscoverSectionState
    extends ConsumerState<PodcastDiscoverSection> {
  late Future<List<PodcastIndexRecommendation>> _recommendationsFuture;
  late String _profileFingerprint;

  @override
  void initState() {
    super.initState();
    _profileFingerprint = _fingerprint();
    _recommendationsFuture = _loadRecommendations();
  }

  @override
  void didUpdateWidget(covariant PodcastDiscoverSection oldWidget) {
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
              icon: const AppIcon(AppIcons.refresh),
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
                  leading: const AppIcon(AppIcons.compass),
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
                ),
              );
            }
            return ListView.separated(
              key: const ValueKey('podcast-discover-recommendations'),
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final recommendation = recommendations[index];
                final podcast = recommendation.podcast;
                return SizedBox(
                  height: 132,
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
                                          fontWeight: FontWeight.w500,
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
                                                color: context.appTextSecondary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      AppIcon(
                                        AppIcons.arrowRight01,
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
            );
          },
        ),
      ],
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
