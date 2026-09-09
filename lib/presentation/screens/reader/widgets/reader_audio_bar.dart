import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';
import '../../../../core/providers.dart';
import '../../../../data/database/app_database.dart' as drift_db;
import '../../../widgets/book_cover.dart';
import '../../player/player_screen.dart';

class ReaderAudioBar extends ConsumerWidget {
  final drift_db.Book book;
  final drift_db.Chapter? currentChapter;
  final VoidCallback onStartListening;

  const ReaderAudioBar({
    super.key,
    required this.book,
    required this.currentChapter,
    required this.onStartListening,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final accent = context.appAccent;
    final scheme = Theme.of(context).colorScheme;

    return handlerAsync.when(
      data: (handler) {
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, playbackSnapshot) {
            final state = playbackSnapshot.data;
            final isPlaying = state?.playing ?? false;
            final isThisBook = handler.currentBookId == book.id;
            final isBuffering =
                state?.processingState == AudioProcessingState.loading ||
                state?.processingState == AudioProcessingState.buffering;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.appSurface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Book cover / Player open
                  GestureDetector(
                    onTap: () {
                      if (currentChapter != null) {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlayerScreen(
                              book: book,
                              initialChapter: currentChapter,
                              autoplayOnOpen: false,
                            ),
                          ),
                        );
                      }
                    },
                    child: SizedBox(
                      width: 40,
                      height: 52,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: BookCover(
                          coverPath: book.coverPath,
                          iconSize: 22,
                          borderRadius: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (currentChapter != null) {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlayerScreen(
                                book: book,
                                initialChapter: currentChapter,
                                autoplayOnOpen: false,
                              ),
                            ),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentChapter?.title ?? book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isThisBook && isPlaying
                                ? context.tr(
                                    '正在朗读...',
                                    'Reading aloud...',
                                    '朗読中...',
                                  )
                                : (book.author ??
                                      context.tr(
                                        '有声阅读',
                                        'Audio reading',
                                        'オーディオ読書',
                                      )),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isThisBook && isPlaying
                                  ? accent
                                  : context.appTextSecondary,
                              fontWeight: isThisBook && isPlaying
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Controls
                  if (isThisBook) ...[
                    IconButton(
                      icon: const AppIcon(AppIcons.goBackward10Sec),
                      iconSize: 22,
                      color: context.appTextSecondary,
                      tooltip: context.tr('快退 10 秒', 'Rewind 10s', '10秒戻る'),
                      onPressed: () => handler.rewind(),
                    ),
                    IconButton(
                      icon: isBuffering
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          : AppIcon(
                              isPlaying
                                  ? AppIcons.pauseCircle
                                  : AppIcons.playCircle,
                              size: 34,
                              color: accent,
                            ),
                      onPressed: () {
                        if (isPlaying) {
                          handler.pause();
                        } else {
                          handler.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.goForward10Sec),
                      iconSize: 22,
                      color: context.appTextSecondary,
                      tooltip: context.tr('快进 10 秒', 'Forward 10s', '10秒進む'),
                      onPressed: () => handler.fastForward(),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: onStartListening,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedHeadphones,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(context.tr('听书', 'Listen', '聴く')),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
