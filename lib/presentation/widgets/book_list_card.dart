import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../services/cover_palette_service.dart';

class BookListCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? localCoverPath;
  final String? remoteCoverUrl;
  final List<BookListCardMeta> metadata;
  final VoidCallback onTap;
  final Widget? trailing;

  const BookListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.localCoverPath,
    this.remoteCoverUrl,
    this.metadata = const [],
    this.trailing,
  });

  @override
  State<BookListCard> createState() => _BookListCardState();
}

class _BookListCardState extends State<BookListCard> {
  late Future<Color?> _coverSeed;

  @override
  void initState() {
    super.initState();
    _coverSeed = CoverPaletteService.seedForPath(widget.localCoverPath);
  }

  @override
  void didUpdateWidget(covariant BookListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localCoverPath != widget.localCoverPath) {
      _coverSeed = CoverPaletteService.seedForPath(widget.localCoverPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
      future: _coverSeed,
      builder: (context, snapshot) {
        return _BookListCardBody(
          title: widget.title,
          subtitle: widget.subtitle,
          localCoverPath: widget.localCoverPath,
          remoteCoverUrl: widget.remoteCoverUrl,
          metadata: widget.metadata,
          onTap: widget.onTap,
          trailing: widget.trailing,
          seed: snapshot.data,
        );
      },
    );
  }
}

class _BookListCardBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? localCoverPath;
  final String? remoteCoverUrl;
  final List<BookListCardMeta> metadata;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? seed;

  const _BookListCardBody({
    required this.title,
    required this.subtitle,
    required this.localCoverPath,
    required this.remoteCoverUrl,
    required this.metadata,
    required this.onTap,
    required this.trailing,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final cardColor = _cardColor(context, seed);
    final chipColor = _chipColor(context, seed);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(design.radiusMedium),
        boxShadow: [
          if (seed != null)
            BoxShadow(
              color: seed!.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(design.radiusMedium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 108,
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
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final item in metadata)
                              _BookListMetaChip(item, surfaceColor: chipColor),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Icon(Icons.chevron_right, color: context.appTextSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _cardColor(BuildContext context, Color? seed) {
    if (seed == null) return context.appSurface;
    final tint = CoverPaletteService.cardSurfaceForSeed(
      seed,
      Theme.of(context).brightness,
    );
    return Color.lerp(context.appSurface, tint, 0.82)!;
  }

  Color _chipColor(BuildContext context, Color? seed) {
    if (seed == null) return context.appSurfaceHighlight;
    final tint = CoverPaletteService.cardSurfaceForSeed(
      seed,
      Theme.of(context).brightness,
    );
    return Color.lerp(context.appSurfaceHighlight, tint, 0.45)!;
  }
}

class BookListCardMeta {
  final IconData icon;
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
    final file = path == null ? null : File(path);
    final hasLocalCover = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: context.appSurfaceHighlight,
        child: hasLocalCover
            ? Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            : url == null
            ? _placeholder(context)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _placeholder(context);
                },
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: Icon(
        Icons.auto_stories_outlined,
        color: context.appTextSecondary,
        size: 34,
      ),
    );
  }
}

class _BookListMetaChip extends StatelessWidget {
  final BookListCardMeta meta;
  final Color? surfaceColor;

  const _BookListMetaChip(this.meta, {this.surfaceColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: surfaceColor ?? context.appSurfaceHighlight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: context.appTextSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              meta.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
