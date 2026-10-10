import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'design_system/app_icon.dart';

/// The heart for saving a book or episode. Unsaved it is the app's outline;
/// saved it is one solid heart in soft red. The icon set has no filled heart,
/// and laying one under the outline left a pale ring between the two.
class SavedHeart extends StatelessWidget {
  final bool saved;

  /// The outline's colour while unsaved.
  final Color color;
  final double size;

  const SavedHeart({
    super.key,
    required this.saved,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) => saved
      ? Icon(Icons.favorite, size: size, color: AppColors.savedHeart)
      : AppIcon(AppIcons.favourite, size: size, color: color);
}
