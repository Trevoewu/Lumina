import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../services/podcast_transcription_service.dart';
import '../../widgets/animated_pressable_card.dart';
import '../../widgets/half_screen_action_sheet.dart';
import '../../widgets/podcast_artwork.dart';
import 'podcast_formatters.dart';

class PodcastEpisodeTile extends ConsumerStatefulWidget {
  final PodcastEpisode episode;
  final String? showTitle;
  final VoidCallback onTap;

  const PodcastEpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
    this.showTitle,
  });

  @override
  ConsumerState<PodcastEpisodeTile> createState() => _PodcastEpisodeTileState();
}

class _PodcastEpisodeTileState extends ConsumerState<PodcastEpisodeTile> {
  late PodcastEpisode _resolvedEpisode;
  bool _downloading = false;
  double? _downloadProgress;
  bool _transcribing = false;
  StreamSubscription<PodcastTranscriptionProgress>? _transcriptionSubscription;

  @override
  void initState() {
    super.initState();
    _resolvedEpisode = widget.episode;
    _watchTranscriptionProgress();
  }

  @override
  void didUpdateWidget(covariant PodcastEpisodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id ||
        widget.episode.isPlayed ||
        !_resolvedEpisode.isPlayed) {
      _resolvedEpisode = widget.episode;
    }
    if (oldWidget.episode.id != widget.episode.id) {
      _watchTranscriptionProgress();
    }
  }

  @override
  void dispose() {
    unawaited(_transcriptionSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedEpisode = _resolvedEpisode;
    final date = formatPodcastDate(resolvedEpisode.publishedAt);
    final duration = formatPodcastDuration(resolvedEpisode.durationMs);
    final metadata = [
      if (widget.showTitle != null && widget.showTitle!.isNotEmpty)
        widget.showTitle!,
      if (date.isNotEmpty) date,
      if (duration.isNotEmpty) duration,
    ].join(' · ');
    final progress = resolvedEpisode.durationMs <= 0
        ? 0.0
        : (resolvedEpisode.playbackPositionMs / resolvedEpisode.durationMs)
              .clamp(0.0, 1.0)
              .toDouble();

    return AnimatedPressableCard(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      metadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                  if (resolvedEpisode.playbackPositionMs > 0 &&
                      !resolvedEpisode.isPlayed) ...[
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: context.appSurfaceHighlight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (resolvedEpisode.isPlayed) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle_rounded,
                color: context.appTextSecondary,
                size: 32,
              ),
            ],
            if (_downloading || _transcribing) ...[
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
    );
  }

  void _showActions(BuildContext context, PodcastEpisode resolvedEpisode) {
    final downloaded = _hasDownloadedAudio(resolvedEpisode);
    final progress = _downloadProgress;
    final hasTranscript =
        resolvedEpisode.transcriptJson?.trim().isNotEmpty ?? false;
    final paused =
        resolvedEpisode.transcriptStatus == podcastTranscriptPausedStatus &&
        resolvedEpisode.transcriptProgressMs > 0;
    showHalfScreenActionSheet(
      context,
      title: resolvedEpisode.title,
      actions: [
        HalfScreenActionSheetItem(
          label: context.tr('标记为已听完', 'Mark as finished'),
          icon: Icons.check_circle_outline_rounded,
          onPressed: resolvedEpisode.isPlayed
              ? null
              : () => _markAsFinished(resolvedEpisode),
        ),
        HalfScreenActionSheetItem(
          label: downloaded
              ? context.tr('单集已下载', 'Episode downloaded')
              : _downloading
              ? progress == null
                    ? context.tr('正在下载单集', 'Downloading episode')
                    : context.tr(
                        '正在下载 ${(progress * 100).round()}%',
                        'Downloading ${(progress * 100).round()}%',
                      )
              : context.tr('下载单集', 'Download episode'),
          icon: downloaded
              ? Icons.download_done_rounded
              : Icons.download_for_offline_outlined,
          onPressed: downloaded || _downloading
              ? null
              : () => _downloadEpisode(resolvedEpisode),
        ),
        if (_transcribing)
          HalfScreenActionSheetItem(
            label: context.tr('暂停转写', 'Pause transcription'),
            icon: Icons.pause_circle_outline_rounded,
            onPressed: _pauseTranscription,
          )
        else
          HalfScreenActionSheetItem(
            label: paused
                ? context.tr('继续转写', 'Resume transcription')
                : hasTranscript
                ? context.tr('重新生成字幕', 'Regenerate transcript')
                : context.tr('生成字幕', 'Generate transcript'),
            icon: paused
                ? Icons.play_circle_outline_rounded
                : Icons.auto_awesome_rounded,
            onPressed: () => _runTranscription(
              resolvedEpisode,
              clearExisting: hasTranscript && !paused,
              confirm: hasTranscript && !paused,
            ),
          ),
        if (hasTranscript)
          HalfScreenActionSheetItem(
            label: context.tr('删除字幕', 'Delete transcript'),
            icon: Icons.delete_outline_rounded,
            destructive: true,
            onPressed: () => _deleteTranscript(resolvedEpisode),
          ),
      ],
    );
  }

  void _watchTranscriptionProgress() {
    unawaited(_transcriptionSubscription?.cancel());
    final service = ref.read(podcastTranscriptionServiceProvider);
    _transcribing = service.activeEpisodeId == _resolvedEpisode.id;
    _transcriptionSubscription = service.progressStream.listen((progress) {
      if (!mounted || progress.episodeId != _resolvedEpisode.id) return;
      setState(() => _transcribing = progress.running);
      if (!progress.running) unawaited(_refreshEpisode());
    });
  }

  Future<void> _refreshEpisode() async {
    final updated = await ref
        .read(appDatabaseProvider)
        .getPodcastEpisode(_resolvedEpisode.id);
    if (mounted && updated != null) setState(() => _resolvedEpisode = updated);
  }

  Future<void> _pauseTranscription() async {
    try {
      await ref.read(podcastTranscriptionServiceProvider).pause();
      await _refreshEpisode();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '暂停转写失败：$error',
                'Unable to pause transcription: $error',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _runTranscription(
    PodcastEpisode episode, {
    required bool clearExisting,
    required bool confirm,
  }) async {
    if (_transcribing) return;
    if (confirm && !await _confirmRegenerate()) return;
    final service = ref.read(podcastTranscriptionServiceProvider);
    try {
      if (clearExisting) {
        await ref
            .read(cacheManagerProvider)
            .clearPodcastEpisodeTranscript(episode.id);
      }
      if (mounted) setState(() => _transcribing = true);
      await service.transcribe(episode);
      await _refreshEpisode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('字幕已生成', 'Transcript generated'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '字幕生成失败：$error',
                'Unable to generate transcript: $error',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<bool> _confirmRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('重新生成字幕？', 'Regenerate transcript?')),
        content: Text(
          context.tr(
            '当前字幕会被删除，然后从头重新转写。',
            'The current transcript will be deleted and transcribed again from the beginning.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('重新生成', 'Regenerate')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteTranscript(PodcastEpisode episode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('删除字幕？', 'Delete transcript?')),
        content: Text(
          context.tr(
            '只删除本地字幕，Podcast 音频会保留。之后可以重新生成。',
            'Only the local transcript will be deleted. Podcast audio will be kept and you can generate it again later.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('删除', 'Delete')),
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
          SnackBar(content: Text(context.tr('字幕已删除', 'Transcript deleted'))),
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
              ),
            ),
          ),
        );
      }
    }
  }

  bool _hasDownloadedAudio(PodcastEpisode episode) {
    final path = episode.localAudioPath;
    return path != null && path.isNotEmpty && File(path).existsSync();
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
        SnackBar(content: Text(context.tr('单集已下载', 'Episode downloaded'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('无法下载单集', 'Unable to download episode')),
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
          content: Text(context.tr('无法标记为已听完', 'Unable to mark as finished')),
        ),
      );
    }
  }
}
