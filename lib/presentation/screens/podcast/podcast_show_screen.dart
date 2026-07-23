import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/podcast_artwork.dart';
import 'podcast_episode_screen.dart';
import 'podcast_episode_tile.dart';

class PodcastShowScreen extends ConsumerStatefulWidget {
  final String showId;

  const PodcastShowScreen({super.key, required this.showId});

  @override
  ConsumerState<PodcastShowScreen> createState() => _PodcastShowScreenState();
}

class _PodcastShowScreenState extends ConsumerState<PodcastShowScreen> {
  late Future<PodcastShow?> _showFuture;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _showFuture = ref.read(appDatabaseProvider).getPodcastShow(widget.showId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PodcastShow?>(
      future: _showFuture,
      builder: (context, snapshot) {
        final show = snapshot.data;
        return CollapsingPageScaffold(
          title: show?.title ?? context.tr('Podcast', 'Podcast'),
          showBackButton: true,
          actions: show == null
              ? const []
              : [
                  IconButton(
                    tooltip: context.tr('刷新节目', 'Refresh podcast'),
                    onPressed: _refreshing ? null : () => _refresh(show),
                    icon: _refreshing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.tr('更多', 'More'),
                    onSelected: (value) {
                      if (value == 'unsubscribe') _unsubscribe(show);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'unsubscribe',
                        child: Text(context.tr('取消订阅', 'Unsubscribe')),
                      ),
                    ],
                  ),
                ],
          body: _buildBody(snapshot, show),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<PodcastShow?> snapshot, PodcastShow? show) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('加载失败：${snapshot.error}'));
    }
    if (show == null) {
      return Center(child: Text(context.tr('节目不存在', 'Podcast not found')));
    }

    final database = ref.watch(appDatabaseProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return StreamBuilder<List<PodcastEpisode>>(
      stream: database.watchPodcastEpisodes(show.id),
      builder: (context, snapshot) {
        final episodes = snapshot.data ?? const <PodcastEpisode>[];
        return ListView(
          padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PodcastArtwork(imageUrl: show.imageUrl, size: 126),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        show.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (show.author != null && show.author!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          show.author!,
                          style: TextStyle(color: context.appTextSecondary),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: episodes.isEmpty
                            ? null
                            : () => _openEpisode(episodes.first.id),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(context.tr('播放最新', 'Play latest')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (show.description.isNotEmpty) ...[
              SizedBox(height: design.spaceLg),
              Text(
                show.description,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.appTextSecondary, height: 1.45),
              ),
            ],
            SizedBox(height: design.spaceXl),
            Text(
              context.tr('所有单集', 'All episodes'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (episodes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  context.tr('Feed 中没有可播放的单集', 'No playable episodes'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.appTextSecondary),
                ),
              )
            else
              for (final episode in episodes)
                PodcastEpisodeTile(
                  episode: episode,
                  onTap: () => _openEpisode(episode.id),
                ),
          ],
        );
      },
    );
  }

  Future<void> _refresh(PodcastShow show) async {
    setState(() => _refreshing = true);
    try {
      await ref.read(podcastRepositoryProvider).refresh(show);
      if (mounted) {
        setState(() {
          _showFuture = ref
              .read(appDatabaseProvider)
              .getPodcastShow(widget.showId);
        });
      }
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

  Future<void> _unsubscribe(PodcastShow show) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('取消订阅？', 'Unsubscribe?')),
        content: Text(
          context.tr(
            '将删除该节目、本地单集记录和转写结果。',
            'This removes the podcast, episode history, and transcripts.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('取消订阅', 'Unsubscribe')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final database = ref.read(appDatabaseProvider);
    final episodes = await database.getPodcastEpisodes(show.id);
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    if (handler.currentPodcastShowId == show.id) await handler.unload();
    for (final episode in episodes) {
      final path = episode.localAudioPath;
      if (path == null) continue;
      for (final candidate in [File(path), File('$path.wav')]) {
        if (await candidate.exists()) {
          try {
            await candidate.delete();
          } catch (_) {}
        }
      }
    }
    await database.deletePodcastShowCascade(show.id);
    if (mounted) Navigator.pop(context);
  }

  void _openEpisode(String episodeId) {
    openPodcastEpisodePlayer(context, episodeId: episodeId);
  }
}
