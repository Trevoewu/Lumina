import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';

class BookListCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final design = context.appDesign;
    return Material(
      color: context.appSurface,
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
                          for (final item in metadata) _BookListMetaChip(item),
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
    );
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

  const _BookListMetaChip(this.meta);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.appSurfaceHighlight,
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
