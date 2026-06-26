import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class BookCover extends StatelessWidget {
  final String? coverPath;
  final IconData placeholderIcon;
  final double iconSize;
  final double borderRadius;

  const BookCover({
    super.key,
    this.coverPath,
    this.placeholderIcon = Icons.album,
    this.iconSize = 72,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final path = coverPath;
    final coverExists = path != null && File(path).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        color: AppColors.surface,
        child: coverExists
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceHighlight, AppColors.surface],
        ),
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          size: iconSize,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
