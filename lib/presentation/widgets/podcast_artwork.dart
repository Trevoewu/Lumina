import 'package:flutter/material.dart';

import 'disk_cached_network_image.dart';

class PodcastArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;

  const PodcastArtwork({
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderRadius = 10,
    this.fallbackIcon = Icons.podcasts,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: size * 0.42,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final source = imageUrl;

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: source == null || source.isEmpty
            ? fallback
            : DiskCachedNetworkImage(
                url: source,
                placeholder: fallback,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
