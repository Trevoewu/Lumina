import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import '../../../core/providers.dart';
import '../../../services/cover_palette_service.dart';
import '../screens/podcast/podcast_episode_screen.dart';
import '../screens/player/player_screen.dart';
import 'book_cover.dart';
import 'podcast_artwork.dart';

/// 全局迷你播放器
class MiniPlayer extends ConsumerWidget {
  /// Includes the inset progress track and its bottom breathing room.
  static const double height = 64;
  static const double navigationGap = 8;
  static const double horizontalInset = 20;

  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return handlerAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (handler) {
        return StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          initialData: handler.mediaItem.valueOrNull,
          builder: (context, mediaSnapshot) {
            final currentItem = mediaSnapshot.data;
            if (currentItem == null) return const SizedBox.shrink();
            return StreamBuilder(
              stream: handler.playbackState,
              initialData: handler.playbackState.value,
              builder: (context, playbackSnapshot) {
                final state = playbackSnapshot.data;
                if (state == null) return const SizedBox.shrink();

                final playing = state.playing;
                // A stream that has been asked to play but has no audio yet
                // must not sit behind a pause icon with nothing happening.
                final buffering =
                    playing &&
                    (state.processingState == AudioProcessingState.loading ||
                        state.processingState ==
                            AudioProcessingState.buffering);
                final duration = handler.chapterDuration;
                final bookId = currentItem.extras?['bookId'] as String?;
                final podcastEpisodeId =
                    currentItem.extras?['podcastEpisodeId'] as String?;
                final imageUrl = currentItem.extras?['imageUrl'] as String?;
                final isPodcast = currentItem.extras?['mediaType'] == 'podcast';

                return GestureDetector(
                  onTap: () async {
                    if (isPodcast && podcastEpisodeId != null) {
                      if (context.mounted) {
                        await openPodcastEpisodePlayer(
                          context,
                          episodeId: podcastEpisodeId,
                        );
                      }
                      return;
                    }
                    if (bookId == null) return;

                    final db = ref.read(appDatabaseProvider);
                    final book = await db.getBook(bookId);
                    final chapterId =
                        currentItem.extras?['chapterId'] as String? ??
                        book?.currentChapterId;
                    final chapter = chapterId == null
                        ? null
                        : await db.getChapter(chapterId);
                    if (book != null && context.mounted) {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlayerScreen(book: book, initialChapter: chapter),
                        ),
                      );
                    }
                  },
                  child: _MiniPlayerSurface(
                    bookId: bookId,
                    imageUrl: imageUrl,
                    child: (context, coverPath) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 7, 8, 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: isPodcast
                                    ? PodcastArtwork(
                                        imageUrl: imageUrl,
                                        size: 44,
                                        borderRadius: 10,
                                      )
                                    : BookCover(
                                        coverPath: coverPath,
                                        iconSize: 22,
                                        borderRadius: 10,
                                      ),
                              ),
                              const SizedBox(width: 10),

                              // 标题信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentItem.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentItem.album ?? 'Lumina',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // 控制按钮
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                icon: Icon(
                                  buffering
                                      ? Icons.hourglass_top_rounded
                                      : playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                onPressed: playing
                                    ? handler.pause
                                    : handler.play,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                icon: Icon(
                                  Icons.skip_next,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                onPressed: handler.skipToNext,
                              ),
                            ],
                          ),
                        ),

                        // 极细的进度条
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                            child: StreamBuilder<Duration>(
                              stream: handler.chapterPositionStream,
                              initialData: handler.chapterPosition,
                              builder: (context, positionSnapshot) {
                                final position =
                                    positionSnapshot.data ?? Duration.zero;
                                final progress = duration.inMilliseconds <= 0
                                    ? 0.0
                                    : (position.inMilliseconds /
                                              duration.inMilliseconds)
                                          .clamp(0.0, 1.0)
                                          .toDouble();

                                return LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 2,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.08),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accent,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MiniPlayerSurface extends ConsumerStatefulWidget {
  final String? bookId;
  final String? imageUrl;
  final Widget Function(BuildContext context, String? coverPath) child;

  const _MiniPlayerSurface({
    required this.bookId,
    required this.imageUrl,
    required this.child,
  });

  @override
  ConsumerState<_MiniPlayerSurface> createState() => _MiniPlayerSurfaceState();
}

class _MiniPlayerSurfaceState extends ConsumerState<_MiniPlayerSurface> {
  late Future<_MiniPlayerAppearance> _appearance;

  @override
  void initState() {
    super.initState();
    _appearance = _loadAppearance();
  }

  @override
  void didUpdateWidget(covariant _MiniPlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId ||
        oldWidget.imageUrl != widget.imageUrl) {
      _appearance = _loadAppearance();
    }
  }

  Future<_MiniPlayerAppearance> _loadAppearance() async {
    final id = widget.bookId;
    final book = id == null
        ? null
        : await ref.read(appDatabaseProvider).getBook(id);
    final seed = await CoverPaletteService.seedForPath(book?.coverPath);
    return _MiniPlayerAppearance(coverPath: book?.coverPath, seed: seed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _appearance,
      builder: (context, snapshot) {
        final appearance = snapshot.data;
        final seed = appearance?.seed;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final surface = Color.lerp(
          theme.colorScheme.surface,
          seed ?? theme.colorScheme.surface,
          isDark ? 0.10 : 0.05,
        )!;
        final content = SizedBox(
          height: MiniPlayer.height,
          child: widget.child(context, appearance?.coverPath),
        );
        final nativeGlass =
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS) &&
            PlatformVersion.supportsLiquidGlass;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MiniPlayer.horizontalInset,
          ),
          child: nativeGlass
              ? LiquidGlassContainer(
                  config: LiquidGlassConfig(
                    effect: CNGlassEffect.regular,
                    shape: CNGlassEffectShape.capsule,
                    tint: (seed ?? theme.colorScheme.surface).withValues(
                      alpha: 0.06,
                    ),
                  ),
                  child: content,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                        child: content,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _MiniPlayerAppearance {
  final String? coverPath;
  final Color? seed;

  const _MiniPlayerAppearance({required this.coverPath, required this.seed});
}
