import 'package:flutter/widgets.dart';

import '../../../core/app_localizations.dart';

/// An episode's length in the reader's language: "1h 35m" / "25 min",
/// "1小时35分钟", "1時間35分".
String formatPodcastDuration(BuildContext context, int milliseconds) {
  if (milliseconds <= 0) return '';
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0
        ? context.tr('$hours小时', '${hours}h', '$hours時間')
        : context.tr(
            '$hours小时$minutes分钟',
            '${hours}h ${minutes}m',
            '$hours時間$minutes分',
          );
  }
  final total = duration.inMinutes.clamp(1, 9999);
  return context.tr('$total分钟', '$total min', '$total分');
}

String formatPlaybackTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
