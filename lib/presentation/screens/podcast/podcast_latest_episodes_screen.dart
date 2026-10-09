import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import 'podcast_episode_screen.dart';
import 'podcast_episode_tile.dart';

class PodcastLatestEpisodesScreen extends ConsumerStatefulWidget {
  const PodcastLatestEpisodesScreen({super.key});

  @override
  ConsumerState<PodcastLatestEpisodesScreen> createState() =>
      _PodcastLatestEpisodesScreenState();
}

class _PodcastLatestEpisodesScreenState
    extends ConsumerState<PodcastLatestEpisodesScreen> {
  late Future<_LatestEpisodesData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_LatestEpisodesData> _load() async {
    final database = ref.read(appDatabaseProvider);
    final results = await Future.wait<Object>([
      database.getPodcastShows(),
      database.getRecentPodcastEpisodes(),
    ]);
    final shows = results[0] as List<PodcastShow>;
    return _LatestEpisodesData(
      episodes: results[1] as List<PodcastEpisode>,
      showsById: {for (final show in shows) show.id: show},
    );
  }

  Future<void> _openEpisode(String episodeId) async {
    await openPodcastEpisodePlayer(context, episodeId: episodeId);
    if (!mounted) return;
    setState(() {
      _dataFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('最新单集', 'Latest episodes', '最新エピソード'),
      showBackButton: true,
      body: FutureBuilder<_LatestEpisodesData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                context.tr(
                  '无法加载最新单集',
                  'Unable to load latest episodes',
                  '最新エピソードを読み込めません',
                ),
                style: TextStyle(color: context.appTextSecondary),
              ),
            );
          }
          final data = snapshot.data ?? const _LatestEpisodesData();
          if (data.episodes.isEmpty) {
            return Center(
              child: Text(
                context.tr(
                  '还没有 Podcast 单集',
                  'No podcast episodes yet',
                  'ポッドキャストのエピソードはまだありません',
                ),
                style: TextStyle(color: context.appTextSecondary),
              ),
            );
          }
          return ListView.builder(
            key: const ValueKey('podcast-all-episodes-list'),
            padding: EdgeInsets.fromLTRB(inset, design.spaceMd, inset, 120),
            itemCount: data.episodes.length,
            itemBuilder: (context, index) {
              final episode = data.episodes[index];
              return PodcastEpisodeTile(
                episode: episode,
                showTitle: data.showsById[episode.showId]?.title,
                onTap: () => _openEpisode(episode.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _LatestEpisodesData {
  final List<PodcastEpisode> episodes;
  final Map<String, PodcastShow> showsById;

  const _LatestEpisodesData({
    this.episodes = const <PodcastEpisode>[],
    this.showsById = const <String, PodcastShow>{},
  });
}
