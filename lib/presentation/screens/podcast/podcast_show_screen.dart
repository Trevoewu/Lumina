import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import '../../widgets/app_glass_controls.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/user_facing_error.dart';
import '../../../data/database/app_database.dart';
import '../../../data/podcasts/podcast_repository.dart';
import '../../../services/app_log_service.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/podcast_artwork.dart';
import '../../widgets/tag_chips.dart';
import '../../widgets/podcast_expandable_description.dart';
import 'podcast_episode_screen.dart';
import 'podcast_episode_tile.dart';
import '../search/search_links.dart';

enum PodcastEpisodeSortOrder {
  newestFirst,
  oldestFirst;

  String label(BuildContext context) => switch (this) {
    PodcastEpisodeSortOrder.newestFirst => context.tr(
      '从新到旧',
      'Newest first',
      '新しい順',
    ),
    PodcastEpisodeSortOrder.oldestFirst => context.tr(
      '从旧到新',
      'Oldest first',
      '古い順',
    ),
  };
}

class PodcastShowScreen extends ConsumerStatefulWidget {
  final String showId;

  const PodcastShowScreen({super.key, required this.showId});

  @override
  ConsumerState<PodcastShowScreen> createState() => _PodcastShowScreenState();
}

class _PodcastShowScreenState extends ConsumerState<PodcastShowScreen> {
  late Future<PodcastShow?> _showFuture;
  bool _refreshing = false;
  PodcastEpisodeSortOrder _sortOrder = PodcastEpisodeSortOrder.newestFirst;

  /// Episodes are read a page at a time; reaching the end asks for the next.
  static const _pageSize = 30;
  int _episodeLimit = _pageSize;
  Stream<List<PodcastEpisode>>? _episodes;
  bool _checkedFreshness = false;

  /// One stream per limit and order, not one per rebuild.
  Stream<List<PodcastEpisode>> _episodeStream(String showId) =>
      _episodes ??= ref
          .read(appDatabaseProvider)
          .watchPodcastEpisodes(
            showId,
            limit: _episodeLimit,
            newestFirst: _sortOrder == PodcastEpisodeSortOrder.newestFirst,
          );

  void _loadMoreEpisodes() {
    setState(() {
      _episodeLimit += _pageSize;
      _episodes = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _showFuture = _loadShow();
  }

  Future<PodcastShow?> _loadShow() async {
    final show = await ref
        .read(appDatabaseProvider)
        .getPodcastShow(widget.showId);
    if (show != null && show.categoriesJson == null) {
      unawaited(_enrichLegacyShow(show));
    } else if (show != null && !_checkedFreshness && isPodcastShowStale(show)) {
      // New episodes show up on their own; the refresh button is for when
      // the reader wants to check again right now.
      _checkedFreshness = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refresh(show, quiet: true));
      });
    }
    return show;
  }

  Future<void> _enrichLegacyShow(PodcastShow show) async {
    try {
      await ref.read(podcastRepositoryProvider).refresh(show);
      if (!mounted) return;
      setState(() {
        _showFuture = ref
            .read(appDatabaseProvider)
            .getPodcastShow(widget.showId);
      });
    } catch (_) {
      // Metadata enrichment is best effort. Existing local content remains
      // usable when the publisher feed cannot be reached.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PodcastShow?>(
      future: _showFuture,
      builder: (context, snapshot) {
        final show = snapshot.data;
        return CollapsingPageScaffold(
          title: show?.title ?? context.tr('Podcast', 'Podcast', 'ポッドキャスト'),
          // The show card below carries the title.
          showTitle: false,
          showBackButton: true,
          actions: show == null
              ? const []
              : [
                  IconButton(
                    tooltip: context.tr('刷新节目', 'Refresh podcast', '番組を更新'),
                    onPressed: _refreshing ? null : () => _refresh(show),
                    icon: _refreshing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppIcon(AppIcons.refresh),
                  ),
                  AppGlassMenuButton<String>(
                    tooltip: context.tr('更多', 'More', 'その他'),
                    onSelected: (value) {
                      if (value == 'unsubscribe') _unsubscribe(show);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'unsubscribe',
                        child: Text(context.tr('取消订阅', 'Unsubscribe', '購読解除')),
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
      return Center(
        child: Text(
          '${context.tr('加载失败', 'Could not load this show', '番組を読み込めませんでした')}: '
          '${userFacingErrorMessage(context, snapshot.error!)}',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (show == null) {
      return Center(
        child: Text(context.tr('节目不存在', 'Podcast not found', '番組が見つかりません')),
      );
    }

    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final categories = meaningfulPodcastCategories(
      decodePodcastCategories(show.categoriesJson),
    );
    return StreamBuilder<List<PodcastEpisode>>(
      stream: _episodeStream(show.id),
      builder: (context, snapshot) {
        final episodes = snapshot.data ?? const <PodcastEpisode>[];
        final mayHaveMore = episodes.length >= _episodeLimit;
        final header = <Widget>[
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
                          : () => _playLatest(show),
                      icon: const AppIcon(AppIcons.play),
                      label: Text(context.tr('播放最新', 'Play latest', '最新を再生')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            SizedBox(height: design.spaceMd),
            TagChips(
              tags: categories,
              onSelected: (category) => openSearchFor(context, category),
            ),
          ],
          if (show.description.isNotEmpty) ...[
            SizedBox(height: design.spaceLg),
            PodcastExpandableDescription(text: show.description),
          ],
          SizedBox(height: design.spaceXl),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('所有单集', 'All episodes', 'すべてのエピソード'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (episodes.isNotEmpty) _buildSortMenu(context),
            ],
          ),
          const SizedBox(height: 8),
          if (episodes.isEmpty && snapshot.hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.tr(
                  'Feed 中没有可播放的单集',
                  'No playable episodes',
                  'フィードに再生できるエピソードがありません',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appTextSecondary),
              ),
            ),
        ];
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 0),
              sliver: SliverList.list(children: header),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, 120),
              // Built as they scroll into view; nearing the end of what is
              // loaded asks for the next page.
              sliver: SliverList.builder(
                itemCount: episodes.length + (mayHaveMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= episodes.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && episodes.length >= _episodeLimit) {
                        _loadMoreEpisodes();
                      }
                    });
                    return const Padding(
                      key: ValueKey('podcast-episodes-loading-more'),
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    );
                  }
                  final episode = episodes[index];
                  return PodcastEpisodeTile(
                    key: ValueKey('podcast-episode-${episode.id}'),
                    episode: episode,
                    enableSwipeActions: true,
                    onTap: () => _openEpisode(episode.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playLatest(PodcastShow show) async {
    final latest = await ref
        .read(appDatabaseProvider)
        .watchPodcastEpisodes(show.id, limit: 1)
        .first;
    if (!mounted || latest.isEmpty) return;
    _openEpisode(latest.first.id);
  }

  /// [quiet] is the automatic check on opening: a failure is logged, not
  /// shown, since the reader did not ask for it.
  Future<void> _refresh(PodcastShow show, {bool quiet = false}) async {
    if (_refreshing) return;
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
    } catch (error, stackTrace) {
      if (quiet) {
        AppLogger.warning(
          'Podcast',
          '打开节目时自动刷新失败 show=${show.id}',
          error: error,
          stackTrace: stackTrace,
        );
      } else if (mounted) {
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
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _unsubscribe(PodcastShow show) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('取消订阅？', 'Unsubscribe?', '購読を解除しますか？')),
        content: Text(
          context.tr(
            '将删除该节目、本地单集记录和转写结果。',
            'This removes the podcast, episode history, and transcripts.',
            'ポッドキャスト、エピソード履歴、文字起こしを削除します。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('取消订阅', 'Unsubscribe', '購読解除')),
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

  Widget _buildSortMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<PodcastEpisodeSortOrder>(
      key: const ValueKey('podcast-episodes-sort-button'),
      tooltip: context.tr('排序', 'Sort', '並び替え'),
      position: PopupMenuPosition.under,
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.appDesign.radiusSmall),
      ),
      initialValue: _sortOrder,
      onSelected: (order) {
        if (_sortOrder != order) {
          // The database sorts, so a new order starts again from page one.
          setState(() {
            _sortOrder = order;
            _episodeLimit = _pageSize;
            _episodes = null;
          });
        }
      },
      itemBuilder: (context) => [
        for (final order in PodcastEpisodeSortOrder.values)
          PopupMenuItem(
            key: ValueKey('sort-order-${order.name}'),
            value: order,
            child: _sortMenuItem(
              label: order.label(context),
              selected: _sortOrder == order,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _sortOrder.label(context),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(width: 4),
            AppIcon(
              AppIcons.arrowUpDown,
              size: 16,
              color: context.appTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortMenuItem({required String label, required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: selected
              ? AppIcon(AppIcons.tick02, size: 18, color: scheme.primary)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? scheme.primary : context.appTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
