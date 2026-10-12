import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

/// The fading rule between sections laid flat on a page: Home, the
/// dictionary page, the player's notes and AI sections.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final line = context.appTextPrimary.withValues(alpha: 0.09);

    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, line, line, Colors.transparent],
          stops: const [0, 0.12, 0.88, 1],
        ),
      ),
    );
  }
}
