import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/podcasts/podcast_index_repository.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/podcast_artwork.dart';

class PodcastIndexSearchScreen extends ConsumerStatefulWidget {
  const PodcastIndexSearchScreen({super.key});

  @override
  ConsumerState<PodcastIndexSearchScreen> createState() =>
      _PodcastIndexSearchScreenState();
}

class _PodcastIndexSearchScreenState
    extends ConsumerState<PodcastIndexSearchScreen> {
  final _controller = TextEditingController();
  final _subscribedFeedUrls = <String>{};
  final _subscribingFeedUrls = <String>{};
  Timer? _debounce;
  Future<List<PodcastIndexPodcast>>? _searchFuture;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSubscriptions());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
    final shows = await ref.read(appDatabaseProvider).getPodcastShows();
    if (!mounted) return;
    setState(() {
      _subscribedFeedUrls.addAll(shows.map((show) => show.feedUrl));
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _activeQuery = '';
        _searchFuture = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  void _runSearch() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _activeQuery = '';
        _searchFuture = null;
      });
      return;
    }
    setState(() {
      _activeQuery = query;
      _searchFuture = ref.read(podcastIndexRepositoryProvider).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('发现 Podcast', 'Discover podcasts'),
      showBackButton: true,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 4),
            child: TextField(
              key: const ValueKey('podcast-index-search-field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.appSurface,
                hintText: context.tr('搜索节目或创作者', 'Search shows or creators'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('清空', 'Clear'),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('podcast-index-attribution'),
                onPressed: () => launchUrl(
                  Uri.parse('https://podcastindex.org/'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.public, size: 15),
                label: const Text('Powered by Podcast Index'),
              ),
            ),
          ),
          Expanded(child: _buildResults(inset)),
        ],
      ),
    );
  }

  Widget _buildResults(double inset) {
    final future = _searchFuture;
    if (future == null) {
      return _PodcastIndexIntro(inset: inset);
    }
    return FutureBuilder<List<PodcastIndexPodcast>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _PodcastIndexError(
            message: snapshot.error.toString(),
            onRetry: _runSearch,
          );
        }
        final results = snapshot.data ?? const <PodcastIndexPodcast>[];
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: Text(
                context.tr(
                  '没有找到“$_activeQuery”',
                  'No podcasts found for “$_activeQuery”',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appTextSecondary),
              ),
            ),
          );
        }
        return ListView.separated(
          key: const ValueKey('podcast-index-results'),
          padding: EdgeInsets.fromLTRB(inset, 4, inset, 120),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final podcast = results[index];
            return _PodcastIndexResultTile(
              podcast: podcast,
              subscribed: _subscribedFeedUrls.contains(podcast.feedUrl),
              subscribing: _subscribingFeedUrls.contains(podcast.feedUrl),
              onSubscribe: () => _subscribe(podcast),
            );
          },
        );
      },
    );
  }

  Future<void> _subscribe(PodcastIndexPodcast podcast) async {
    if (_subscribedFeedUrls.contains(podcast.feedUrl) ||
        _subscribingFeedUrls.contains(podcast.feedUrl)) {
      return;
    }
    setState(() => _subscribingFeedUrls.add(podcast.feedUrl));
    try {
      final result = await ref
          .read(podcastRepositoryProvider)
          .subscribe(podcast.feedUrl);
      if (!mounted) return;
      setState(() {
        _subscribedFeedUrls
          ..add(podcast.feedUrl)
          ..add(result.show.feedUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '已订阅 ${result.show.title}',
              'Subscribed to ${result.show.title}',
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('订阅失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _subscribingFeedUrls.remove(podcast.feedUrl));
      }
    }
  }
}

class _PodcastIndexIntro extends StatelessWidget {
  final double inset;

  const _PodcastIndexIntro({required this.inset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, 24, inset, 120),
        child: Column(
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 88,
              color: context.appSurfaceHighlight,
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('从开放目录发现节目', 'Discover from the open index'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                '输入节目名或创作者；订阅后由 Lumina 直接读取发布者 RSS。',
                'Search by show or creator. Lumina reads the publisher RSS after you subscribe.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodcastIndexError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PodcastIndexError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              context.tr('Podcast Index 搜索失败', 'Podcast Index search failed'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('重试', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodcastIndexResultTile extends StatelessWidget {
  final PodcastIndexPodcast podcast;
  final bool subscribed;
  final bool subscribing;
  final VoidCallback onSubscribe;

  const _PodcastIndexResultTile({
    required this.podcast,
    required this.subscribed,
    required this.subscribing,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (podcast.author != null) podcast.author!,
      if (podcast.genres.isNotEmpty) podcast.genres.first,
      if (podcast.episodeCount > 0)
        context.tr(
          '${podcast.episodeCount} 个单集',
          '${podcast.episodeCount} episodes',
        ),
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PodcastArtwork(imageUrl: podcast.imageUrl, size: 72),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      metadata,
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
            if (subscribing)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else if (subscribed)
              Tooltip(
                message: context.tr('已订阅', 'Subscribed'),
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
              )
            else
              FilledButton(
                onPressed: onSubscribe,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                ),
                child: Text(context.tr('订阅', 'Follow')),
              ),
          ],
        ),
      ),
    );
  }
}
