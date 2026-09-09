import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../player/player_screen.dart';
import '../../widgets/app_back_button.dart';

/// Opens Podcast playback above the tab navigator so every entry point uses
/// the same immersive player surface as the global mini player.
Future<void> openPodcastEpisodePlayer(
  BuildContext context, {
  required String episodeId,
  bool autoplayOnOpen = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => PodcastEpisodeScreen(
        episodeId: episodeId,
        autoplayOnOpen: autoplayOnOpen,
      ),
    ),
  );
}

/// Resolves the persisted Podcast entities, then opens the same immersive
/// player used by audiobooks. Transcript rendering and live database updates
/// are handled by [PlayerScreen]'s Podcast mode.
class PodcastEpisodeScreen extends ConsumerStatefulWidget {
  final String episodeId;
  final bool autoplayOnOpen;

  const PodcastEpisodeScreen({
    super.key,
    required this.episodeId,
    this.autoplayOnOpen = false,
  });

  @override
  ConsumerState<PodcastEpisodeScreen> createState() =>
      _PodcastEpisodeScreenState();
}

class _PodcastEpisodeScreenState extends ConsumerState<PodcastEpisodeScreen> {
  late Future<PodcastPlayerData?> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void didUpdateWidget(covariant PodcastEpisodeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId) {
      _dataFuture = _loadData();
    }
  }

  Future<PodcastPlayerData?> _loadData() async {
    final database = ref.read(appDatabaseProvider);
    final episode = await database.getPodcastEpisode(widget.episodeId);
    if (episode == null) return null;
    final show = await database.getPodcastShow(episode.showId);
    if (show == null) return null;
    final episodes = await database.getPodcastEpisodes(show.id);
    return PodcastPlayerData(episode: episode, show: show, episodes: episodes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PodcastPlayerData?>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(leading: const Center(child: AppBackButton())),
            body: Center(
              child: Text(
                context.tr(
                  'Podcast 加载失败：${snapshot.error}',
                  'Unable to load podcast: ${snapshot.error}',
                  'ポッドキャストを読み込めません：${snapshot.error}',
                ),
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(leading: const Center(child: AppBackButton())),
            body: Center(
              child: Text(
                context.tr('单集不存在', 'Episode not found', 'エピソードが見つかりません'),
              ),
            ),
          );
        }
        return PlayerScreen.podcast(
          podcast: data,
          autoplayOnOpen: widget.autoplayOnOpen,
        );
      },
    );
  }
}
