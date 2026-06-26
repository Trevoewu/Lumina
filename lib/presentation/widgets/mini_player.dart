import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/providers.dart';
import '../screens/player/player_screen.dart';
import 'book_cover.dart';

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
        return StreamBuilder(
          stream: handler.playbackState,
          initialData: handler.playbackState.value,
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state == null) return const SizedBox.shrink();

            final currentItem = handler.mediaItem.valueOrNull;
            if (currentItem == null) return const SizedBox.shrink();

            final playing = state.playing;
            final duration = handler.chapterDuration;
            final bookId = currentItem.extras?['bookId'] as String?;

            return GestureDetector(
              onTap: () async {
                // Get the current book from the database
                if (bookId == null) return;

                final db = ref.read(appDatabaseProvider);
                final book = await db.getBook(bookId);
                if (book != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PlayerScreen(book: book)),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: _MiniPlayerCover(bookId: bookId),
                          ),
                          const SizedBox(width: 12),

                          // 标题信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentItem.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentItem.album ?? 'Lumina',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),

                          // 控制按钮
                          IconButton(
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: playing ? handler.pause : handler.play,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: handler.skipToNext,
                          ),
                        ],
                      ),
                    ),

                    // 极细的进度条
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniPlayerCover extends ConsumerWidget {
  final String? bookId;

  const _MiniPlayerCover({required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = bookId;
    if (id == null) {
      return const BookCover(iconSize: 22, borderRadius: 4);
    }

    return FutureBuilder(
      future: ref.read(appDatabaseProvider).getBook(id),
      builder: (context, snapshot) {
        return BookCover(
          coverPath: snapshot.data?.coverPath,
          iconSize: 22,
          borderRadius: 4,
        );
      },
    );
  }
}
