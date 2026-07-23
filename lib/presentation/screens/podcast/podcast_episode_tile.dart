import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/podcast_artwork.dart';
import 'podcast_formatters.dart';

class PodcastEpisodeTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final date = formatPodcastDate(episode.publishedAt);
    final duration = formatPodcastDuration(episode.durationMs);
    final metadata = [
      if (showTitle != null && showTitle!.isNotEmpty) showTitle!,
      if (date.isNotEmpty) date,
      if (duration.isNotEmpty) duration,
    ].join(' · ');
    final progress = episode.durationMs <= 0
        ? 0.0
        : (episode.playbackPositionMs / episode.durationMs)
              .clamp(0.0, 1.0)
              .toDouble();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastArtwork(imageUrl: episode.imageUrl, size: 76),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
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
                  if (episode.playbackPositionMs > 0) ...[
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
            if (episode.isPlayed) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle,
                color: context.appTextSecondary,
                size: 32,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
