import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

/// Small uppercase section label ("LATEST", "生词本 · 6") from the Lumina
/// design: tracked out, secondary ink, never larger than the content it labels.
/// Size and tracking set it apart; its colour still has to clear 4.5:1.
TextStyle kickerTextStyle(BuildContext context) => TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  letterSpacing: 1.26,
  color: context.appTextSecondary,
);

/// Technical text — time codes, durations, phonetics, counts. Tabular figures
/// stand in for the design's monospace face so digits stay aligned in lists.
TextStyle technicalTextStyle(
  BuildContext context, {
  required double size,
  required double alpha,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  color: context.appTextPrimary.withValues(alpha: alpha),
  fontFeatures: const [FontFeature.tabularFigures()],
);
