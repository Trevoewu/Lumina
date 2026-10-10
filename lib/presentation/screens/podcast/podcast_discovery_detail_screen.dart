import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/user_facing_error.dart';
import '../../../data/podcasts/podcast_index_repository.dart';
import '../../../data/podcasts/podcast_repository.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/podcast_artwork.dart';
import '../../widgets/tag_chips.dart';
import '../../widgets/podcast_expandable_description.dart';
import 'podcast_episode_screen.dart';
import 'podcast_formatters.dart';
import 'podcast_show_screen.dart';
import '../search/search_links.dart';

class PodcastDiscoveryDetailScreen extends ConsumerStatefulWidget {
  final PodcastIndexPodcast podcast;

  const PodcastDiscoveryDetailScreen({super.key, required this.podcast});

  @override
  ConsumerState<PodcastDiscoveryDetailScreen> createState() =>
      _PodcastDiscoveryDetailScreenState();
}

class _PodcastDiscoveryDetailScreenState
    extends ConsumerState<PodcastDiscoveryDetailScreen> {
  late Future<ParsedPodcastFeed> _previewFuture;
  String? _subscribedShowId;
  bool _checkingSubscription = true;
  bool _subscribing = false;
  String? _openingEpisodeGuid;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
    _loadSubscription();
  }

  Future<ParsedPodcastFeed> _loadPreview() {
    return ref.read(podcastRepositoryProvider).preview(widget.podcast.feedUrl);
  }

  Future<void> _loadSubscription() async {
    final show = await ref
        .read(appDatabaseProvider)
        .getPodcastShowByFeedUrl(widget.podcast.feedUrl);
    if (!mounted) return;
    setState(() {
      _subscribedShowId = show != null && show.subscribedAt > 0
          ? show.id
          : null;
      _checkingSubscription = false;
    });
  }

  void _retry() {
    setState(() {
      _previewFuture = _loadPreview();
    });
  }

  Future<void> _followOrOpen() async {
    final existingShowId = _subscribedShowId;
    if (existingShowId != null) {
      await _openSubscribedShow(existingShowId);
      return;
    }
    if (_subscribing) return;
    setState(() => _subscribing = true);
    try {
      final result = await ref
          .read(podcastRepositoryProvider)
          .subscribe(widget.podcast.feedUrl, categories: widget.podcast.genres);
      if (!mounted) return;
      setState(() => _subscribedShowId = result.show.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '已订阅 ${result.show.title}',
              'Subscribed to ${result.show.title}',
              '${result.show.title}をフォローしました',
            ),
          ),
        ),
      );
      await _openSubscribedShow(result.show.id, replace: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.tr('订阅失败', 'Could not subscribe', '購読できませんでした')}: '
              '${userFacingErrorMessage(context, error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  Future<void> _openSubscribedShow(
    String showId, {
    bool replace = false,
  }) async {
    final route = MaterialPageRoute<void>(
      builder: (_) => PodcastShowScreen(showId: showId),
    );
    if (replace) {
      await Navigator.of(context).pushReplacement(route);
    } else {
      await Navigator.of(context).push(route);
    }
  }

  Future<void> _previewEpisode(
    ParsedPodcastFeed preview,
    ParsedPodcastEpisode episode,
  ) async {
    if (_openingEpisodeGuid != null) return;
    setState(() => _openingEpisodeGuid = episode.guid);
    try {
      final result = await ref
          .read(podcastRepositoryProvider)
          .storePreview(
            widget.podcast.feedUrl,
            preview,
            categories: widget.podcast.genres,
          );
      final stored = await ref
          .read(appDatabaseProvider)
          .getPodcastEpisodeByGuid(result.show.id, episode.guid);
      if (!mounted) return;
      if (stored == null) {
        throw StateError(
          context.tr('无法准备试听单集', 'Unable to prepare preview', '試聴を準備できません'),
        );
      }
      await openPodcastEpisodePlayer(
        context,
        episodeId: stored.id,
        autoplayOnOpen: true,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '无法开始试听：$error',
                'Unable to start preview: $error',
                '試聴を開始できません：$error',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingEpisodeGuid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsingPageScaffold(
      title: widget.podcast.title,
      // The show card below carries the title.
      showTitle: false,
      showBackButton: true,
      body: FutureBuilder<ParsedPodcastFeed>(
        future: _previewFuture,
        builder: (context, snapshot) {
          final preview = snapshot.data;
          return _buildBody(
            preview: preview,
            waiting: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
          );
        },
      ),
    );
  }

  Widget _buildBody({
    required ParsedPodcastFeed? preview,
    required bool waiting,
    required Object? error,
  }) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final imageUrl = preview?.imageUrl ?? widget.podcast.imageUrl;
    final title = preview?.title ?? widget.podcast.title;
    final author = preview?.author ?? widget.podcast.author;

    return ListView(
      key: const ValueKey('podcast-discovery-detail'),
      padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastArtwork(imageUrl: imageUrl, size: 126),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (author != null && author.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      author,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('podcast-discovery-follow'),
                    onPressed: _checkingSubscription || _subscribing
                        ? null
                        : _followOrOpen,
                    icon: _subscribing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AppIcon(
                            _subscribedShowId == null
                                ? AppIcons.add01
                                : AppIcons.arrowRight02,
                          ),
                    label: Text(
                      _subscribedShowId == null
                          ? context.tr('订阅', 'Follow', '購読')
                          : context.tr('查看节目', 'Open show', '番組を開く'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_categoriesFor(preview).isNotEmpty) ...[
          SizedBox(height: design.spaceMd),
          TagChips(
            tags: _categoriesFor(preview),
            onSelected: (category) => openSearchFor(context, category),
          ),
        ],
        if (preview != null && preview.description.isNotEmpty) ...[
          SizedBox(height: design.spaceLg),
          PodcastExpandableDescription(text: preview.description),
        ],
        SizedBox(height: design.spaceXl),
        Text(
          context.tr('最新单集', 'Latest episodes', '最新エピソード'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (waiting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          _PreviewError(error: error, onRetry: _retry)
        else if (preview == null || preview.episodes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              context.tr(
                'Feed 中没有可预览的单集',
                'No episodes available to preview',
                'フィードに試聴できるエピソードがありません',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
          )
        else
          for (final episode in preview.episodes.take(12))
            _PreviewEpisodeTile(
              episode: episode,
              fallbackImageUrl: imageUrl,
              opening: _openingEpisodeGuid == episode.guid,
              onTap: () => _previewEpisode(preview, episode),
            ),
      ],
    );
  }

  List<String> _categoriesFor(ParsedPodcastFeed? preview) {
    final categories = <String>[];
    final seen = <String>{};
    for (final category in [
      ...?preview?.categories,
      ...widget.podcast.genres,
    ]) {
      if (seen.add(category.toLowerCase())) categories.add(category);
    }
    return meaningfulPodcastCategories(categories);
  }
}

class _PreviewEpisodeTile extends StatelessWidget {
  final ParsedPodcastEpisode episode;
  final String? fallbackImageUrl;
  final bool opening;
  final VoidCallback onTap;

  const _PreviewEpisodeTile({
    required this.episode,
    required this.fallbackImageUrl,
    required this.opening,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (episode.durationMs > 0)
        formatPodcastDuration(context, episode.durationMs),
      context.tr('可直接试听', 'Preview available', '試聴できます'),
    ].join(' · ');
    return InkWell(
      key: ValueKey('podcast-preview-episode-${episode.guid}'),
      borderRadius: BorderRadius.circular(8),
      onTap: opening ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastArtwork(
              imageUrl: episode.imageUrl ?? fallbackImageUrl,
              size: 72,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    metadata,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (episode.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      episode.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (opening)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: context.tr('试听', 'Preview', '試聴'),
                onPressed: onTap,
                icon: const AppIcon(AppIcons.playCircle),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _PreviewError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const AppIcon(AppIcons.cloudOff, size: 40),
          const SizedBox(height: 10),
          Text(
            context.tr(
              '无法读取节目 Feed',
              'Unable to load podcast feed',
              '番組フィードを読み込めません',
            ),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            userFacingErrorMessage(context, error),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appTextSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const AppIcon(AppIcons.refresh),
            label: Text(context.tr('重试', 'Retry', '再試行')),
          ),
        ],
      ),
    );
  }
}
