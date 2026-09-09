import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class BookCover extends StatelessWidget {
  final String? coverPath;
  final AppIconData placeholderIcon;
  final double iconSize;
  final double borderRadius;

  const BookCover({
    super.key,
    this.coverPath,
    this.placeholderIcon = AppIcons.album01,
    this.iconSize = 72,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final path = coverPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        color: context.appSurface,
        child: path == null || path.isEmpty
            ? _placeholder(context)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                  int? cachePixels(double extent) {
                    if (!extent.isFinite || extent <= 0) return null;
                    return (extent * pixelRatio).ceil().clamp(1, 4096).toInt();
                  }

                  return Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    cacheWidth: cachePixels(constraints.maxWidth),
                    cacheHeight: cachePixels(constraints.maxHeight),
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _placeholder(context),
                  );
                },
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.appSurfaceHighlight, context.appSurface],
        ),
      ),
      child: Center(
        child: AppIcon(
          placeholderIcon,
          size: iconSize,
          color: context.appTextSecondary,
        ),
      ),
    );
  }
}
