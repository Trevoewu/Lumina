import 'dart:ui';

import 'package:flutter/material.dart';
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
                          padding: const EdgeInsets.fromLTRB(8, 6, 4, 5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: isPodcast
                                    ? PodcastArtwork(
                                        imageUrl: imageUrl,
                                        size: 48,
                                        borderRadius: 5,
                                      )
                                    : BookCover(
                                        coverPath: coverPath,
                                        iconSize: 22,
                                        borderRadius: 5,
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
                                            color: Colors.white,
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
                                            color: Colors.white.withValues(
                                              alpha: 0.74,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // 控制按钮
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 42,
                                  height: 42,
                                ),
                                icon: Icon(
                                  playing ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: playing
                                    ? handler.pause
                                    : handler.play,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 42,
                                  height: 42,
                                ),
                                icon: Icon(
                                  Icons.skip_next,
                                  color: Colors.white,
                                ),
                                onPressed: handler.skipToNext,
                              ),
                            ],
                          ),
                        ),

                        // 极细的进度条
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.lerp(accent, Colors.white, 0.72)!,
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
        final surface = seed == null
            ? const Color(0xFF303030)
            : CoverPaletteService.darkSurfaceForSeed(seed);

        return Container(
          margin: const EdgeInsets.fromLTRB(6, 0, 6, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: 0.88),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: widget.child(context, appearance?.coverPath),
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
