import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'animated_pressable_card.dart';
import 'disk_cached_network_image.dart';

class BookListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? localCoverPath;
  final String? remoteCoverUrl;
  final List<BookListCardMeta> metadata;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const BookListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.localCoverPath,
    this.remoteCoverUrl,
    this.metadata = const [],
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      subtitle,
      for (final item in metadata) item.label,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return AnimatedPressableCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              height: 96,
              child: _BookListCover(
                localPath: localCoverPath,
                remoteUrl: remoteCoverUrl,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookListCardMeta {
  final AppIconData icon;
  final String label;

  const BookListCardMeta({required this.icon, required this.label});
}

class _BookListCover extends StatelessWidget {
  final String? localPath;
  final String? remoteUrl;

  const _BookListCover({this.localPath, this.remoteUrl});

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    final url = remoteUrl;
    final fallback = _remoteOrPlaceholder(context, url);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: context.appSurfaceHighlight,
        child: path == null || path.isEmpty
            ? fallback
            : LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = MediaQuery.devicePixelRatioOf(context);
                  final cacheWidth = (constraints.maxWidth * ratio)
                      .ceil()
                      .clamp(1, 4096)
                      .toInt();
                  final cacheHeight = (constraints.maxHeight * ratio)
                      .ceil()
                      .clamp(1, 4096)
                      .toInt();
                  return Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    cacheHeight: cacheHeight,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => fallback,
                  );
                },
              ),
      ),
    );
  }

  Widget _remoteOrPlaceholder(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return _placeholder(context);
    return DiskCachedNetworkImage(
      url: url,
      placeholder: _placeholder(context),
      fit: BoxFit.cover,
    );
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: AppIcon(
        AppIcons.bookOpen02,
        color: context.appTextSecondary,
        size: 34,
      ),
    );
  }
}
