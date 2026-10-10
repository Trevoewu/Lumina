import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/relative_time.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/animated_pressable_card.dart';
import '../../widgets/half_screen_action_sheet.dart';
import '../../widgets/podcast_artwork.dart';
import '../../widgets/swipe_action_row.dart';
import 'podcast_formatters.dart';

class PodcastEpisodeTile extends ConsumerStatefulWidget {
  final PodcastEpisode episode;
  final String? showTitle;
  final VoidCallback onTap;
  final bool enableSwipeActions;

  const PodcastEpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
    this.showTitle,
    this.enableSwipeActions = false,
  });

  @override
  ConsumerState<PodcastEpisodeTile> createState() => _PodcastEpisodeTileState();
}

class _PodcastEpisodeTileState extends ConsumerState<PodcastEpisodeTile> {
  late PodcastEpisode _resolvedEpisode;
  bool _downloading = false;
  double? _downloadProgress;
  bool _removedFromList = false;

  @override
  void initState() {
    super.initState();
    _resolvedEpisode = widget.episode;
  }

  @override
  void didUpdateWidget(covariant PodcastEpisodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id ||
        widget.episode.isPlayed ||
        !_resolvedEpisode.isPlayed) {
      _resolvedEpisode = widget.episode;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_removedFromList) return const SizedBox.shrink();
    final resolvedEpisode = _resolvedEpisode;
    final date = relativeTimeLabel(context, resolvedEpisode.publishedAt);
    final duration = formatPodcastDuration(context, resolvedEpisode.durationMs);
    final metadata = [
      if (widget.showTitle != null && widget.showTitle!.isNotEmpty)
        widget.showTitle!,
      if (date.isNotEmpty) date,
      if (duration.isNotEmpty) duration,
    ].join(' · ');

    return SwipeActionRow(
      key: ValueKey('podcast-episode-swipe-${resolvedEpisode.id}'),
      enabled: widget.enableSwipeActions,
      actions: [
        SwipeAction(
          label: resolvedEpisode.isPlayed
              ? context.tr('标为未读', 'Mark as unread', '未読にする')
              : context.tr('标为已读', 'Mark as read', '既読にする'),
          backgroundColor: const Color(0xFF2389E9),
          onPressed: () => _setPlayedStatus(
            resolvedEpisode,
            isPlayed: !resolvedEpisode.isPlayed,
          ),
        ),
        SwipeAction(
          label: context.tr('隐藏', 'Hide', '非表示'),
          backgroundColor: const Color(0xFFFF9D32),
          onPressed: () => _hideEpisode(resolvedEpisode),
        ),
        SwipeAction(
          label: context.tr('删除', 'Delete', '削除'),
          backgroundColor: const Color(0xFFFF4D52),
          onPressed: () => _confirmDeleteEpisode(resolvedEpisode),
        ),
      ],
      child: ColoredBox(
        color: context.appBackground,
        child: AnimatedPressableCard(
          key: ValueKey('podcast-episode-${resolvedEpisode.id}'),
          onTap: widget.onTap,
          onLongPress: () => _showActions(context, resolvedEpisode),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PodcastArtwork(imageUrl: resolvedEpisode.imageUrl, size: 76),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedEpisode.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.appTextSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (resolvedEpisode.isPlayed) ...[
                  const SizedBox(width: 6),
                  AppIcon(
                    AppIcons.checkmarkCircle02,
                    color: context.appTextSecondary,
                    size: 32,
                  ),
                ],
                if (_downloading) ...[
                  const SizedBox(width: 10),
                  SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      value: _downloadProgress,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setPlayedStatus(
    PodcastEpisode episode, {
    required bool isPlayed,
  }) async {
    try {
      await ref
          .read(appDatabaseProvider)
          .setPodcastEpisodePlayed(episode.id, isPlayed);
      if (!mounted) return;
      setState(() {
        _resolvedEpisode = episode.copyWith(
          playbackPositionMs: isPlayed ? episode.durationMs : 0,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
          isPlayed: isPlayed,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('无法更新单集状态', 'Unable to update episode', '状態を更新できません'),
          ),
        ),
      );
    }
  }

  Future<void> _hideEpisode(PodcastEpisode episode) async {
    await ref
        .read(appDatabaseProvider)
        .updatePodcastEpisodeHidden(episode.id, true);
    if (!mounted) return;
    setState(() => _removedFromList = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('已隐藏该单集', 'Episode hidden', 'エピソードを非表示にしました')),
        action: SnackBarAction(
          label: context.tr('撤销', 'Undo', '元に戻す'),
          onPressed: () async {
            await ref
                .read(appDatabaseProvider)
                .updatePodcastEpisodeHidden(episode.id, false);
            if (mounted) setState(() => _removedFromList = false);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEpisode(PodcastEpisode episode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('删除单集？', 'Delete episode?', '削除しますか？')),
        content: Text(
          context.tr(
            '将删除该单集及其本地音频和字幕。',
            'This removes the episode, its local audio, and transcript.',
            'エピソード、ローカル音声、文字起こしを削除します。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('删除', 'Delete', '削除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(cacheManagerProvider).clearPodcastEpisodeData(episode.id);
      await ref.read(appDatabaseProvider).deletePodcastEpisode(episode.id);
      if (mounted) setState(() => _removedFromList = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('无法删除单集', 'Unable to delete episode', '削除できません'),
          ),
        ),
      );
    }
  }

  Future<void> _showActions(
    BuildContext context,
    PodcastEpisode resolvedEpisode,
  ) async {
    final downloaded = await _hasDownloadedAudio(resolvedEpisode);
    if (!context.mounted) return;
    final progress = _downloadProgress;
    final hasTranscript =
        resolvedEpisode.transcriptJson?.trim().isNotEmpty ?? false;
    showHalfScreenActionSheet(
      context,
      title: resolvedEpisode.title,
      actions: [
        HalfScreenActionSheetItem(
          label: context.tr('标记为已听完', 'Mark as finished', '聴き終わりにする'),
          icon: AppIcons.checkmarkCircle02,
          onPressed: resolvedEpisode.isPlayed
              ? null
              : () => _markAsFinished(resolvedEpisode),
        ),
        HalfScreenActionSheetItem(
          label: downloaded
              ? context.tr('单集已下载', 'Episode downloaded', 'エピソードをダウンロード済み')
              : _downloading
              ? progress == null
                    ? context.tr(
                        '正在下载单集',
                        'Downloading episode',
                        'エピソードをダウンロード中',
                      )
                    : context.tr(
                        '正在下载 ${(progress * 100).round()}%',
                        'Downloading ${(progress * 100).round()}%',
                        'ダウンロード中 ${(progress * 100).round()}%',
                      )
              : context.tr('下载单集', 'Download episode', 'エピソードをダウンロード'),
          icon: downloaded
              ? AppIcons.checkmarkCircle02
              : AppIcons.downloadCircle01,
          onPressed: downloaded || _downloading
              ? null
              : () => _downloadEpisode(resolvedEpisode),
        ),
        if (hasTranscript)
          HalfScreenActionSheetItem(
            label: context.tr('删除字幕', 'Delete transcript', '文字起こしを削除'),
            icon: AppIcons.delete02,
            destructive: true,
            onPressed: () => _deleteTranscript(resolvedEpisode),
          ),
      ],
    );
  }

  Future<void> _refreshEpisode() async {
    final updated = await ref
        .read(appDatabaseProvider)
        .getPodcastEpisode(_resolvedEpisode.id);
    if (mounted && updated != null) setState(() => _resolvedEpisode = updated);
  }

  Future<void> _deleteTranscript(PodcastEpisode episode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('删除字幕？', 'Delete transcript?', '文字起こしを削除しますか？')),
        content: Text(
          context.tr(
            '只删除本地字幕，Podcast 音频会保留。之后可以重新生成。',
            'Only the local transcript will be deleted. Podcast audio will be kept and you can generate it again later.',
            'ローカルの文字起こしのみ削除されます。ポッドキャスト音声は保持され、後で再生成できます。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('删除', 'Delete', '削除')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(cacheManagerProvider)
          .clearPodcastEpisodeTranscript(episode.id);
      await _refreshEpisode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('字幕已删除', 'Transcript deleted', '文字起こしを削除しました'),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '字幕删除失败：$error',
                'Unable to delete transcript: $error',
                '文字起こしを削除できません：$error',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _hasDownloadedAudio(PodcastEpisode episode) async {
    final path = episode.localAudioPath;
    return path != null && path.isNotEmpty && await File(path).exists();
  }

  Future<void> _downloadEpisode(PodcastEpisode resolvedEpisode) async {
    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });
    try {
      await ref
          .read(podcastTranscriptionServiceProvider)
          .downloadEpisodeAudio(
            resolvedEpisode,
            onProgress: (received, total) {
              if (!mounted) return;
              setState(() {
                _downloadProgress = total <= 0
                    ? null
                    : (received / total).clamp(0.0, 1.0).toDouble();
              });
            },
          );
      final updated = await ref
          .read(appDatabaseProvider)
          .getPodcastEpisode(resolvedEpisode.id);
      if (!mounted) return;
      if (updated != null) {
        setState(() => _resolvedEpisode = updated);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('单集已下载', 'Episode downloaded', 'エピソードをダウンロードしました'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '无法下载单集',
              'Unable to download episode',
              'エピソードをダウンロードできません',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _markAsFinished(PodcastEpisode resolvedEpisode) async {
    final finishedPositionMs = resolvedEpisode.durationMs > 0
        ? resolvedEpisode.durationMs
        : resolvedEpisode.playbackPositionMs;
    try {
      await ref
          .read(appDatabaseProvider)
          .updatePodcastProgress(
            resolvedEpisode.id,
            positionMs: finishedPositionMs,
            isPlayed: true,
          );
      if (!mounted) return;
      setState(() {
        _resolvedEpisode = resolvedEpisode.copyWith(
          playbackPositionMs: finishedPositionMs,
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
          isPlayed: true,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('无法标记为已听完', 'Unable to mark as finished', '聴き終わりにできません'),
          ),
        ),
      );
    }
  }
}
